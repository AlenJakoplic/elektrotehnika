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

-- Ukupna ljestvica: težinski prosjek razina po gradivima (kao "ukupna razina" u aplikaciji).
create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)))
      / sum(greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0))))::real,
    sum(coalesce((p.state->'ratings'->k->>'n')::int, 0))::int
  from profiles p, unnest(array['serpar','ruk','estat','kont','cvor']) k
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;
-- Dodatak: javni profil, ime i prezime (vidi samo nastavnik), tjedna liga.
-- Pokreni jednom u SQL Editoru.

alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists show_name boolean not null default false;

-- Vlastito ime (samo uz vlastiti token).
create or replace function public.get_me(p_token uuid)
returns table(full_name text, show_name boolean)
language sql security definer set search_path = public as $$
  select p.full_name, p.show_name from profiles p where p.token = p_token;
$$;

create or replace function public.set_name(p_token uuid, p_name text, p_show boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update profiles set full_name = nullif(left(btrim(coalesce(p_name, '')), 60), ''),
                      show_name = coalesce(p_show, false) and nullif(btrim(coalesce(p_name, '')), '') is not null
  where token = p_token;
  if not found then raise exception 'bad_token'; end if;
end $$;

-- Javni profil: samo razine, niz dana, značke i bodovi. Bez zamki i pojedinih odgovora.
-- Ime se vraća samo ako je student sam uključio prikaz.
create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'ratings', coalesce(p.state->'ratings', '{}'::jsonb),
      'days',    coalesce(p.state->'days', '{}'::jsonb),
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;

-- Tjedna liga: bodovi u tekućem tjednu (tjedan počinje u ponedjeljak).
create or replace function public.leaderboard_week(p_week text)
returns table(nick text, pts real)
language sql security definer set search_path = public as $$
  select p.nick, (p.state->'week'->>'pts')::real
  from profiles p
  where p.state->'week'->>'id' = p_week and coalesce((p.state->'week'->>'pts')::real, 0) > 0
  order by 2 desc limit 200;
$$;

revoke all on function public.get_me, public.set_name, public.public_profile, public.leaderboard_week from public;
grant execute on function public.get_me, public.set_name, public.public_profile, public.leaderboard_week to anon, authenticated;
-- Dodatak: promjena nadimka i broj zadataka na javnom profilu. Pokreni jednom u SQL Editoru.

create or replace function public.rename_nick(p_token uuid, p_nick text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  p_nick := btrim(p_nick);
  if char_length(p_nick) < 2 or char_length(p_nick) > 24 then raise exception 'bad_nick'; end if;
  if exists (select 1 from profiles p where lower(p.nick) = lower(p_nick) and p.token <> p_token) then raise exception 'nick_taken'; end if;
  update profiles set nick = p_nick, state = jsonb_set(state, '{nick}', to_jsonb(p_nick)), updated_at = now() where token = p_token;
  if not found then raise exception 'bad_token'; end if;
end $$;
revoke all on function public.rename_nick from public;
grant execute on function public.rename_nick to anon, authenticated;

create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'ratings', coalesce(p.state->'ratings', '{}'::jsonb),
      'days',    coalesce(p.state->'days', '{}'::jsonb),
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb),
                                    'n', coalesce(p.state->'zad'->'n', '0'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;
-- Dodatak: točnost je zadano skrivena; prikazuje se samo ako je student uključi. Pokreni jednom u SQL Editoru.

create or replace function public.leaderboard(p_topic text)
returns table(nick text, r real, n integer, c integer)
language sql security definer set search_path = public as $$
  select p.nick, (p.state->'ratings'->p_topic->>'r')::real, (p.state->'ratings'->p_topic->>'n')::int,
         case when coalesce((p.state->>'showAcc')::boolean, false) then (p.state->'ratings'->p_topic->>'c')::int end
  from profiles p
  where coalesce((p.state->'ratings'->p_topic->>'n')::int, 0) > 0
  order by 2 desc limit 200;
$$;

create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'showAcc', coalesce((p.state->>'showAcc')::boolean, false),
      'ratings', case when coalesce((p.state->>'showAcc')::boolean, false) then coalesce(p.state->'ratings', '{}'::jsonb)
                      else coalesce((select jsonb_object_agg(k, v - 'c') from jsonb_each(coalesce(p.state->'ratings', '{}'::jsonb)) e(k, v)), '{}'::jsonb) end,
      'days',    coalesce(p.state->'days', '{}'::jsonb) - 'free' - 'run',
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb),
                                    'n', coalesce(p.state->'zad'->'n', '0'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;
-- Dodatak: tko je pronašao easter egg. Pokreni jednom u SQL Editoru.

create table if not exists public.easter_egg (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  found_at   timestamptz not null default now()
);
alter table public.easter_egg enable row level security;
revoke all on public.easter_egg from anon, authenticated;

create or replace function public.egg_found(p_token uuid)
returns void
language sql security definer set search_path = public as $$
  insert into easter_egg(profile_id) select id from profiles where token = p_token
  on conflict (profile_id) do nothing;
$$;

create or replace function public.egg_list()
returns table(nick text, found_at timestamptz)
language sql security definer set search_path = public as $$
  select p.nick, e.found_at from easter_egg e join profiles p on p.id = e.profile_id
  order by e.found_at limit 500;
$$;

revoke all on function public.egg_found, public.egg_list from public;
grant execute on function public.egg_found, public.egg_list to anon, authenticated;
-- Dodatak: ljestvica Zadataka. Pokreni jednom u SQL Editoru.
create or replace function public.leaderboard_zad()
returns table(nick text, pts real, n integer, full_n integer)
language sql security definer set search_path = public as $$
  select p.nick,
         coalesce((p.state->'zad'->>'pts')::real, 0),
         coalesce((p.state->'zad'->>'n')::int, 0),
         coalesce((select sum(value::int) from jsonb_each_text(coalesce(p.state->'zad'->'full', '{}'::jsonb))), 0)::int
  from profiles p
  where coalesce((p.state->'zad'->>'n')::int, 0) > 0
  order by 2 desc, 4 desc limit 200;
$$;
revoke all on function public.leaderboard_zad from public;
grant execute on function public.leaderboard_zad to anon, authenticated;

-- Statistika Zadataka za sve (zbirno).
create or replace function public.stats_zad()
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'users', (select count(distinct profile_id) from answers where mode = 'zadaci'),
    'n',     (select count(*) from answers where mode = 'zadaci'),
    'avg',   (select avg(score) from answers where mode = 'zadaci'),
    'full',  (select count(*) from answers where mode = 'zadaci' and score >= 0.999),
    'types', coalesce((select jsonb_object_agg(topic, v) from (
        select topic, jsonb_build_object('n', count(*), 'users', count(distinct profile_id), 'avg', avg(score),
                                         'full', count(*) filter (where score >= 0.999)) v
        from answers where mode = 'zadaci' group by topic) t), '{}'::jsonb));
$$;
revoke all on function public.stats_zad from public;
grant execute on function public.stats_zad to anon, authenticated;

-- Javni profil: dodani bodovi iz Zadataka.
create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'showAcc', coalesce((p.state->>'showAcc')::boolean, false),
      'ratings', case when coalesce((p.state->>'showAcc')::boolean, false) then coalesce(p.state->'ratings', '{}'::jsonb)
                      else coalesce((select jsonb_object_agg(k, v - 'c') from jsonb_each(coalesce(p.state->'ratings', '{}'::jsonb)) e(k, v)), '{}'::jsonb) end,
      'days',    coalesce(p.state->'days', '{}'::jsonb) - 'free' - 'run',
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb),
                                    'n', coalesce(p.state->'zad'->'n', '0'::jsonb),
                                    'pts', coalesce(p.state->'zad'->'pts', '0'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;
-- Dodatak: Theveninov i Nortonov teorem ulaze u ukupnu ljestvicu. Pokreni jednom u SQL Editoru.
create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)))
      / sum(greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0))))::real,
    sum(coalesce((p.state->'ratings'->k->>'n')::int, 0))::int
  from profiles p, unnest(array['serpar','ruk','estat','kont','cvor','thev','nort']) k
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
-- Brisanje pitanja (student) i povratnih informacija (nastavnik)
create or replace function public.my_question_delete(p_token uuid, p_id bigint)
returns void
language sql security definer set search_path = public as $$
  delete from feedback f using profiles p
  where f.id = p_id and p.id = f.profile_id and p.token = p_token and f.kind = 'pitanje';
