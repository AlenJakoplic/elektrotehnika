# SQL dodaci za Supabase

`../supabase.sql` je osnovna shema iz prvih verzija (profili, odgovori, ljestvice…) s nekim kasnijim dodacima na kraju.
Svaki kasniji dodatak je zasebna datoteka u ovoj mapi. Sve su pisane tako da se smiju pokrenuti više puta
(`create table if not exists`, `create or replace function`) i ne brišu postojeće podatke.

Redoslijed kako su nastajali (za novu bazu: prvo `supabase.sql`, zatim ovim redom):

| Datum | Datoteka | Što dodaje |
| --- | --- | --- |
| 9. 10. | supabase-dodatak-brisanje.sql | brisanje vlastitog profila |
| 9. 10. | supabase-dodatak-ukupno.sql | ukupna ljestvica (kasnije zamijenjena, vidi slobodno) |
| 10. 10. | supabase-dodatak-profil.sql | javni profil, ime i prezime, tjedna liga |
| 12. 10. | supabase-dodatak-nadimak.sql | promjena nadimka |
| 12. 10. | supabase-dodatak-tocnost.sql | točnost skrivena dok je student ne uključi |
| 12. 10. | supabase-dodatak-easteregg.sql | tko je pronašao uskrsno jaje |
| 13. 10. | supabase-dodatak-ljestvica-zadaci.sql | ljestvica Zadataka |
| 15. 10. | supabase-dodatak-teoremi.sql | Thevenin/Norton u ukupnoj ljestvici (zamijenjeno, vidi slobodno) |
| 15. 10. | supabase-dodatak-zadaci-gradiva.sql | ljestvica Zadataka po gradivima |
| 15. 10. | supabase-dodatak-kz.sql | ljestvica probne KZ1 |
| 15. 10. | supabase-dodatak-povratne.sql | povratne informacije, ankete, tablica admins, is_admin |
| 15. 10. | supabase-dodatak-kolegij.sql | usporedba po kolegiju |
| 16. 10. | supabase-dodatak-brisanje-pitanja.sql | brisanje pitanja i povratnih poruka |
| 16. 10. | supabase-dodatak-analitika.sql | analitika za administratora |
| 18. 10. | supabase-dodatak-tjedni.sql | tjedni bodovi, tjedni vrh, potpuni izvoz |
| 20. 10. | supabase-dodatak-redovitost.sql | ljestvica Redovitost |
| 20. 10. | supabase-dodatak-izazov.sql | dnevni izazov |
| 21. 10. | supabase-dodatak-slobodno.sql | ukupna ljestvica: sva gradiva + vježba bez bodovanja u „Riješeno“ |
| 21. 10. | supabase-dodatak-funkcije.sql | statistika korištenja funkcija (feature_events) |
| 23. 10. | supabase-dodatak-admin-mare912.sql | dodaje mare912 kao administratora |
| 26. 10. | supabase-dodatak-odgovori.sql | odgovori nastavnika na prijave, poruke i ankete: stižu pošiljatelju i kad je anoniman (skrivena veza), po želji i svima |
| 28. 10. | supabase-dodatak-admin-ns.sql | dodaje ns kao administratora |

Administrator se dodaje ovako (profil mora postojati):

```sql
insert into public.admins(profile_id) select id from public.profiles where lower(nick) = lower('NADIMAK') on conflict do nothing;
```
