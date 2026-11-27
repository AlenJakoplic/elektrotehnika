-- KZ2 nova gradiva (27. 11. 2026.): ukupna ljestvica broji i nova gradiva KZ2
-- (ser2, par2, kzp2, kon2, cvr2, rez2), a stara (auvod, aser, apar, akom) ostaju jer ih koristi prethodna verzija aplikacije.
-- Gradivo KZ2 ulazi u prosjek tek kad je u njemu riješeno barem jedno pitanje (isto pravilo kao overall() u aplikaciji).
-- Zamjenjuje leaderboard_total iz supabase-dodatak-kz2-ljestvica.sql. Smije se pokrenuti više puta.
-- Pokrenuti u Supabase SQL Editoru. Očekivani rezultat: Success. No rows returned.

create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * w.w) / nullif(sum(w.w), 0))::real,
    (sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)))::int
  from profiles p,
    unnest(array['serpar','ruk','estat','kont','cvor','thev','nort','mag','auvod','aser','apar','akom','ser2','par2','kzp2','kon2','cvr2','rez2']) k,
    lateral (select case when k in ('auvod','aser','apar','akom','ser2','par2','kzp2','kon2','cvr2','rez2') and coalesce((p.state->'ratings'->k->>'n')::int, 0) = 0 then 0
                         else greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)) end as w) w
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;
