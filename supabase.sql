-- Elektrotehnika: Digitalna radionica — zajednička baza
-- Pokreni cijelu skriptu jednom u Supabase: SQL Editor -> New query -> Run.

create extension if not exists pgcrypto with schema extensions;

-- Studenti: nadimak, PIN (spremljen samo kao hash), tajni token za prijavu s uređaja i stanje napretka.
create table if not exists public.profiles (
  id         uuid primary key default gen_random_uuid(),
  nick       text not null check (char_length(nick) between 2 and 24),
  pin_hash   text not null,
  token      uuid not null default gen_random_uuid() unique,
  state      jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists profiles_nick_lower on public.profiles (lower(nick));

-- Zajednička težina svakog pitanja (uči iz odgovora svih studenata).
create table if not exists public.qstats (
  qid text primary key,
  r   real not null,
  n   integer not null default 0,
  c   integer not null default 0
);

-- Dnevnik svih odgovora, za tvoju analizu.
create table if not exists public.answers (
  id         bigserial primary key,
  profile_id uuid references public.profiles(id) on delete cascade,
  qid        text not null,
  topic      text not null,
  score      real not null,
  used_help  boolean not null default false,
  mode       text not null default 'vjezba',
  created_at timestamptz not null default now()
);
create index if not exists answers_qid on public.answers (qid);

-- Tablice su zaključane; stranica smije samo pozivati funkcije ispod.
alter table public.profiles enable row level security;
alter table public.qstats   enable row level security;
alter table public.answers  enable row level security;
revoke all on public.profiles, public.qstats, public.answers from anon, authenticated;

create or replace function public.register(p_nick text, p_pin text)
returns table(token uuid, nick text, state jsonb)
language plpgsql security definer set search_path = public, extensions as $$
begin
  p_nick := btrim(p_nick);
  if char_length(p_nick) < 2 or char_length(p_nick) > 24 then raise exception 'bad_nick'; end if;
  if p_pin !~ '^[0-9]{4}$' then raise exception 'bad_pin'; end if;
  if exists (select 1 from profiles p where lower(p.nick) = lower(p_nick)) then raise exception 'nick_taken'; end if;
  return query insert into profiles(nick, pin_hash) values (p_nick, crypt(p_pin, gen_salt('bf')))
    returning profiles.token, profiles.nick, profiles.state;
end $$;

create or replace function public.login(p_nick text, p_pin text)
returns table(token uuid, nick text, state jsonb)
language plpgsql security definer set search_path = public, extensions as $$
begin
  return query select p.token, p.nick, p.state from profiles p
    where lower(p.nick) = lower(btrim(p_nick)) and p.pin_hash = crypt(p_pin, p.pin_hash);
  if not found then raise exception 'bad_login'; end if;
end $$;

create or replace function public.resume(p_token uuid)
returns table(nick text, state jsonb)
language sql security definer set search_path = public as $$
  select p.nick, p.state from profiles p where p.token = p_token;
$$;

create or replace function public.save_state(p_token uuid, p_state jsonb)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if octet_length(p_state::text) > 200000 then raise exception 'too_big'; end if;
  update profiles set state = p_state, updated_at = now() where token = p_token;
  if not found then raise exception 'bad_token'; end if;
end $$;

create or replace function public.record_answer(p_token uuid, p_qid text, p_topic text, p_score real,
  p_help boolean, p_mode text, p_qbase real, p_qdelta real)
returns void
language plpgsql security definer set search_path = public as $$
declare pid uuid; d real;
begin
  select id into pid from profiles where token = p_token;
  if pid is null then raise exception 'bad_token'; end if;
  insert into answers(profile_id, qid, topic, score, used_help, mode)
    values (pid, left(p_qid, 40), left(p_topic, 20), greatest(0, least(1, p_score)), p_help, left(p_mode, 10));
  if not p_help then
    d := greatest(-0.5, least(0.5, p_qdelta));
    insert into qstats(qid, r, n, c)
      values (left(p_qid, 40), greatest(1, least(10, p_qbase + d)), 1, case when p_score >= 0.5 then 1 else 0 end)
    on conflict (qid) do update
      set r = greatest(1, least(10, qstats.r + d)), n = qstats.n + 1, c = qstats.c + excluded.c;
  end if;
end $$;

create or replace function public.get_qstats()
returns table(qid text, r real, n integer, c integer)
language sql security definer set search_path = public as $$
  select qid, r, n, c from qstats;
$$;

create or replace function public.leaderboard(p_topic text)
returns table(nick text, r real, n integer, c integer)
language sql security definer set search_path = public as $$
  select p.nick, (p.state->'ratings'->p_topic->>'r')::real, (p.state->'ratings'->p_topic->>'n')::int,
         (p.state->'ratings'->p_topic->>'c')::int
  from profiles p
  where coalesce((p.state->'ratings'->p_topic->>'n')::int, 0) > 0
  order by 2 desc limit 200;
$$;

revoke all on function public.register, public.login, public.resume, public.save_state,
  public.record_answer, public.get_qstats, public.leaderboard from public;
grant execute on function public.register, public.login, public.resume, public.save_state,
  public.record_answer, public.get_qstats, public.leaderboard to anon, authenticated;

-- Zbirna statistika za sve (prikazuje se na dnu Ljestvice). Samo brojevi i prosjeci, bez nadimaka.
create or replace function public.stats()
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'users',   (select count(*) from profiles p where exists (select 1 from answers a where a.profile_id = p.id)),
    'active7', (select count(distinct profile_id) from answers where created_at > now() - interval '7 days'),
    'today',   (select count(distinct profile_id) from answers where created_at > date_trunc('day', now())),
    'answers', (select count(*) from answers),
    'correct', (select count(*) from answers where score >= 0.5),
    'topics',  coalesce((select jsonb_object_agg(t.topic, t.v) from (
        select a.topic, jsonb_build_object('n', count(*), 'c', count(*) filter (where a.score >= 0.5),
               'users', count(distinct a.profile_id)) v
        from answers a group by a.topic) t), '{}'::jsonb),
    'levels',  coalesce((select jsonb_object_agg(k, v) from (
        select k, jsonb_agg(round(((p.state->'ratings'->k->>'r')::numeric), 1)) v
        from profiles p, jsonb_object_keys(coalesce(p.state->'ratings','{}'::jsonb)) k
        where coalesce((p.state->'ratings'->k->>'n')::int, 0) >= 3
        group by k) x), '{}'::jsonb),
    'daily',   coalesce((select jsonb_agg(jsonb_build_object('d', d, 'u', u, 'n', n) order by d) from (
        select date_trunc('day', created_at)::date d, count(distinct profile_id) u, count(*) n
        from answers where created_at > now() - interval '30 days' group by 1) z), '[]'::jsonb),
    'hardest', coalesce((select jsonb_agg(jsonb_build_object('qid', qid, 'n', n, 'c', c) order by c::real / n) from (
        select qid, n, c from qstats where n >= 5 order by c::real / n limit 10) h), '[]'::jsonb)
  );
$$;
revoke all on function public.stats from public;
grant execute on function public.stats to anon, authenticated;

-- Brisanje vlastitog profila (uz PIN). Briše i sve odgovore tog profila.
create or replace function public.delete_profile(p_token uuid, p_pin text)
returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  delete from profiles where token = p_token and pin_hash = crypt(p_pin, pin_hash);
  if not found then raise exception 'bad_pin'; end if;
end $$;
revoke all on function public.delete_profile from public;
grant execute on function public.delete_profile to anon, authenticated;
