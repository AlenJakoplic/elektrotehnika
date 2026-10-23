-- Statistika korištenja funkcija (zadaci dana, dnevni izazov, ljestvice, preporuka, KZ1, novosti,
-- vježba bez bodovanja, ponavljanje grešaka, povećanje slika, lekcije).
-- Vidljivo samo administratoru (Nastavnik → Analitika → Korištenje funkcija). Smije se pokrenuti više puta.
create table if not exists public.feature_events (
  id bigserial primary key,
  profile_id uuid references public.profiles(id) on delete cascade,
  day text not null,
  feature text not null,
  action text not null,
  detail text,
  created_at timestamptz not null default now()
);
create index if not exists feature_events_day on public.feature_events(day);
create index if not exists feature_events_created on public.feature_events(created_at);
create index if not exists feature_events_pd on public.feature_events(profile_id, day);
alter table public.feature_events enable row level security;
revoke all on public.feature_events from anon, authenticated;

create or replace function public.event_log(p_token uuid, p_feature text, p_action text, p_detail text)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; d text := to_char(now() at time zone 'Europe/Zagreb', 'YYYY-MM-DD'); cnt int;
begin
  select id into pid from profiles where token = p_token;
  if pid is null then return; end if;
  select count(*) into cnt from feature_events where profile_id = pid and day = d;
  if cnt >= 400 then return; end if;
  insert into feature_events(profile_id, day, feature, action, detail)
  values (pid, d, left(coalesce(p_feature,''), 24), left(coalesce(p_action,''), 24), left(p_detail, 60));
end $$;
revoke all on function public.event_log(uuid, text, text, text) from public;
grant execute on function public.event_log(uuid, text, text, text) to anon, authenticated;

drop function if exists public.admin_feature_stats(uuid, integer);
create or replace function public.admin_feature_stats(p_token uuid, p_days integer)
returns table(day text, feature text, action text, detail text, lvl integer, users integer, n integer)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
    select e.day, e.feature, e.action, coalesce(e.detail, '–'), grouping(e.detail)::int * -1 + 1,
           count(distinct e.profile_id)::int, count(*)::int
    from feature_events e
    where e.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 120)))
      and not exists(select 1 from admins a where a.profile_id = e.profile_id)
    group by grouping sets ((e.day, e.feature, e.action), (e.day, e.feature, e.action, e.detail))
    order by 1 desc, 2, 3;
end $$;
revoke all on function public.admin_feature_stats(uuid, integer) from public;
grant execute on function public.admin_feature_stats(uuid, integer) to anon, authenticated;