$$;

create or replace function public.feedback_delete(p_token uuid, p_id bigint)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  delete from feedback where id = p_id;
end $$;

grant execute on function public.my_question_delete(uuid, bigint) to anon, authenticated;
grant execute on function public.feedback_delete(uuid, bigint) to anon, authenticated;
-- Analitika za nastavnika (samo administratori)
create or replace function public.admin_students(p_token uuid)
returns table(nick text, full_name text, created_at timestamptz, updated_at timestamptz, state jsonb, answers_n integer, last_answer timestamptz, days7 integer)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select p.nick, p.full_name, p.created_at, p.updated_at, p.state,
         coalesce(a.n,0)::int, a.last, coalesce(a.d7,0)::int
  from profiles p
  left join (select profile_id, count(*) n, max(answers.created_at) last,
                    count(distinct (answers.created_at at time zone 'Europe/Zagreb')::date) filter (where answers.created_at > now() - interval '7 days') d7
             from answers group by profile_id) a on a.profile_id = p.id
  where not exists(select 1 from admins x where x.profile_id = p.id)
  order by a.last desc nulls last;
end $$;

create or replace function public.admin_activity(p_token uuid)
returns table(day date, hour integer, n integer, users integer)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select (a.created_at at time zone 'Europe/Zagreb')::date, extract(hour from a.created_at at time zone 'Europe/Zagreb')::int,
         count(*)::int, count(distinct a.profile_id)::int
  from answers a where a.created_at > now() - interval '60 days'
  group by 1, 2 order by 1, 2;
