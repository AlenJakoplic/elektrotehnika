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
| Claude Code | piše i dorađuje aplikaciju izravno u GitHub repozitoriju prema materijalima kolegija, sam je isproba i spremi |

Postoje dvije verzije iste datoteke: `index.html` je živa verzija koju koriste studenti, a `test.html` je testna. Sve se prvo napravi i isproba na testu, a tek onda objavi.

## Što treba prije početka

- [ ] **GitHub račun** (besplatan) na [github.com](https://github.com). Tamo će biti spremljeni aplikacija i materijali, a aplikacija se odatle objavljuje.
- [ ] **Vlastiti Supabase račun i projekt** (besplatan plan) na [supabase.com](https://supabase.com). Prijaviti se može i GitHub računom. U bazi samo pokrećeš SQL kod koji napiše Claude.
- [ ] **Claude račun s Claude Codeom** (plan Pro, Max ili Team) na [claude.ai/code](https://claude.ai/code). Na fakultetskom Team računu povezivanje s GitHubom prvo mora uključiti administrator organizacije.
- [ ] **Materijali kolegija u digitalnom obliku:** predavanja, auditorne vježbe, zadaci s rješenjima, stari kolokviji i literatura (PDF, Word, PowerPoint).
- [ ] **Predložak:** Alenov javni repozitorij [AlenJakoplic/elektrotehnika](https://github.com/AlenJakoplic/elektrotehnika). Claude Code ga sam pročita (aplikaciju i pravila u `CLAUDE.md`), pa ništa ne treba preuzimati.

**Model i napor (effort):** u Claude Codeu odaberi model **Opus 5.5**.

| Posao | Effort |
| --- | --- |
| Veći zadaci: novo gradivo, nova funkcija, veće preuređenje | high |
| Sitnice: tekst, boja, raspored, mala ispravka | low je dovoljno, ali high daje bolje rezultate |
| Jači effort | nije isprobano, slobodno probaj |

## Koraci postavljanja

Prva verzija može biti gotova za jedno popodne. Koraci redom:

1. **Napravi javni repozitorij za aplikaciju** na GitHubu, npr. `fizika-radionica` (New repository → Public → označi *Add a README file*).
2. **Uključi GitHub Pages:** u repozitoriju Settings → Pages → Deploy from a branch → grana `main`, mapa `/ (root)`. Aplikacija će biti na adresi `https://<korisničko-ime>.github.io/<repozitorij>/`, a testna verzija na `…/test.html`.
3. **Napravi privatni repozitorij za materijale**, npr. `fizika-materijali` (Private), i učitaj u njega materijale kolegija: Add file → Upload files (pojedina datoteka do 25 MB). Privatan je jer materijali služe samo Claudeu, a ne javnosti.
4. **Napravi Supabase projekt:** na supabase.com → New project. Upiši naziv, odaberi regiju u Europi (npr. Frankfurt) i postavi lozinku baze. Lozinku spremi za sebe, ali je nikome ne daješ, ni Claudeu.
5. **Otvori Claude Code** na [claude.ai/code](https://claude.ai/code) i poveži GitHub račun. Kad ponudi, instaliraj **Claude GitHub App** na svoj GitHub račun: bez toga Claude ne vidi privatni repozitorij s materijalima.
6. **Započni prvu sesiju:** ispod polja za poruku odaberi **oba repozitorija** (aplikaciju i materijale), model Opus 5.5 i pošalji tekst iz odjeljka *Prvi prompt* (niže). Claude napravi `CLAUDE.md` s pravilima projekta, prvu verziju `test.html` i SQL datoteku za bazu.
7. **Pokreni SQL u Supabaseu:** SQL Editor → zalijepi cijeli SQL → Run. Na kraju treba pisati „Success“. Ako javi grešku, kopiraj njen tekst Claudeu.
8. **Daj Claudeu adresu baze i javni ključ:** u Supabaseu Project Settings → API: adresa projekta (Project URL) i **publishable / anon** ključ. Nikad ne daj *service_role / secret* ključ ni lozinku baze.
9. **Isprobaj testnu verziju** (`…/test.html`) na mobitelu i računalu. Napravi profil i postavi se za administratora (Claude napiše kratak SQL za to).
10. **Objavi:** kad test radi, napiši Claudeu „objavi“. On napravi `index.html` iz testne verzije i spremi ga na GitHub. Tu adresu daješ studentima.

Claude Code sve izmjene sam sprema na GitHub. U `CLAUDE.md` piše da ih sprema izravno na granu `main`, pa se odmah vide na webu (nakon minute-dvije). Ako ipak napravi zasebnu granu, napiši mu „spoji u main“.

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
- Za svaku veću izmjenu otvori novu sesiju s oba repozitorija. Pravila su u CLAUDE.md, pa ih ne treba ponavljati, samo ukratko napiši gdje ste stali.

**Računalo i mobitel.** Provjere i glavne prijedloge radi na računalu. Ako se nečega sjetiš u slobodno vrijeme, prijedlog možeš poslati i s mobitela (aplikacija Claude, kartica Code): Claude izmjenu stavi samo u testnu verziju i vrati snimku zaslona da vidiš kako izgleda.

**Prije objave:**

- Traži od Claudea **popis što sve provjeriti**, pa ga drugi dan za računalom prođi na testnoj verziji, tek onda napiši „objavi“.
- Uz veće novosti Claude pri objavi doda **novu oznaku verzije** i prozor **Što je novo** za studente. Za sitnice (tekst, boja, mala ispravka) to ne treba.

**Zašto Claude Code, a ne razgovor u claude.ai projektu?** U projektu Claude piše datoteke koje onda ručno preuzimaš i učitavaš na GitHub, a u Claude Codeu sam mijenja, isproba i sprema. Može se raditi i u projektu, ali ne miješaj oba načina na istoj aplikaciji: lako se dogodi da jedan prebriše izmjene drugoga.

## Važno

- **Ključevi:** u HTML ide samo javni *publishable / anon* ključ. *service_role / secret* ključ i lozinka baze nikad ne idu Claudeu ni u datoteku.
- **Pristup podacima:** tablice su zaključane, a aplikacija čita i piše samo preko funkcija u bazi. Administratorske funkcije provjeravaju je li korisnik administrator.
- **Privatnost:** studenti se prijavljuju nadimkom i PIN-om. Izvozi za analizu su anonimizirani (bez nadimka, imena i PIN-a).
- **Tekstovi za studente** neka budu rodno neutralni (ne „dobio/la“, nego npr. „Točno, +2 boda“).
- **SQL se smije pokretati više puta.** Svaka promjena baze dolazi kao zasebna datoteka (npr. `supabase-dodatak-ankete.sql`), a postojeći podaci ostaju.
- **Besplatni Supabase** pauzira projekt nakon otprilike tjedan dana bez ikakve aktivnosti. Dok studenti koriste aplikaciju to se ne događa, a pauzirani projekt se jednim klikom ponovno pokreće.

## CLAUDE.md: pravila projekta

`CLAUDE.md` je datoteka u repozitoriju aplikacije koju Claude Code pročita na početku svake sesije. Pravila ispod zalijepi na kraj *Prvog prompta* (dijelove u uglatim zagradama zamijeni svojim podacima), a Claude od njih i od Alenova `CLAUDE.md` napravi datoteku za tvoju aplikaciju. Kasnije pravilo dodaš tako da napišeš Claudeu „dodaj u CLAUDE.md: …“.

```
Razvijam web-aplikaciju za vježbanje gradiva kolegija [NAZIV KOLEGIJA] na [STUDIJ, FAKULTET]. Nositelj: [IME]. Izvode: [IMENA].
Materijali kolegija (predavanja, auditorne, zadaci, literatura) su u privatnom repozitoriju [KORISNIK/MATERIJALI]. Pitanja i zadatke radi isključivo prema tim materijalima, istim oznakama i nazivljem kao na nastavi. Materijale nikad ne kopiraj u javni repozitorij aplikacije.

TEHNIKA
- Cijela aplikacija je jedna HTML datoteka (HTML, CSS, JavaScript, SVG za sheme), bez build alata.
- Spremište: javni GitHub repozitorij [KORISNIK/REPOZITORIJ], objava preko GitHub Pages. Izmjene spremaj izravno na granu main.
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

Ovo je prva poruka u prvoj sesiji Claude Codea, s odabrana oba repozitorija. Effort: **high**.

```
Napravi prvu verziju aplikacije za vježbanje gradiva mog kolegija, prema materijalima u repozitoriju [KORISNIK/MATERIJALI]. Aplikacija ide u repozitorij [KORISNIK/REPOZITORIJ].

1. Prvo u repozitoriju aplikacije napravi CLAUDE.md. Pravila su na kraju ove poruke, a kao uzor za strukturu i tehničke dijelove uzmi CLAUDE.md iz javnog repozitorija AlenJakoplic/elektrotehnika.
2. Kao predložak aplikacije prouči test.html iz istog repozitorija (Digitalna radionica, Elektrotehnika R): prijava nadimkom i PIN-om, spremanje u Supabase, razina 1–10, ljestvica, povratne informacije i analitika za administratora. Preuzmi ono što ima smisla, ali sadržaj neka bude iz mog kolegija. Adresu njegove baze i njegov ključ nemoj preuzeti: aplikacija koristi moj Supabase projekt, a adresu i javni ključ dat ću ti posebno.

Za ovu prvu verziju želim:
1. Prijavu nadimkom i PIN-om i spremanje napretka u bazu.
2. Jedno gradivo: [NAZIV GRADIVA, npr. prvo poglavlje], s kratkom lekcijom i vježbom s pitanjima različite težine iz mojih materijala.
3. Razinu 1–10 po gradivu, koja raste i pada prema točnosti.
4. Jednostavnu ljestvicu i stranicu "O aplikaciji".
5. Gumb za povratnu informaciju.

Predaj mi:
- CLAUDE.md i test.html spremljene na GitHub (grana main),
- SQL datoteku za bazu,
- kratak SQL kojim sebe postavljam za administratora,
- popis koraka što da isprobam.

Ako ti nešto nije jasno, prije nego što kreneš postavi mi do tri pitanja.

PRAVILA ZA CLAUDE.md:
[ovdje zalijepi tekst iz odjeljka "CLAUDE.md: pravila projekta"]
```

**Sljedeći koraci**, svaki u novoj poruci kad prethodni radi, npr.:

- „Dodaj gradivo [X] prema predavanju [N] i auditornoj [M].“
- „Dodaj zadatke s brojevima za gradivo [X], korak po korak, s provjerom rezultata.“
- „Dodaj probnu kontrolnu zadaću s [N] zadataka kao na pravom kolokviju.“
- „Dodaj analitiku za administratora: tko koliko radi i gdje zapinju.“
- „Studenti su u anketi napisali: [komentar]. Predloži nekoliko rješenja.“

## Ako zapne

Javi se Alenu Jakopliću ako bilo gdje zapne: postavljanje baze, GitHub Pages, greška u SQL-u ili nešto što Claude ne uspijeva riješiti. Najbrže je poslati snimku zaslona i tekst greške.
