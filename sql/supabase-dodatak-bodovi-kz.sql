-- Nastavnik → Analitika → Upisani bodovi KZ (3. 11. 2026.). Smije se pokrenuti više puta.
-- Vraća nadimak i state.grades za sve profile koji nisu administratori (samo za administratora).
create or replace function public.admin_grades(p_token uuid)
returns table(nick text, grades jsonb)
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  return query select p.nick, coalesce(p.state->'grades', '{}'::jsonb)
    from profiles p where not exists(select 1 from admins a where a.profile_id = p.id)
    order by p.nick;
end $$;
revoke all on function public.admin_grades(uuid) from public;
grant execute on function public.admin_grades(uuid) to anon, authenticated;
