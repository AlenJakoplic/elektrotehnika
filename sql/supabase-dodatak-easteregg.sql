-- Dodatak: tko je pronašao easter egg. Pokreni jednom u SQL Editoru.

create table if not exists public.easter_egg (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  found_at   timestamptz not null default now()
);
alter table public.easter_egg enable row level security;
revoke all on public.easter_egg from anon, authenticated;

create or replace function public.egg_found(p_token uuid)
returns void
language sql security definer set search_path = public as $$
  insert into easter_egg(profile_id) select id from profiles where token = p_token
  on conflict (profile_id) do nothing;
$$;

create or replace function public.egg_list()
returns table(nick text, found_at timestamptz)
language sql security definer set search_path = public as $$
  select p.nick, e.found_at from easter_egg e join profiles p on p.id = e.profile_id
  order by e.found_at limit 500;
$$;

revoke all on function public.egg_found, public.egg_list from public;
grant execute on function public.egg_found, public.egg_list to anon, authenticated;
