-- KZ2: odobravanje novog gradiva i ukupna ljestvica s gradivima KZ2.
-- Pokrenuti u Supabase SQL Editoru. Smije se pokrenuti više puta. Očekivani rezultat: Success. No rows returned.
--
-- 1) Tablica content_review: nastavnik (administrator) uz svako pitanje i slajd lekcije sprema
--    „odobreno” ili „treba ispraviti” i komentar. Jedan redak po stavci i nastavniku.
-- 2) review_set / review_list: samo za administratore (provjera kroz tablicu admins).
-- 3) leaderboard_total: dodana gradiva KZ2 (aser, apar, akom). Gradivo KZ2 ulazi u prosjek tek kad
--    je u njemu riješeno barem jedno pitanje (isto pravilo kao overall() u aplikaciji), pa se nikome
--    razina ne mijenja dok ne počne vježbati KZ2. Gradiva KZ1 računaju se kao i prije.

create table if not exists public.content_review (
  item       text not null check (char_length(item) between 1 and 40),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status     text not null check (status in ('ok', 'fix')),
  comment    text not null default '' check (char_length(comment) <= 2000),
  updated_at timestamptz not null default now(),
  primary key (item, profile_id)
);
alter table public.content_review enable row level security;
revoke all on public.content_review from anon, authenticated;

create or replace function public.review_set(p_token uuid, p_item text, p_status text, p_comment text)
returns void
language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  select id into pid from profiles where token = p_token;
  if p_status not in ('ok', 'fix') then raise exception 'bad status'; end if;
  insert into content_review(item, profile_id, status, comment, updated_at)
    values (left(p_item, 40), pid, p_status, left(coalesce(p_comment, ''), 2000), now())
  on conflict (item, profile_id) do update set status = excluded.status, comment = excluded.comment, updated_at = now();
end $$;

drop function if exists public.review_list(uuid);
create or replace function public.review_list(p_token uuid)
returns table(item text, status text, comment text, nick text, updated_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query select r.item, r.status, r.comment, p.nick, r.updated_at
    from content_review r join profiles p on p.id = r.profile_id order by r.updated_at;
end $$;

revoke all on function public.review_set(uuid, text, text, text), public.review_list(uuid) from public;
grant execute on function public.review_set(uuid, text, text, text), public.review_list(uuid) to anon, authenticated;

create or replace function public.leaderboard_total()
returns table(nick text, r real, n integer)
language sql security definer set search_path = public as $$
  select p.nick,
    (sum(coalesce((p.state->'ratings'->k->>'r')::real, 2) * w.w) / nullif(sum(w.w), 0))::real,
    (sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)))::int
  from profiles p,
    unnest(array['serpar','ruk','estat','kont','cvor','thev','nort','mag','aser','apar','akom']) k,
    lateral (select case when k in ('aser','apar','akom') and coalesce((p.state->'ratings'->k->>'n')::int, 0) = 0 then 0
                         else greatest(1, coalesce((p.state->'ratings'->k->>'n')::int, 0)) end as w) w
  group by p.id, p.nick
  having sum(coalesce((p.state->'ratings'->k->>'n')::int, 0)) + max(coalesce((p.state->>'freeN')::int, 0)) > 0
  order by 2 desc limit 200;
$$;
revoke all on function public.leaderboard_total from public;
grant execute on function public.leaderboard_total to anon, authenticated;
