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