end $$;

create or replace function public.admin_questions(p_token uuid)
returns table(qid text, topic text, n integer, users integer, avg_score real, help real)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select a.qid, min(a.topic), count(*)::int, count(distinct a.profile_id)::int, avg(a.score)::real, avg(case when a.used_help then 1 else 0 end)::real
  from answers a group by a.qid having count(*) >= 3 order by avg(a.score) asc limit 300;
end $$;

create or replace function public.admin_student_answers(p_token uuid, p_nick text)
returns table(qid text, topic text, score real, used_help boolean, mode text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select a.qid, a.topic, a.score, a.used_help, a.mode, a.created_at
  from answers a join profiles p on p.id = a.profile_id
  where lower(p.nick) = lower(p_nick) order by a.created_at desc limit 500;
end $$;

grant execute on function public.admin_students(uuid) to anon, authenticated;
grant execute on function public.admin_activity(uuid) to anon, authenticated;
grant execute on function public.admin_questions(uuid) to anon, authenticated;
grant execute on function public.admin_student_answers(uuid, text) to anon, authenticated;
-- Tjedna ljestvica: pamćenje bodova po tjednima i tjedni vrh (top 10 %)
create table if not exists public.week_scores (
  profile_id uuid references public.profiles(id) on delete cascade,
  week text not null,
  pts real not null default 0,
  updated_at timestamptz not null default now(),
  primary key (profile_id, week)
);
alter table public.week_scores enable row level security;

-- prenesi postojeće bodove ovog tjedna iz profila
insert into week_scores(profile_id, week, pts)
select id, state->'week'->>'id', (state->'week'->>'pts')::real from profiles
where state->'week'->>'id' is not null and coalesce((state->'week'->>'pts')::real,0) > 0
on conflict (profile_id, week) do update set pts = greatest(week_scores.pts, excluded.pts);

create or replace function public.week_save(p_token uuid, p_week text, p_pts real)
returns void
language sql security definer set search_path = public as $$
  insert into week_scores(profile_id, week, pts)
  select id, p_week, greatest(0, least(p_pts, 100000)) from profiles where token = p_token and p_week ~ '^\d{4}-\d{2}-\d{2}$'
  on conflict (profile_id, week) do update set pts = greatest(week_scores.pts, excluded.pts), updated_at = now();
$$;

create or replace function public.leaderboard_week(p_week text)
returns table(nick text, pts real)
language sql security definer set search_path = public as $$
  select p.nick, greatest(coalesce(w.pts,0), case when p.state->'week'->>'id' = p_week then coalesce((p.state->'week'->>'pts')::real,0) else 0 end)
  from profiles p left join week_scores w on w.profile_id = p.id and w.week = p_week
  where (w.pts > 0) or (p.state->'week'->>'id' = p_week and coalesce((p.state->'week'->>'pts')::real,0) > 0)
  order by 2 desc limit 200;
$$;

create or replace function public.week_list()
returns table(week text, users integer)
language sql security definer set search_path = public as $$
  select week, count(*)::int from week_scores where pts > 0 group by week order by week desc limit 60;
$$;

-- tjedni vrh: za svaki završeni tjedan prvih 10 % (najmanje 1) studenata s bodovima
create or replace function public.week_medals()
returns table(nick text, week text, rnk integer, n integer)
language sql security definer set search_path = public as $$
  with r as (
    select w.week, p.nick, rank() over (partition by w.week order by w.pts desc)::int rnk,
           count(*) over (partition by w.week)::int n
    from week_scores w join profiles p on p.id = w.profile_id
    where w.pts > 0 and w.week < to_char(date_trunc('week', (now() at time zone 'Europe/Zagreb')::date), 'YYYY-MM-DD')
  )
  select nick, week, rnk, n from r where rnk <= greatest(1, ceil(n * 0.1)) order by week desc, rnk;
$$;

grant execute on function public.week_save(uuid, text, real) to anon, authenticated;
grant execute on function public.leaderboard_week(text) to anon, authenticated;
grant execute on function public.week_list() to anon, authenticated;
grant execute on function public.week_medals() to anon, authenticated;

-- Potpuni izvoz za analizu (samo administrator). Ne izvozi PIN, token ni pravo ime.
create or replace function public.admin_export(p_token uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  select jsonb_build_object(
    'exported_at', now(),
    'admins', (select coalesce(jsonb_agg(profile_id),'[]') from admins),
    'profiles', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'nick',nick,'has_name',full_name is not null,'show_name',show_name,'created_at',created_at,'updated_at',updated_at,'state',state)),'[]') from profiles),
    'answers', (select coalesce(jsonb_agg(jsonb_build_object('pid',profile_id,'qid',qid,'topic',topic,'score',score,'help',used_help,'mode',mode,'t',created_at) order by created_at),'[]') from answers),
    'qstats', (select coalesce(jsonb_agg(to_jsonb(q)),'[]') from qstats q),
    'week_scores', (select coalesce(jsonb_agg(jsonb_build_object('pid',profile_id,'week',week,'pts',pts)),'[]') from week_scores),
    'feedback', (select coalesce(jsonb_agg(jsonb_build_object('pid',profile_id,'kind',kind,'qid',qid,'page',page,'msg',msg,'rating',rating,'extra',extra,'reply',reply,'t',created_at)),'[]') from feedback)
  ) into r;
  return r;
