-- Dodatak: javni profil, ime i prezime (vidi samo nastavnik), tjedna liga.
-- Pokreni jednom u SQL Editoru.

alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists show_name boolean not null default false;

-- Vlastito ime (samo uz vlastiti token).
create or replace function public.get_me(p_token uuid)
returns table(full_name text, show_name boolean)
language sql security definer set search_path = public as $$
  select p.full_name, p.show_name from profiles p where p.token = p_token;
$$;

create or replace function public.set_name(p_token uuid, p_name text, p_show boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update profiles set full_name = nullif(left(btrim(coalesce(p_name, '')), 60), ''),
                      show_name = coalesce(p_show, false) and nullif(btrim(coalesce(p_name, '')), '') is not null
  where token = p_token;
  if not found then raise exception 'bad_token'; end if;
end $$;

-- Javni profil: samo razine, niz dana, značke i bodovi. Bez zamki i pojedinih odgovora.
-- Ime se vraća samo ako je student sam uključio prikaz.
create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'ratings', coalesce(p.state->'ratings', '{}'::jsonb),
      'days',    coalesce(p.state->'days', '{}'::jsonb),
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;

-- Tjedna liga: bodovi u tekućem tjednu (tjedan počinje u ponedjeljak).
create or replace function public.leaderboard_week(p_week text)
returns table(nick text, pts real)
language sql security definer set search_path = public as $$
  select p.nick, (p.state->'week'->>'pts')::real
  from profiles p
  where p.state->'week'->>'id' = p_week and coalesce((p.state->'week'->>'pts')::real, 0) > 0
  order by 2 desc limit 200;
$$;

revoke all on function public.get_me, public.set_name, public.public_profile, public.leaderboard_week from public;
grant execute on function public.get_me, public.set_name, public.public_profile, public.leaderboard_week to anon, authenticated;
