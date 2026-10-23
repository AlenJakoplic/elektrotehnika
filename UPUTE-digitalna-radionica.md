# Kako napraviti digitalnu radionicu za kolegij

23. 10. 2026. · Alen Jakoplić

## Što je aplikacija

Digitalna radionica je web-aplikacija za vježbanje gradiva jednog kolegija, napravljena uz pomoć Claudea bez programiranja. Za Elektrotehniku R nastala je u nekoliko tjedana, dio po dio, uz nastavu.

**Što dobivaju studenti:**

- lekcije s primjerima i vježbu s pitanjima koja se prilagođavaju njihovoj razini (razina 1–10, kao rejting u šahu);
- zadatke s brojevima, korak po korak, s provjerom rezultata i postupkom;
- pripremu i probnu kontrolnu zadaću;
- ljestvice, dnevni izazov, zadatke dana, značke i niz dana;
- prijavu greške i pitanja nastavniku izravno iz zadatka.

**Što dobiva nastavnik:** povratne informacije i ankete studenata, analitiku (tko koliko radi, gdje zapinju, spremnost za kolokvij) i anonimizirani izvoz podataka za analizu.

**Kako je građena:**

| Dio | Čemu služi |
| --- | --- |
| Jedna HTML datoteka | cijela aplikacija (izgled, zadaci, logika) u jednoj datoteci |
| GitHub i GitHub Pages | besplatno spremište i objava aplikacije na webu |
| Supabase | baza podataka: profili, odgovori, ljestvice, povratne informacije |
| Claude (claude.ai, projekt) | piše i dorađuje aplikaciju prema materijalima kolegija |

Postoje dvije verzije iste datoteke: `index.html` je živa verzija koju koriste studenti, a `test.html` je testna. Sve se prvo napravi i isproba na testu, a tek onda objavi.

## Što treba prije početka

