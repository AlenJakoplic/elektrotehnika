-- Dodaje korisnika s nadimkom ns kao administratora (nastavnika). Smije se pokrenuti više puta.
insert into public.admins(profile_id)
select id from public.profiles where lower(nick) = lower('ns')
on conflict do nothing;
-- Provjera: treba vratiti jedan red s nadimkom ns.
select p.nick from public.admins a join public.profiles p on p.id = a.profile_id where lower(p.nick) = 'ns';
