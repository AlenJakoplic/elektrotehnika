-- Ljestvica simulacija KZ1 (najbolji rezultat iz state.kz.best, stadij pripreme iz state.kz.stage).
drop function if exists public.leaderboard_kz();
create or replace function public.leaderboard_kz()
returns table(nick text, best real, n integer, stage integer)
language sql security definer set search_path = public as $$
  select p.nick,
         coalesce((p.state->'kz'->>'best')::real, 0),
         coalesce(jsonb_array_length(p.state->'kz'->'sims'), 0),
         coalesce((p.state->'kz'->>'stage')::int, 1)
  from profiles p
  where p.state ? 'kz'
  order by 2 desc, 4 desc, 3 desc limit 200;
$$;
revoke all on function public.leaderboard_kz from public;
grant execute on function public.leaderboard_kz to anon, authenticated;