- [ ] **GitHub račun** (besplatan) na [github.com](https://github.com). Tamo će biti spremljena i objavljena aplikacija.
- [ ] **Vlastiti Supabase račun i projekt** (besplatan plan) na [supabase.com](https://supabase.com). Prijaviti se može i GitHub računom. U bazi samo pokrećeš SQL kod koji napiše Claude.
- [ ] **Claude račun** s pristupom projektima na [claude.ai](https://claude.ai).
- [ ] **Materijali kolegija u digitalnom obliku:** predavanja, auditorne vježbe, zadaci s rješenjima, stari kolokviji i literatura (PDF, Word, PowerPoint).
- [ ] Po želji: **Alenove HTML datoteke** (`index.html` i `test.html`) kao predložak. Claude iz njih vidi kako je radionica građena i može preuzeti dobra rješenja (prijava, ljestvice, analitika).

**Model i napor (effort):** u Claudeu odaberi model **Opus 5.5**.

| Posao | Effort |
| --- | --- |
| Veći zadaci: novo gradivo, nova funkcija, veće preuređenje | high |
| Sitnice: tekst, boja, raspored, mala ispravka | low je dovoljno, ali high daje bolje rezultate |
| Jači effort | nije isprobano, slobodno probaj |

## Koraci postavljanja

Prva verzija može biti gotova za jedno popodne. Koraci redom:

1. **Napravi repozitorij na GitHubu**, javni (public), npr. `fizika-radionica`.
2. **Uključi GitHub Pages:** u repozitoriju Settings → Pages → Deploy from a branch → grana `main`, mapa `/ (root)`. Aplikacija će biti na adresi `https://<korisničko-ime>.github.io/<repozitorij>/`, a testna verzija na `…/test.html`.
3. **Napravi Supabase projekt:** na supabase.com → New project. Upiši naziv, odaberi regiju u Europi (npr. Frankfurt) i postavi lozinku baze. Lozinku spremi za sebe, ali je nikome ne daješ, ni Claudeu.
4. **Napravi projekt u claude.ai** i u njega učitaj sve materijale kolegija (predavanja, auditorne, zadatke, literaturu) te, po želji, Alenove HTML datoteke.
5. **U upute projekta zalijepi tekst** iz odjeljka *Upute za Claude projekt* (niže) i prilagodi naziv kolegija i imena.
6. **Započni prvi razgovor** s tekstom iz odjeljka *Prvi prompt* (niže). Claude će napraviti prvu verziju `test.html` i SQL datoteku za bazu.
7. **Pokreni SQL u Supabaseu:** SQL Editor → zalijepi cijeli SQL → Run. Na kraju treba pisati „Success“. Ako javi grešku, kopiraj njen tekst Claudeu.
8. **Daj Claudeu adresu baze i javni ključ:** u Supabaseu Project Settings → API: adresa projekta (Project URL) i **publishable / anon** ključ. Nikad ne daj *service_role / secret* ključ ni lozinku baze.
9. **Stavi `test.html` na GitHub:** ako je GitHub povezan s Claudeom, Claude sam sprema izmjene; ako nije, preuzmi datoteku od Claudea i u repozitoriju odaberi Add file → Upload files.
10. **Isprobaj testnu verziju** na mobitelu i računalu. Napravi profil i postavi se za administratora (Claude napiše kratak SQL za to).
11. **Objavi:** kad test radi, napiši Claudeu „objavi“. On napravi `index.html` iz testne verzije, a ti je staviš na GitHub kao u koraku 9. Tu adresu daješ studentima.

## Kako raditi s Claudeom

Najbolje ide **korak po korak**: jedno gradivo ili jedna funkcija po razgovoru, provjera na testu, pa objava. Claude može napisati i puno odjednom, ali tada je teže sve provjeriti, a greške se teže nalaze. Radionica za Elektrotehniku R rasla je tako da je iz tjedna u tjedan dolazilo novo gradivo, a starije se dorađivalo prema komentarima studenata.

**Ciklus jedne izmjene:**

1. Opiši što želiš, kratko i konkretno (npr. „Dodaj gradivo Coulombov zakon prema predavanju 3 i auditornoj 2“).
2. Claude izmijeni `test.html`. Ako treba promjena u bazi, da ti i SQL datoteku.
3. Pokreni SQL (ako ga ima), otvori testnu verziju i isprobaj.
4. Napiši što ne valja, i to ispravljajte dok ne bude dobro.
5. Napiši „objavi“.

**Korisni savjeti:**

- Kad tražiš prijedlog, traži nekoliko opcija pa odaberi.
- Snimka zaslona s problemom vrijedi više od opisa.
- Komentare studenata (ankete, povratne informacije) zalijepi Claudeu i pitaj što s njima.
- Prije veće promjene traži sigurnosnu kopiju (backup).
- Novo gradivo dodaj kad se obradi na nastavi, a staro dorađuj kad se pokaže da nešto ne radi.
- Kad je razgovor jako dug, otvori novi u istom projektu i ukratko napiši gdje ste stali.

**Računalo i mobitel.** Provjere i glavne prijedloge radi na računalu. Ako se nečega sjetiš u slobodno vrijeme, prijedlog možeš poslati i s mobitela: Claude izmjenu stavi samo u testnu verziju i vrati snimku zaslona da vidiš kako izgleda.

**Prije objave:**

- Traži od Claudea **popis što sve provjeriti**, pa ga drugi dan za računalom prođi na testnoj verziji, tek onda napiši „objavi“.
- Uz veće novosti Claude pri objavi doda **novu oznaku verzije** i prozor **Što je novo** za studente. Za sitnice (tekst, boja, mala ispravka) to ne treba.

## Važno

- **Ključevi:** u HTML ide samo javni *publishable / anon* ključ. *service_role / secret* ključ i lozinka baze nikad ne idu Claudeu ni u datoteku.
- **Pristup podacima:** tablice su zaključane, a aplikacija čita i piše samo preko funkcija u bazi. Administratorske funkcije provjeravaju je li korisnik administrator.
- **Privatnost:** studenti se prijavljuju nadimkom i PIN-om. Izvozi za analizu su anonimizirani (bez nadimka, imena i PIN-a).
- **Tekstovi za studente** neka budu rodno neutralni (ne „dobio/la“, nego npr. „Točno, +2 boda“).
- **SQL se smije pokretati više puta.** Svaka promjena baze dolazi kao zasebna datoteka (npr. `supabase-dodatak-ankete.sql`), a postojeći podaci ostaju.
- **Besplatni Supabase** pauzira projekt nakon otprilike tjedan dana bez ikakve aktivnosti. Dok studenti koriste aplikaciju to se ne događa, a pauzirani projekt se jednim klikom ponovno pokreće.

## Upute za Claude projekt

Ovaj tekst zalijepi u upute projekta u claude.ai. Dijelove u uglatim zagradama zamijeni svojim podacima.

```
Razvijam web-aplikaciju za vježbanje gradiva kolegija [NAZIV KOLEGIJA] na [STUDIJ, FAKULTET]. Nositelj: [IME]. Izvode: [IMENA].
U projektu su materijali kolegija (predavanja, auditorne, zadaci, literatura). Pitanja i zadatke radi isključivo prema tim materijalima, istim oznakama i nazivljem kao na nastavi.

TEHNIKA
- Cijela aplikacija je jedna HTML datoteka (HTML, CSS, JavaScript, SVG za sheme), bez build alata.
- Spremište: GitHub repozitorij [KORISNIK/REPOZITORIJ], objava preko GitHub Pages.
- Dvije datoteke: index.html je živa verzija za studente, test.html je testna. Radi samo na test.html. index.html mijenjaj tek kad napišem "objavi".
- Baza: moj Supabase projekt (besplatni plan).
- Svaka promjena baze ide u zasebnu SQL datoteku koju ja pokrećem u Supabase SQL Editoru. SQL mora biti siguran za ponovno pokretanje (create if not exists, create or replace) i ne smije brisati postojeće podatke.
- Tablice su zaključane (RLS uključen, bez izravnog pristupa za anon i authenticated). Aplikacija koristi samo RPC funkcije sa security definer. Administratorske funkcije provjeravaju tablicu admins.
- U HTML ide samo javni publishable/anon ključ. Nikad ne traži service_role/secret ključ ni lozinku baze.
- Studenti se prijavljuju nadimkom i PIN-om. Izvozi podataka su anonimizirani.

NAČIN RADA
- Odgovaraj na hrvatskom.
- Kad tražim prijedloge, prvo ponudi nekoliko opcija.
- Sav tekst koji vide studenti mora biti rodno neutralan.
- Radimo korak po korak: jedno gradivo ili jedna funkcija odjednom, pa testiranje.
- Prije predaje provjeri da aplikacija radi i na mobitelu (širina oko 390 px) i u tamnoj temi.
- Gdje ima više vrsta zadataka, administratoru omogući da isproba svaku vrstu.
- Održavaj stranicu "O aplikaciji" ažuriranom.
- Ako nešto nije jasno ili se ne slaže s materijalima, pitaj prije nego što napraviš.
- Kad pišem s mobitela, izmjenu stavi samo u test.html i vrati mi snimku zaslona da vidim kako izgleda.
- Prije objave napravi mi popis što sve da provjerim na testnoj verziji.
- Kad objavljujemo veće novosti, dodaj novu oznaku verzije i prozor "Što je novo" za studente. Za sitnice to ne radi.
```

## Prvi prompt

Ovo je prva poruka u novom razgovoru unutar projekta. Effort: **high**.

```
Napravi prvu verziju aplikacije za vježbanje gradiva mog kolegija, prema materijalima u projektu.

Ako su u projektu Alenove datoteke index.html i test.html (Digitalna radionica, Elektrotehnika R), prouči ih kao predložak: kako su građene prijava nadimkom i PIN-om, spremanje u Supabase, razina 1–10, ljestvica, povratne informacije i analitika za administratora. Preuzmi ono što ima smisla, ali sadržaj neka bude iz mog kolegija. Adresu njegove baze i njegov ključ nemoj preuzeti: aplikacija koristi moj Supabase projekt, a adresu i javni ključ dat ću ti posebno.

Za ovu prvu verziju želim:
1. Prijavu nadimkom i PIN-om i spremanje napretka u bazu.
2. Jedno gradivo: [NAZIV GRADIVA, npr. prvo poglavlje], s kratkom lekcijom i vježbom s pitanjima različite težine iz mojih materijala.
3. Razinu 1–10 po gradivu, koja raste i pada prema točnosti.
4. Jednostavnu ljestvicu i stranicu "O aplikaciji".
5. Gumb za povratnu informaciju.

Predaj mi:
- test.html,
- SQL datoteku za bazu,
- kratak SQL kojim sebe postavljam za administratora,
- popis koraka što da isprobam.

Prije nego što kreneš, ako ti nešto nije jasno, postavi mi do tri pitanja.
```

**Sljedeći koraci**, svaki u novoj poruci kad prethodni radi, npr.:

- „Dodaj gradivo [X] prema predavanju [N] i auditornoj [M].“
- „Dodaj zadatke s brojevima za gradivo [X], korak po korak, s provjerom rezultata.“
- „Dodaj probnu kontrolnu zadaću s [N] zadataka kao na pravom kolokviju.“
- „Dodaj analitiku za administratora: tko koliko radi i gdje zapinju.“
- „Studenti su u anketi napisali: [komentar]. Predloži nekoliko rješenja.“

## Ako zapne

Javi se Alenu Jakopliću ako bilo gdje zapne: postavljanje baze, GitHub Pages, greška u SQL-u ili nešto što Claude ne uspijeva riješiti. Najbrže je poslati snimku zaslona i tekst greške.
