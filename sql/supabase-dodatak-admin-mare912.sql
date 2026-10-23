-- Dodaje korisnika s nadimkom mare912 kao administratora (vidi Nastavnik: Povratne i Analitika).
-- Profil s tim nadimkom mora već postojati u aplikaciji. Smije se pokrenuti više puta.
insert into public.admins(profile_id)
select id from public.profiles where lower(nick) = lower('mare912')
on conflict do nothing;

-- Provjera: popis svih administratora
select p.nick, p.created_at from public.admins a join public.profiles p on p.id = a.profile_id order by p.created_at;
