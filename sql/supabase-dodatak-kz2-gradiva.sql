-- KZ2 gradiva u ukupnoj ljestvici i preskok gradiva bez ijednog odgovora.
-- Alen je 29. 10. 2026. odobrio: gradivo s n = 0 ne ulazi u prosjek.
-- Isto pravilo je omotač funkcije overall() u test.html.
-- Ova datoteka NIJE pokrenuta. Pokrenuti je tek kad Alen kaže, u Supabase SQL Editoru.
-- Očekivani rezultat: Success. No rows returned.
-- Zamjenjuje public.leaderboard_total iz supabase-dodatak-slobodno.sql.
-- Razina = sum(r·n) / sum(n) samo za gradiva s n > 0. Ako su svi n = 0, a ima vježbe bez bodovanja, razina je 1.
-- Riješeno i dalje broji sum(n) + odgovore iz vježbe bez bodovanja (freeN).
-- Gradiva su ista kao overall() u aplikaciji: KZ1 (serpar, ruk, estat, kont, cvor, thev, nort, mag)
-- i KZ2 (ind, izmj, vser, vpar, asnaga, kompl, akont, acvor, athev, anort, asup, aprl, rez).
-- Smije se pokrenuti više puta (create or replace, isti povratni tip).

create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    coalesce(
      (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * coalesce((p.state->'ratings'->k->>'n')::int, 0))
        / nullif(sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)), 0))::real,
      1::real),
    (sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)))::int
  from profiles p,
    unnest(array['serpar','ruk','estat','kont','cvor','thev','nort','mag','ind','izmj','vser','vpar','asnaga','kompl','akont','acvor','athev','anort','asup','aprl','rez']) k
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)) > 0
  order by 2 desc
  limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;