end $$;
grant execute on function public.admin_export(uuid) to anon, authenticated;
-- Ljestvica Redovitost (dani zaredom)
create or replace function public.leaderboard_streak()
returns table(nick text, streak integer, best integer, last text, free integer)
language sql security definer set search_path = public as $$
  select p.nick, coalesce((p.state->'days'->>'streak')::int,0), coalesce((p.state->'days'->>'best')::int,0),
         p.state->'days'->>'last', coalesce((p.state->'days'->>'free')::int,0)
  from profiles p
  where coalesce((p.state->'days'->>'streak')::int,0) >= 2 and p.state->'days'->>'last' is not null
  order by 2 desc, 3 desc limit 300;
$$;
grant execute on function public.leaderboard_streak() to anon, authenticated;
-- Dnevni izazov: isti set od 10 pitanja za sve, prvi pokušaj ide na ljestvicu
create table if not exists public.daily_challenge (
  day text primary key,
  qids jsonb not null,
  topics jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.daily_results (
  profile_id uuid references public.profiles(id) on delete cascade,
  day text not null,
  pts real not null,
  ms integer not null,
  detail jsonb,
  created_at timestamptz not null default now(),
  primary key (profile_id, day)
);
alter table public.daily_challenge enable row level security;
alter table public.daily_results enable row level security;

create or replace function public.daily_ok(p_token uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists(select 1 from profiles p where p.token = p_token and (
    (select count(*) from answers a where a.profile_id = p.id) >= 100
    or exists(select 1 from admins x where x.profile_id = p.id)));
$$;

create or replace function public.daily_get(p_token uuid, p_day text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not daily_ok(p_token) then return jsonb_build_object('locked', true); end if;
  select jsonb_build_object('qids', qids, 'topics', topics) into r from daily_challenge where day = p_day;
  return coalesce(r, jsonb_build_object('qids', null));
end $$;

create or replace function public.daily_set(p_token uuid, p_day text, p_qids jsonb, p_topics jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not daily_ok(p_token) then return jsonb_build_object('locked', true); end if;
  if p_day !~ '^\d{4}-\d{2}-\d{2}$' or jsonb_array_length(p_qids) <> 10 then raise exception 'bad'; end if;
  insert into daily_challenge(day, qids, topics) values (p_day, p_qids, p_topics) on conflict (day) do nothing;
  return (select jsonb_build_object('qids', qids, 'topics', topics) from daily_challenge where day = p_day);
end $$;

create or replace function public.daily_submit(p_token uuid, p_day text, p_pts real, p_ms integer, p_detail jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
declare pid uuid; n int;
begin
  if not daily_ok(p_token) then return false; end if;
  select id into pid from profiles where token = p_token;
  insert into daily_results(profile_id, day, pts, ms, detail)
  values (pid, p_day, greatest(0, least(p_pts, 100)), greatest(0, p_ms), p_detail)
  on conflict (profile_id, day) do nothing;
  get diagnostics n = row_count;
  return n > 0;
end $$;

create or replace function public.daily_board(p_token uuid, p_day text)
returns table(nick text, pts real, ms integer)
language plpgsql security definer set search_path = public as $$
begin
  if not daily_ok(p_token) then return; end if;
  return query select p.nick, r.pts, r.ms from daily_results r join profiles p on p.id = r.profile_id
    where r.day = p_day order by r.pts desc, r.ms asc limit 200;
end $$;

grant execute on function public.daily_ok(uuid) to anon, authenticated;
grant execute on function public.daily_get(uuid, text) to anon, authenticated;
grant execute on function public.daily_set(uuid, text, jsonb, jsonb) to anon, authenticated;
grant execute on function public.daily_submit(uuid, text, real, integer, jsonb) to anon, authenticated;
grant execute on function public.daily_board(uuid, text) to anon, authenticated;

-- Aktivnost po gradivu u zadnjih 7 dana (za izbor gradiva u dnevnom izazovu)
create or replace function public.topic_recent()
returns table(topic text, users integer, total integer)
language sql security definer set search_path = public as $$
  with a as (select profile_id, topic from answers where created_at > now() - interval '7 days' and mode <> 'zadaci')
  select topic, count(distinct profile_id)::int, (select count(distinct profile_id)::int from a) from a group by topic;
$$;
grant execute on function public.topic_recent() to anon, authenticated;

-- Prosjek bodova po pitanju (prvi pokušaji) za dnevni izazov
create or replace function public.daily_avg(p_token uuid, p_day text)
returns table(i integer, avg real, n integer)
language plpgsql security definer set search_path = public as $$
begin
  if not daily_ok(p_token) then return; end if;
  return query select (e.ord-1)::int, avg(e.v::real)::real, count(*)::int
    from daily_results r, jsonb_array_elements_text(r.detail->'res') with ordinality as e(v, ord)
    where r.day = p_day group by e.ord order by e.ord;
end $$;
grant execute on function public.daily_avg(uuid, text) to anon, authenticated;

-- ===== dodatak: slobodno (vježba bez bodovanja u Riješeno) =====
-- Ljestvica ukupno: u "Riješeno" se broje i odgovori iz vježbe bez bodovanja (state.freeN).
-- Razina se i dalje računa samo iz bodovanih odgovora.
create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)))
      / sum(greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0))))::real,
    (sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)))::int
  from profiles p, unnest(array['serpar','ruk','estat','kont','cvor','thev','nort','mag']) k
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;

