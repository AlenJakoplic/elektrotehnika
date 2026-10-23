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
