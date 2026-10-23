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
