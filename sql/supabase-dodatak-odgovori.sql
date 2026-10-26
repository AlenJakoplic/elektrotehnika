-- Odgovori nastavnika na prijave grešaka i povratne informacije (26. 10. 2026.). Smije se pokrenuti više puta.
-- Poruka s nadimkom: odgovor vidi taj student (Napredak → Moja pitanja i prijave).
-- Anonimna poruka: baza uz nju sprema skrivenu vezu na pošiljatelja (owner_id). Nastavnik u aplikaciji
--   i dalje vidi samo „anonimno”, a odgovor stiže pošiljatelju na Napredak.
--   Isto vrijedi i za ankete.
-- Nastavnik može odgovor prikazati i svima (uz zadatak ili na Napretku, bez teksta poruke).
-- Starije anonimne poruke nemaju vezu, pa je za njih odgovor uvijek javan.

alter table public.feedback add column if not exists owner_id uuid references public.profiles(id) on delete set null;
alter table public.feedback add column if not exists public_reply boolean not null default false;

create or replace function public.feedback_send(p_token uuid, p_anon boolean, p_kind text, p_qid text, p_page text, p_msg text, p_rating integer, p_extra jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare pid uuid; cnt integer;
begin
  select id into pid from profiles where token = p_token;
  if pid is null then raise exception 'no_session'; end if;
  insert into feedback_rl(profile_id, day, n) values (pid, current_date, 1)
    on conflict (profile_id, day) do update set n = feedback_rl.n + 1 returning n into cnt;
  if cnt > 30 then raise exception 'too_many'; end if;
  insert into feedback(profile_id, owner_id, kind, qid, page, msg, rating, extra)
  values (case when p_anon then null else pid end, pid, left(coalesce(p_kind,''),20), left(p_qid,40), left(p_page,40),
          left(p_msg,3000), case when p_rating between 1 and 5 then p_rating end, coalesce(p_extra,'{}'::jsonb));
end $$;

-- Odgovor nastavnika. p_public: prikaži odgovor i svima (null = zadrži; stara anonimna poruka bez veze je uvijek javna).
drop function if exists public.feedback_reply(uuid, bigint, text);
create or replace function public.feedback_reply(p_token uuid, p_id bigint, p_reply text, p_public boolean default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  update feedback set reply = left(p_reply,4000), replied_at = now(), seen = false,
    public_reply = case when profile_id is null and owner_id is null then true else coalesce(p_public, public_reply) end
  where id = p_id;
end $$;

-- Popis za nastavnika: bez pošiljatelja anonimnih poruka; linked = odgovor može stići pošiljatelju.
drop function if exists public.feedback_list(uuid);
create or replace function public.feedback_list(p_token uuid)
returns table(id bigint, created_at timestamptz, nick text, kind text, qid text, page text, msg text, rating integer, extra jsonb, email text, reply text, replied_at timestamptz, linked boolean, public_reply boolean)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query select f.id, f.created_at, p.nick, f.kind, f.qid, f.page, f.msg, f.rating, f.extra, f.email, f.reply, f.replied_at,
      (f.profile_id is not null or f.owner_id is not null), f.public_reply
    from feedback f left join profiles p on p.id = f.profile_id order by f.created_at desc limit 1000;
end $$;

-- Moja pitanja i prijave: pitanja nastavniku i moje poruke i ankete (i anonimne) na koje je stigao odgovor.
drop function if exists public.my_questions(uuid);
create or replace function public.my_questions(p_token uuid)
returns table(id bigint, created_at timestamptz, kind text, qid text, msg text, reply text, replied_at timestamptz, seen boolean, anon boolean)
language sql security definer set search_path = public as $$
  select f.id, f.created_at, f.kind, f.qid, f.msg, f.reply, f.replied_at, f.seen, f.profile_id is null
  from feedback f join profiles p on p.id = coalesce(f.profile_id, f.owner_id)
  where p.token = p_token and (f.kind = 'pitanje' or f.reply is not null)
  order by f.created_at desc limit 200;
$$;

create or replace function public.my_questions_seen(p_token uuid)
returns void
language sql security definer set search_path = public as $$
  update feedback f set seen = true from profiles p
  where p.id = coalesce(f.profile_id, f.owner_id) and p.token = p_token and f.reply is not null;
$$;

create or replace function public.my_question_delete(p_token uuid, p_id bigint)
returns void
language sql security definer set search_path = public as $$
  delete from feedback f using profiles p
  where f.id = p_id and p.id = coalesce(f.profile_id, f.owner_id) and p.token = p_token;
$$;

-- Javni odgovori (samo odgovor i oznaka zadatka, bez teksta poruke).
create or replace function public.public_replies(p_token uuid)
returns table(id bigint, qid text, reply text, replied_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from profiles where token = p_token) then raise exception 'no_session'; end if;
  return query select f.id, f.qid, f.reply, f.replied_at from feedback f
    where f.reply is not null and f.kind <> 'pitanje'
      and (f.public_reply or (f.profile_id is null and f.owner_id is null))
    order by f.replied_at desc limit 300;
end $$;

revoke all on function public.feedback_send(uuid, boolean, text, text, text, text, integer, jsonb), public.feedback_reply(uuid, bigint, text, boolean),
  public.feedback_list(uuid), public.my_questions(uuid), public.my_questions_seen(uuid), public.my_question_delete(uuid, bigint), public.public_replies(uuid) from public;
grant execute on function public.feedback_send(uuid, boolean, text, text, text, text, integer, jsonb), public.feedback_reply(uuid, bigint, text, boolean),
  public.feedback_list(uuid), public.my_questions(uuid), public.my_questions_seen(uuid), public.my_question_delete(uuid, bigint), public.public_replies(uuid) to anon, authenticated;
