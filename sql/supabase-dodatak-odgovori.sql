-- Odgovori nastavnika na prijave grešaka i povratne informacije (26. 10. 2026.). Smije se pokrenuti više puta.
-- Prijava s nadimkom: odgovor vidi samo taj student (Napredak → Moja pitanja i prijave).
-- Anonimna prijava: veza sa studentom ne postoji, pa se odgovor prikazuje svima uz taj zadatak
-- (ili na Napretku ako poruka nije vezana uz zadatak), bez teksta prijave.

-- Moja pitanja i prijave: pitanja nastavniku i sve moje poruke na koje je stigao odgovor (osim anketa).
drop function if exists public.my_questions(uuid);
create or replace function public.my_questions(p_token uuid)
returns table(id bigint, created_at timestamptz, kind text, qid text, msg text, reply text, replied_at timestamptz, seen boolean)
language sql security definer set search_path = public as $$
  select f.id, f.created_at, f.kind, f.qid, f.msg, f.reply, f.replied_at, f.seen
  from feedback f join profiles p on p.id = f.profile_id
  where p.token = p_token and (f.kind = 'pitanje' or (f.reply is not null and f.kind <> 'anketa'))
  order by f.created_at desc limit 200;
$$;

create or replace function public.my_questions_seen(p_token uuid)
returns void
language sql security definer set search_path = public as $$
  update feedback f set seen = true from profiles p
  where p.id = f.profile_id and p.token = p_token and f.reply is not null and f.kind <> 'anketa';
$$;

create or replace function public.my_question_delete(p_token uuid, p_id bigint)
returns void
language sql security definer set search_path = public as $$
  delete from feedback f using profiles p
  where f.id = p_id and p.id = f.profile_id and p.token = p_token and f.kind <> 'anketa';
$$;

-- Javni odgovori na anonimne poruke (samo odgovor i oznaka zadatka, bez teksta poruke).
create or replace function public.public_replies(p_token uuid)
returns table(id bigint, qid text, reply text, replied_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from profiles where token = p_token) then raise exception 'no_session'; end if;
  return query select f.id, f.qid, f.reply, f.replied_at from feedback f
    where f.profile_id is null and f.reply is not null and f.kind not in ('anketa','pitanje')
    order by f.replied_at desc limit 300;
end $$;

revoke all on function public.my_questions(uuid), public.my_questions_seen(uuid), public.my_question_delete(uuid, bigint), public.public_replies(uuid) from public;
grant execute on function public.my_questions(uuid), public.my_questions_seen(uuid), public.my_question_delete(uuid, bigint), public.public_replies(uuid) to anon, authenticated;
