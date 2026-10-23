-- Brisanje pitanja (student) i povratnih informacija (nastavnik)
create or replace function public.my_question_delete(p_token uuid, p_id bigint)
returns void
language sql security definer set search_path = public as $$
  delete from feedback f using profiles p
  where f.id = p_id and p.id = f.profile_id and p.token = p_token and f.kind = 'pitanje';
$$;

create or replace function public.feedback_delete(p_token uuid, p_id bigint)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  delete from feedback where id = p_id;
end $$;

grant execute on function public.my_question_delete(uuid, bigint) to anon, authenticated;
grant execute on function public.feedback_delete(uuid, bigint) to anon, authenticated;