-- ===== dodatak: funkcije (statistika korištenja) =====
-- Statistika korištenja funkcija (zadaci dana, dnevni izazov, ljestvice, preporuka, KZ1, novosti,
-- vježba bez bodovanja, ponavljanje grešaka, povećanje slika, lekcije).
-- Vidljivo samo administratoru (Nastavnik → Analitika → Korištenje funkcija). Smije se pokrenuti više puta.
create table if not exists public.feature_events (
  id bigserial primary key,
  profile_id uuid references public.profiles(id) on delete cascade,
  day text not null,
  feature text not null,
  action text not null,
  detail text,
  created_at timestamptz not null default now()
);
create index if not exists feature_events_day on public.feature_events(day);
create index if not exists feature_events_created on public.feature_events(created_at);
create index if not exists feature_events_pd on public.feature_events(profile_id, day);
alter table public.feature_events enable row level security;
revoke all on public.feature_events from anon, authenticated;

create or replace function public.event_log(p_token uuid, p_feature text, p_action text, p_detail text)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; d text := to_char(now() at time zone 'Europe/Zagreb', 'YYYY-MM-DD'); cnt int;
begin
  select id into pid from profiles where token = p_token;
  if pid is null then return; end if;
  select count(*) into cnt from feature_events where profile_id = pid and day = d;
  if cnt >= 400 then return; end if;
  insert into feature_events(profile_id, day, feature, action, detail)
  values (pid, d, left(coalesce(p_feature,''), 24), left(coalesce(p_action,''), 24), left(p_detail, 60));
end $$;
revoke all on function public.event_log(uuid, text, text, text) from public;
grant execute on function public.event_log(uuid, text, text, text) to anon, authenticated;

drop function if exists public.admin_feature_stats(uuid, integer);
create or replace function public.admin_feature_stats(p_token uuid, p_days integer)
returns table(day text, feature text, action text, detail text, lvl integer, users integer, n integer)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
    select e.day, e.feature, e.action, coalesce(e.detail, '–'), grouping(e.detail)::int * -1 + 1,
           count(distinct e.profile_id)::int, count(*)::int
    from feature_events e
    where e.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 120)))
      and not exists(select 1 from admins a where a.profile_id = e.profile_id)
    group by grouping sets ((e.day, e.feature, e.action), (e.day, e.feature, e.action, e.detail))
    order by 1 desc, 2, 3;
end $$;
revoke all on function public.admin_feature_stats(uuid, integer) from public;
grant execute on function public.admin_feature_stats(uuid, integer) to anon, authenticated;
