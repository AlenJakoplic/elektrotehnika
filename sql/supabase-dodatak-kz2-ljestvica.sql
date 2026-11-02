-- KZ2: ukupna ljestvica s gradivima KZ2 (auvod, aser, apar, akom).
-- Pokrenuti u Supabase SQL Editoru. Smije se pokrenuti više puta. Očekivani rezultat: Success. No rows returned.
-- Gradivo KZ2 ulazi u prosjek tek kad je u njemu riješeno barem jedno pitanje (isto pravilo kao overall() u aplikaciji),
-- pa se nikome razina ne mijenja dok ne počne vježbati KZ2. Gradiva KZ1 računaju se kao i prije.
-- Zamjenjuje leaderboard_total iz supabase-dodatak-slobodno.sql.

create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * w.w) / nullif(sum(w.w), 0))::real,
    (sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)))::int
  from profiles p,
    unnest(array['serpar','ruk','estat','kont','cvor','thev','nort','mag','auvod','aser','apar','akom']) k,
    lateral (select case when k in ('auvod','aser','apar','akom') and coalesce((p.state->'ratings'->k->>'n')::int, 0) = 0 then 0
                         else greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)) end as w) w
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;
