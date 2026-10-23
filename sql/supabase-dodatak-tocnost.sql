-- Dodatak: točnost je zadano skrivena; prikazuje se samo ako je student uključi. Pokreni jednom u SQL Editoru.

create or replace function public.leaderboard(p_topic text)
returns table(nick text, r real, n integer, c integer)
language sql security definer set search_path = public as $$
  select p.nick, (p.state->'ratings'->p_topic->>'r')::real, (p.state->'ratings'->p_topic->>'n')::int,
         case when coalesce((p.state->>'showAcc')::boolean, false) then (p.state->'ratings'->p_topic->>'c')::int end
  from profiles p
  where coalesce((p.state->'ratings'->p_topic->>'n')::int, 0) > 0
  order by 2 desc limit 200;
$$;

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
                                    'n', coalesce(p.state->'zad'->'n', '0'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;
