-- Analitika za nastavnika (samo administratori)
create or replace function public.admin_students(p_token uuid)
returns table(nick text, full_name text, created_at timestamptz, updated_at timestamptz, state jsonb, answers_n integer, last_answer timestamptz, days7 integer)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select p.nick, p.full_name, p.created_at, p.updated_at, p.state,
         coalesce(a.n,0)::int, a.last, coalesce(a.d7,0)::int
  from profiles p
  left join (select profile_id, count(*) n, max(answers.created_at) last,
                    count(distinct (answers.created_at at time zone 'Europe/Zagreb')::date) filter (where answers.created_at > now() - interval '7 days') d7
             from answers group by profile_id) a on a.profile_id = p.id
  where not exists(select 1 from admins x where x.profile_id = p.id)
  order by a.last desc nulls last;
end $$;

create or replace function public.admin_activity(p_token uuid)
returns table(day date, hour integer, n integer, users integer)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select (a.created_at at time zone 'Europe/Zagreb')::date, extract(hour from a.created_at at time zone 'Europe/Zagreb')::int,
         count(*)::int, count(distinct a.profile_id)::int
  from answers a where a.created_at > now() - interval '60 days'
  group by 1, 2 order by 1, 2;
end $$;

create or replace function public.admin_questions(p_token uuid)
returns table(qid text, topic text, n integer, users integer, avg_score real, help real)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select a.qid, min(a.topic), count(*)::int, count(distinct a.profile_id)::int, avg(a.score)::real, avg(case when a.used_help then 1 else 0 end)::real
  from answers a group by a.qid having count(*) >= 3 order by avg(a.score) asc limit 300;
end $$;

create or replace function public.admin_student_answers(p_token uuid, p_nick text)
returns table(qid text, topic text, score real, used_help boolean, mode text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query
  select a.qid, a.topic, a.score, a.used_help, a.mode, a.created_at
  from answers a join profiles p on p.id = a.profile_id
  where lower(p.nick) = lower(p_nick) order by a.created_at desc limit 500;
end $$;

grant execute on function public.admin_students(uuid) to anon, authenticated;
grant execute on function public.admin_activity(uuid) to anon, authenticated;
grant execute on function public.admin_questions(uuid) to anon, authenticated;
grant execute on function public.admin_student_answers(uuid, text) to anon, authenticated;
