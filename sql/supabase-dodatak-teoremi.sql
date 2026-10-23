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
