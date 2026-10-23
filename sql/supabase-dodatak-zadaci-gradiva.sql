-- Ljestvica Zadataka po gradivima (zbraja bodove iz state.zad.t za zadane vrste zadataka).
create or replace function public.leaderboard_zad_g(p_types text[])
returns table(nick text, pts real, n integer, full_n integer)
language sql security definer set search_path = public as $$
  select p.nick,
         sum(coalesce((t.value->>'pts')::real, 0))::real,
         sum(coalesce((t.value->>'n')::int, 0))::int,
         sum(coalesce((p.state->'zad'->'full'->>t.key)::int, 0))::int
  from profiles p, jsonb_each(coalesce(p.state->'zad'->'t', '{}'::jsonb)) t
  where t.key = any(p_types)
  group by p.nick
  having sum(coalesce((t.value->>'n')::int, 0)) > 0
  order by 2 desc, 4 desc limit 200;
$$;
revoke all on function public.leaderboard_zad_g from public;
grant execute on function public.leaderboard_zad_g to anon, authenticated;
