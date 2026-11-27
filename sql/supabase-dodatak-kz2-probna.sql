-- Probna KZ2 i nova gradiva (27. 11. 2026.):
-- 1) ljestvica probne KZ2: čita state.kz2 (best, sims, stage), isto kao leaderboard_kz za KZ1 (bez administratora);
-- 2) ukupna ljestvica broji i gradiva Snaga i trokut snage (sn2) te Thevenin i Norton (tn2).
-- Smije se pokrenuti više puta, ništa se ne briše.
-- Pokrenuti u Supabase SQL Editoru. Očekivani rezultat: Success. No rows returned.

create or replace function public.leaderboard_kz2()
returns table(nick text, best real, n integer, stage integer)
language sql security definer set search_path = public as $$
  select p.nick,
         coalesce((p.state->'kz2'->>'best')::real, 0),
         coalesce(jsonb_array_length(p.state->'kz2'->'sims'), 0),
         coalesce((p.state->'kz2'->>'stage')::int, 1)
  from profiles p
  where p.state ? 'kz2'
    and not exists (select 1 from admins a where a.profile_id = p.id)
  order by 2 desc, 4 desc, 3 desc limit 200;
$$;
revoke all on function public.leaderboard_kz2 from public;
grant execute on function public.leaderboard_kz2 to anon, authenticated;

-- ukupna ljestvica (zamjenjuje onu iz supabase-dodatak-kz2-nova-gradiva.sql)
create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * w.w) / nullif(sum(w.w), 0))::real,
    (sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)))::int
  from profiles p,
    unnest(array['serpar','ruk','estat','kont','cvor','thev','nort','mag','auvod','aser','apar','akom','ser2','par2','kzp2','kon2','cvr2','rez2','sn2','tn2']) k,
    lateral (select case when k in ('auvod','aser','apar','akom','ser2','par2','kzp2','kon2','cvr2','rez2','sn2','tn2') and coalesce((p.state->'ratings'->k->>'n')::int, 0) = 0 then 0
                         else greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)) end as w) w
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;
