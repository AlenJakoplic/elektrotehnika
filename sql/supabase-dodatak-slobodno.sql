-- Ljestvica ukupno: sva gradiva kao "ukupna razina" u aplikaciji (serija/paralela, ukupni otpor, elektrostatika,
-- konturne struje, naponi čvorova, Thevenin, Norton, magnetsko polje), a u "Riješeno" se broje i odgovori
-- iz vježbe bez bodovanja (state.freeN). Razina se računa samo iz bodovanih odgovora. Smije se pokrenuti više puta.
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
