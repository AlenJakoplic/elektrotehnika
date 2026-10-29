-- Ljestvica probne po kolokviju (KZ1, KZ2, KZ3).
-- Čita state.kzs.<kz1|kz2|kz3> (best, sims, stage), isti oblik kao stari state.kz.
-- Za KZ1, ako kzs.kz1 još nema, pada na stari state.kz.
-- Funkcija leaderboard_kz() se ne dira: stara ljestvica Probna KZ1 i dalje radi.
-- Sigurno za ponovno pokretanje, ništa se ne briše.
-- Očekivani rezultat u SQL Editoru: Success. No rows returned.

drop function if exists public.leaderboard_kz_exam(text);

create or replace function public.leaderboard_kz_exam(p_exam text)
returns table(nick text, best real, n integer, stage integer)
language sql
security definer
set search_path = public
as $$
  select p.nick,
         coalesce((s.slot->>'best')::real, 0),
         coalesce(jsonb_array_length(s.slot->'sims'), 0),
         coalesce((s.slot->>'stage')::int, 1)
  from public.profiles p,
  lateral (
    select case
      when p_exam in ('kz1','kz2','kz3') and (p.state->'kzs') ? p_exam
        then p.state->'kzs'->p_exam
      when p_exam = 'kz1' and p.state ? 'kz'
        then p.state->'kz'
    end as slot
  ) s
  where s.slot is not null
  order by 2 desc, 4 desc, 3 desc
  limit 200;
$$;

revoke all on function public.leaderboard_kz_exam(text) from public;
grant execute on function public.leaderboard_kz_exam(text) to anon, authenticated;
