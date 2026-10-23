-- Povratne informacije studenata (poruke, prijave grešaka, ankete). Pokreni jednom u SQL Editoru.
create table if not exists public.feedback (
  id         bigserial primary key,
  profile_id uuid references public.profiles(id) on delete set null,
  kind       text not null,
  qid        text,
  page       text,
  msg        text,
  rating     integer,
  extra      jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;

create table if not exists public.feedback_rl (
  profile_id uuid references public.profiles(id) on delete cascade,
  day        date not null default current_date,
  n          integer not null default 0,
  primary key (profile_id, day)
);
alter table public.feedback_rl enable row level security;
revoke all on public.feedback_rl from anon, authenticated;

create table if not exists public.admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;
-- Administrator: profil s nadimkom Alen.
insert into public.admins(profile_id) select id from public.profiles where nick = 'Alen' on conflict do nothing;

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
  insert into feedback(profile_id, kind, qid, page, msg, rating, extra)
  values (case when p_anon then null else pid end, left(coalesce(p_kind,''),20), left(p_qid,40), left(p_page,40),
          left(p_msg,3000), case when p_rating between 1 and 5 then p_rating end, coalesce(p_extra,'{}'::jsonb));
end $$;

create or replace function public.is_admin(p_token uuid)
returns boolean
language sql security definer set search_path = public as $$
  select exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token);
$$;

create or replace function public.feedback_list(p_token uuid)
returns table(id bigint, created_at timestamptz, nick text, kind text, qid text, page text, msg text, rating integer, extra jsonb)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query select f.id, f.created_at, p.nick, f.kind, f.qid, f.page, f.msg, f.rating, f.extra
    from feedback f left join profiles p on p.id = f.profile_id order by f.created_at desc limit 1000;
end $$;

revoke all on function public.feedback_send, public.is_admin, public.feedback_list from public;
grant execute on function public.feedback_send, public.is_admin, public.feedback_list to anon, authenticated;

-- Pitanja nastavniku (nisu anonimna), s odgovorom u aplikaciji.
alter table public.feedback add column if not exists email text;
alter table public.feedback add column if not exists reply text;
alter table public.feedback add column if not exists replied_at timestamptz;
alter table public.feedback add column if not exists seen boolean not null default false;

create or replace function public.ask_send(p_token uuid, p_qid text, p_page text, p_msg text, p_email text, p_ctx jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare pid uuid; cnt integer;
begin
  select id into pid from profiles where token = p_token;
  if pid is null then raise exception 'no_session'; end if;
  insert into feedback_rl(profile_id, day, n) values (pid, current_date, 1)
    on conflict (profile_id, day) do update set n = feedback_rl.n + 1 returning n into cnt;
  if cnt > 30 then raise exception 'too_many'; end if;
  insert into feedback(profile_id, kind, qid, page, msg, email, extra)
  values (pid, 'pitanje', left(p_qid,40), left(p_page,40), left(p_msg,3000), nullif(left(btrim(coalesce(p_email,'')),120),''), coalesce(p_ctx,'{}'::jsonb));
end $$;

create or replace function public.my_questions(p_token uuid)
returns table(id bigint, created_at timestamptz, qid text, msg text, reply text, replied_at timestamptz, seen boolean)
language sql security definer set search_path = public as $$
  select f.id, f.created_at, f.qid, f.msg, f.reply, f.replied_at, f.seen
  from feedback f join profiles p on p.id = f.profile_id
  where p.token = p_token and f.kind = 'pitanje' order by f.created_at desc limit 200;
$$;

create or replace function public.my_questions_seen(p_token uuid)
returns void
language sql security definer set search_path = public as $$
  update feedback f set seen = true from profiles p
  where p.id = f.profile_id and p.token = p_token and f.kind = 'pitanje' and f.reply is not null;
$$;

create or replace function public.feedback_reply(p_token uuid, p_id bigint, p_reply text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  update feedback set reply = left(p_reply,4000), replied_at = now(), seen = false where id = p_id;
end $$;

drop function if exists public.feedback_list(uuid);
create or replace function public.feedback_list(p_token uuid)
returns table(id bigint, created_at timestamptz, nick text, kind text, qid text, page text, msg text, rating integer, extra jsonb, email text, reply text, replied_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query select f.id, f.created_at, p.nick, f.kind, f.qid, f.page, f.msg, f.rating, f.extra, f.email, f.reply, f.replied_at
    from feedback f left join profiles p on p.id = f.profile_id order by f.created_at desc limit 1000;
end $$;

revoke all on function public.ask_send, public.my_questions, public.my_questions_seen, public.feedback_reply, public.feedback_list from public;
grant execute on function public.ask_send, public.my_questions, public.my_questions_seen, public.feedback_reply, public.feedback_list to anon, authenticated;
