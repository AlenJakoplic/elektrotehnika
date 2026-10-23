-- Dodatak: ljestvica Zadataka. Pokreni jednom u SQL Editoru.
create or replace function public.leaderboard_zad()
returns table(nick text, pts real, n integer, full_n integer)
language sql security definer set search_path = public as $$
  select p.nick,
         coalesce((p.state->'zad'->>'pts')::real, 0),
         coalesce((p.state->'zad'->>'n')::int, 0),
         coalesce((select sum(value::int) from jsonb_each_text(coalesce(p.state->'zad'->'full', '{}'::jsonb))), 0)::int
  from profiles p
  where coalesce((p.state->'zad'->>'n')::int, 0) > 0
  order by 2 desc, 4 desc limit 200;
$$;
revoke all on function public.leaderboard_zad from public;
grant execute on function public.leaderboard_zad to anon, authenticated;

-- Statistika Zadataka za sve (zbirno).
create or replace function public.stats_zad()
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'users', (select count(distinct profile_id) from answers where mode = 'zadaci'),
    'n',     (select count(*) from answers where mode = 'zadaci'),
    'avg',   (select avg(score) from answers where mode = 'zadaci'),
    'full',  (select count(*) from answers where mode = 'zadaci' and score >= 0.999),
    'types', coalesce((select jsonb_object_agg(topic, v) from (
        select topic, jsonb_build_object('n', count(*), 'users', count(distinct profile_id), 'avg', avg(score),
                                         'full', count(*) filter (where score >= 0.999)) v
        from answers where mode = 'zadaci' group by topic) t), '{}'::jsonb));
$$;
revoke all on function public.stats_zad from public;
grant execute on function public.stats_zad to anon, authenticated;

-- Javni profil: dodani bodovi iz Zadataka.
create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'showAcc', coalesce((p.state->>'showAcc')::boolean, false),
      'ratings', case when coalesce((p.state->>'showAcc')::boolean, false) then coalesce(p.state->'ratings', '{}'::jsonb)
                      else coalesce((select jsonb_object_agg(k, v - 'c') from jsonb_each(coalesce(p.state->'ratings', '{}'::jsonb)) e(k, v)), '{}'::jsonb) end,
      'days',    coalesce(p.state->'days', '{}'::jsonb) - 'free' - 'run',
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb),
                                    'n', coalesce(p.state->'zad'->'n', '0'::jsonb),
                                    'pts', coalesce(p.state->'zad'->'pts', '0'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;
