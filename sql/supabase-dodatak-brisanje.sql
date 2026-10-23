-- Dodatak: brisanje profila. Pokreni jednom u SQL Editoru.

-- Brisanje vlastitog profila (uz PIN). Briše i sve odgovore tog profila.
create or replace function public.delete_profile(p_token uuid, p_pin text)
returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  delete from profiles where token = p_token and pin_hash = crypt(p_pin, pin_hash);
  if not found then raise exception 'bad_pin'; end if;
end $$;
revoke all on function public.delete_profile from public;
grant execute on function public.delete_profile to anon, authenticated;
