# CLAUDE.md – Elektrotehnika: Digitalna radionica

Upute za Claudea (Claude Code i claude.ai) koji radi na ovom repozitoriju. Pročitaj cijelu datoteku prije prve izmjene.
Na ovom projektu rade dvije Claude sesije (Claude Code na računalu i Claude u oblaku na claude.ai), pa je **repozitorij jedini izvor istine**: prije rada uvijek `git pull`, nakon rada `git commit` i `git push`.

---

## 1. O projektu

- **Kolegij:** Elektrotehnika R (Tehnički fakultet Rijeka, studij računarstva). Aplikaciju koriste i studenti Elektrotehnike na studiju mehatronike i robotike te drugih kolegija (izbor kolegija u profilu).
- **Nositelj:** prof. dr. sc. Nino Stojković. **Izvode:** mr. sc. Branka Dobraš, dr. sc. Alen Jakoplić (vlasnik repozitorija i aplikacije).
- **Adresa:** https://alenjakoplic.github.io/elektrotehnika/ (živa) i …/test.html (testna).
- **Što je:** web-aplikacija za vježbanje gradiva: lekcije, Vježba s prilagodljivom razinom (Elo, 1–10), Zadaci s brojevima, priprema i probna KZ1, ljestvice, dnevni izazov, zadaci dana, značke, ankete, povratne informacije, analitika za nastavnika.
- **Korisnici:** oko 30–50 aktivnih studenata, većina s mobitela.
- **Administratori:** profili u tablici `admins` (Alen, mare912). Vide karticu **Nastavnik** (Povratne, Analitika).

---

## 2. Stalna pravila (uvijek vrijede)

1. **Odgovaraj na hrvatskom.**
2. **Kad Alen traži prijedloge, prvo ponudi nekoliko opcija** (s preporukom), a tek onda radi.
3. **Sav tekst koji vide studenti mora biti rodno neutralan.** Ne „dobio/la”, „zaboravio si”, „riješio si”; koristi bezlične oblike („Točno, +2 boda”, „riješeno je”, „spremno”).
4. **Radi samo na `test.html`.** `index.html` mijenjaj **tek kad Alen napiše „objavi”**.
5. **Kod „objavi” NE dodaji ništa u „Što je novo” (VERS/NEWS)** osim ako to izričito traži („objavi i dodaj u što je novo”). Za veće novosti on sam kaže.
6. **Nakon svake promjene funkcionalnosti ažuriraj „O aplikaciji”** (pomoć unutar aplikacije).
7. **Svaka promjena baze ide u zasebnu SQL datoteku** `sql/supabase-dodatak-<tema>.sql` koju Alen sam pokreće u Supabase SQL Editoru. Dodaj je i u `sql/README.md`. Napiši mu točno što da pokrene.
8. **Gdje postoji više vrsta zadataka ili pitanja, administratoru omogući da isproba svaku vrstu** (npr. izbornik „Usredotoči se na vrstu pitanja”, „Drugi zadatak” u probnoj KZ, „Isprobaj anketu”).
9. **Kad Alen piše s mobitela:** izmjenu stavi samo u `test.html` i vrati snimku zaslona (Playwright) da vidi kako izgleda.
10. **Prije objave** napravi popis što sve da provjeri na testnoj verziji.
11. Kad je nešto nejasno ili se ne slaže s materijalima kolegija, pitaj prije nego što napraviš.
12. Na kraju posla kratko: što je promijenjeno, je li na testu ili objavljeno, koji SQL treba pokrenuti, što da isproba.

---

## 3. Sigurnost (nikad ne kršiti)

- **Nikad ne traži niti koristi** Supabase *service_role / secret* ključ, lozinku baze ili Alenovu prijavu. U HTML-u je samo javni *publishable / anon* ključ.
- **Tablice su zaključane** (RLS uključen, `revoke all … from anon, authenticated`). Aplikacija sve radi preko **RPC funkcija** `security definer` s `set search_path = public`.
- **Administratorske funkcije** provjeravaju:
  ```sql
  if not exists(select 1 from admins a join profiles p on p.id = a.profile_id where p.token = p_token) then raise exception 'forbidden'; end if;
  ```
  Administratorski gumbi i prikazi vidljivi su samo kad `isAdmin` (RPC `is_admin`) vrati true.
- **Izvozi su anonimizirani:** bez nadimka, imena, PIN-a, tokena i e-maila (nadimci → S001, S002…).
- **Tijekom probne KZ studenti ne mogu mijenjati zadatke** (gumb „Drugi zadatak” samo za administratora / test).
- **Sadržaj koji se otključava** (npr. dnevni izazov nakon 100 riješenih pitanja) skriva se i na poslužitelju (`daily_ok`), ne samo u sučelju.
- Administratori se ne broje u statistici studenata (analitika, `admin_feature_stats`).

---

## 4. Datoteke i objava

```
index.html                     živa verzija (studenti)
test.html                      testna verzija – JEDINA datoteka koju mijenjaš
supabase.sql                   osnovna shema baze (+ neki dodaci na kraju)
sql/supabase-dodatak-*.sql     svi kasniji SQL dodaci, sql/README.md = popis i redoslijed
UPUTE-digitalna-radionica.md   upute za kolege koji žele napraviti sličnu aplikaciju
EtR_f1.pdf/png, EtR_f2.pdf/png formule za kolokvij (otvaraju se u pregledniku)
prezentacija.html              prezentacija aplikacije za nastavnike (zasebna datoteka; poveznica na dnu „O aplikaciji”)
prezentacija/slike/*.webp      snimke zaslona za prezentaciju (anonimizirano, S001…)
prezentacija/prva-verzija.html rana verzija (prvi commit), radi bez baze; prefiks pohrane 'cvoriste-prva:'
prezentacija/verzije/DD-10.html snimke aplikacije po danima (slajd 8), bez baze i brojača; prefiks 'cvoriste-vDD:'
icon-*.png, favicon, easter-egg-2.jpg
```

### Razlike test.html ↔ index.html (jedine tri)

| | test.html | index.html |
| --- | --- | --- |
| prefiks lokalne pohrane (3 mjesta) | `'cvoriste-test:'` | `'cvoriste:'` |
| `<title>` | `Elektrotehnika (test)` | `Elektrotehnika: Digitalna radionica` |
| oznaka u zaglavlju | `<span …>TEST</span>` iza „Elektrotehnika” | nema |

`IS_TEST` se izvodi iz prefiksa: `const IS_TEST='cvoriste-test:'.includes('test');`. Na testu su uključene testne mogućnosti (npr. KZRES prikaz, „(test) vrati kao nepročitano”, izbor vrste u probnoj KZ).

### Objava („objavi”)

```bash
git pull
python3 - <<'PY'
s=open('test.html').read()
s=s.replace("'cvoriste-test:'","'cvoriste:'")
s=s.replace('<title>Elektrotehnika (test)</title>','<title>Elektrotehnika: Digitalna radionica</title>')
b='<span style="font-size:14px;background:var(--mark);color:#1C2B3A;padding:2px 8px;border-radius:4px;vertical-align:middle">TEST</span>'
s=s.replace(' '+b,'').replace(b,'')
assert "'cvoriste-test:'" not in s and '>TEST</span>' not in s
open('index.html','w').write(s)
PY
git add index.html && git commit -m "Objava: …" && git push
```

Prije objave: isprobaj index.html (Playwright, poglavlje 9) – `IS_TEST` mora biti false, naslov bez „test”.
Commit poruke završavaju s:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
(ili trailer koji zada okruženje). Prije veće promjene napravi backup (zip repozitorija bez `.git`).

---

## 5. Arhitektura koda (test.html, ~800 KB, jedna datoteka)

- Čisti HTML + CSS + JavaScript + SVG, bez build alata. Vanjske skripte: `@supabase/supabase-js@2.57.4` (jsDelivr) i GoatCounter (anonimni posjeti, `gcSend(path,title)`). Fontovi: Atkinson Hyperlegible (tekst), Barlow Condensed (naslovi, sheme), Inter.
- **Teme:** CSS varijable `--paper --sheet --grid --ink --muted --line --btn --mark --ok --bad`, svijetla i tamna (prefers-color-scheme + `data-theme`). Novi kod koristi samo te varijable.
- **Novi kod se umeće neposredno prije** završnog:
  ```js
  view='home';
  boot();
  ```
  na kraju glavne skripte. Iza toga je samo skripta s animacijama (`<script>` ispred `</body>`) i `<style id="anim">`.
- **Wrapper uzorak:** postojeće funkcije ne prepisuj, nego ih omotaj:
  ```js
  {const _old=renderHome;renderHome=function(){const r=_old.apply(this,arguments);try{/* dodatak */}catch(e){}return r}}
  ```
  Function declarations su globalne pa se mogu preusmjeriti. Pazi: neke su `async` (`renderAn`, `chStart`, `chNext`) – omotač mora biti `async` i `await`.
- **MutationObserver na `main`** koristi se za dodavanje elemenata nakon rendera (npr. gumb ⤢ za povećanje, traka izazova, „Vježbam bez bodovanja”). Observer je asinkron – u testovima pričekaj ~100 ms.

### Glavne globalne varijable i funkcije

| Ime | Značenje |
| --- | --- |
| `main` | `<main id="main">`, sav sadržaj prikaza |
| `view` | trenutni prikaz: `home`, `kz`, `lesson`, `practice`, `zad`, `progress`, `board`, `bank`, `help`, `exam`, `fb` (Nastavnik) |
| `render()` | iscrtava trenutni `view` (puno wrappera) |
| `prof()` | profil prijavljenog korisnika (objekt u `state.profiles`) |
| `save()` | sprema `state` lokalno (`Store`) i nakon 1,2 s na poslužitelj (`pushState` → RPC `save_state`) |
| `Store.get/set` | localStorage s prefiksom `cvoriste:` / `cvoriste-test:` |
| `Remote`, `session` | Supabase klijent i sesija (`session.token`) |
| `isAdmin` | true za administratore |
| `modbar()` | traka „Odaberi gradivo” na vrhu prikaza |
| `fbModal(html)` | skočni prozor (`#fbm`), vraća element |
| `toast(t)` | kratka poruka na dnu |
| `fmt(x)` | broj s jednom decimalom i zarezom; `zN(x)` broj s decimalnim zarezom |
| `sub(x)` | indeksi u oznakama (R12 → R<sub>12</sub>) |
| `$(sel)` | `document.querySelector` |
| `zgDate()` | današnji datum u Zagrebu `YYYY-MM-DD` |

### Profil (`prof()`), najvažnija polja

`ratings[topic]={r,n,c}` (razina, broj, točnih), `module` (trenutno gradivo), `tags`, `wrong[{id,due}]` (pitanja koja se vraćaju), `recent`, `boost[topic]` (Lakši/Teži), `answered`, `zad` (Zadaci: `t[type].g` itd.), `kz` (priprema i probne KZ1: `sims`, `best`, `stage`), `grades` (Moji bodovi KZ1/KZ2/KZ3/lab), `week={id,pts}` (tjedni bodovi), `quest` (zadaci dana), `chal[day]` (dnevni izazov), `les[module]` (napredak lekcija), `fbs` (ankete: `'100'`, `kz`, `g:<topic>`, `gn:<topic>`, `last`, `next100`), `newsSeen`, `freeMode`, `freeN`, `freeT`, `course`, `colors`, `qlog`.

---

## 6. Gradiva i pitanja

### Vježba (prilagodljiva razina)

| Gradivo (`p.module`) | Naziv | Izvor pitanja | Render |
| --- | --- | --- | --- |
| `serpar` | Serija ili paralela | `QS` (iz `BANK.nets`) | `renderSerpar` |
| `ruk` / `rukC` | Ukupni otpor / kapacitet (svođenje korak po korak) | `QS`, mreže `NETS` | `renderRuk`, `rkMerge`, `rkDrop` |
| `estat` | Elektrostatika (smjer sile/polja, omjeri, nul-točka…) | `EQ` (157 pitanja) | `renderEstat`, `pickEstat` |
| `kont` / `cvor` | Konturne struje / naponi čvorova (koraci) | `QS` | `metRender`, `metSteps` |
| `thev` / `nort` | Theveninov / Nortonov teorem (koraci) | `QS` (TV*, TN*) | `thRender`, `thStart` |
| `mag` | Magnetsko polje ravnih vodiča | `MGQ` | `renderMag` |

- `chAll()` = `QS + EQ + MGQ`; `chFind(id)` traži pitanje po id-u.
- **Vrste pitanja:** `q.type`, nazivi u `TYPENAME` (npr. P, Z, V, D za ruk; S „Mreža s izvorima” za serpar; J, G, M za metode; TD, TO, TE, TU… za teoreme; `KS` „Kratki spoj i slijepa grana” i `AB` „Stezaljke na mjestu otpornika” za ruk). Izbornik „Usredotoči se na vrstu pitanja” postavlja `testType`.
- **Zadaci s trikom u Ukupnom otporu** (`RKTR={KS,AB}`): generiraju se pri učitavanju (`rkGenTricks`, `rkGenShorts`), izvedene mreže su u `RK_DNETS`. Student klikom na jedan otpornik može ga izbaciti kao kratko spojen / bez struje (`rkDrop`, `rkClass`, `rkUseful` – dvopovezane komponente). Provjereno numerički na svim otpornicima.
- **Oznake zamki:** `TAGNAMES` (analitika „Gdje zapinju”).

### Razina (Elo) – NE MIJENJATI formulu bez simulacije

```js
pCorrect(s,q) = 1/3 + (2/3)/(1+10^((q-s)/2))
K = max(0.25, 1/sqrt(1+n/6));  d = K*(score - P);  (×0.4 ako je pozitivno i korištene su bojice)
```
U `applyResult(q,correct,usedColors)`. Pitanja se biraju u `pickQuestion` (cilj = razina + boost + 0,8) i `pickEstat`.
**Lekcija:** 21. 10. pokušali smo blažu kaznu, povrat bodova i ×2 za ispravljenu grešku. Simulacija 3.000 studenata pokazala je da tada gotovo svi završe na 9–10 (korelacija sa znanjem pala s 0,94 na 0,14), pa je vraćena stara formula. Svaku promjenu formule prvo simuliraj (`elo` simulacija u Pythonu: studenti s poznatim znanjem, ponavljanje pogrešnih pitanja nakon 5–9 odgovora).
Motivacija ide kroz **tjedne bodove**, **Vježbam bez bodovanja** i **Ponovi moje greške**, ne kroz razinu.

### Zadaci s brojevima (`view='zad'`)

Vrste (`Z.type`): `nab` (naboji, podvrste `ZKINDS.nab`: jedan, ploce, pravac2, pravac3, kut, kvadrat, rad), `capu` (kondenzatori), `ruk`, `cap`, `ui` (struje i naponi), `kont`, `cvor`, `thev`, `nort`, `pril` (prilagođenje po snazi), `mag`. Redoslijed u izborniku prati nastavu: … Teoremi, Prilagođenje, **Magnetsko polje zadnje**. `goZad(type)` otvara vrstu. Bodovanje: točno iz prvog pokušaja puni bodovi, iz drugog pola, uz „Prikaži rješenje” prije predaje 0.

### Lekcije

`LESSONS[module]` = niz slajdova `{svg,t,h}`, `lstep[module]` = trenutni slajd, `lessonX` za posebne lekcije.

---

## 7. Funkcionalnosti (gdje je što)

- **Početna (`renderHome`):** pozdrav, „Što je novo” (istaknuto dok nije pročitano), obavijest o rezultatima KZ1, niz dana, kartica KZ1, ukupna razina, **Preporuka za danas**, **Dnevni izazov** (`#chbox`), **Zadaci dana** (`#qbox`), **Gradiva** s prstenovima napretka (`ringParts`, `ringSvg`: plavo lekcija, zeleno vježba, narančasto zadaci).
- **KZ1 (`view='kz'`, `renderKZ`):** stadiji pripreme (`KZS1`, `KZS2`), spremnost, **Probna KZ1** (4 zadatka, raspodjela u `kzPickTask`), pregled, „Moji bodovi” (`grCalc`, `grHtml`; vidljivo tek kad je `KZRES.kz1=true` ili na testu). `KZRES={kz1,kz2,kz3}`, `KZRES_URL` za tablicu rezultata – postavi na true tek kad Alen kaže da su rezultati objavljeni.
- **Dnevni izazov (`ch*`):** na poslužitelju se sprema set od **10** pitanja (`daily_set` zahtijeva točno 10!), a izazov koristi **prvih 5** (`CH.qs=I.qids.slice(0,5)`). Bodovi: najviše 10 (po pitanju 2; jedan odgovor: −0,2 za svakih započetih 5 s, najmanje 0,2; zadaci s koracima: −0,7 po pogrešci). Prvi pokušaj ide na ljestvicu i u tjedne bodove; je li prvi, provjerava se prema ljestvici na poslužitelju (`chMine`). Biranje: `chTopics` (gradiva aktivna u 7 dana), `chBuild` (teža pitanja; metode ≤ 12 koraka, Ukupni otpor samo `KS`/`AB`). Traka `#chbar` na vrhu, automatski prijelaz (1,5 s točno / 3 s netočno), „Preskoči”, rezultat s „Zašto”. Kartica na Početnoj pamti današnji izazov (`Store 'chc'`). Ljestvica: kartica „Dnevni izazov” s izborom dana (`chDays`, od 21. 10. 2026.).
- **Zadaci dana (`qMake`, `qTick`, `qHtml`):** miks, slabije gradivo, manje vježbano, zadatak s brojevima; bonus `QB=5` tjednih bodova.
- **Tjedni bodovi (`gWeek`, `wkFactor`):** manje bodova na razinama 7+ i 9+; tjedni vrh = top 10 % (`week_medals`).
- **Ljestvica (`view='board'`, `boardAll`):** `false` = gradivo, `true` = ukupno, `'week'`, `'daily'`, `'streak'` (Redovitost, zadnja kartica), `'zad'`, `'kz'`. „Tvoja mjesta” sa zlatom/srebrom/broncom.
- **Što je novo:** `NEWS` (trenutna verzija, `NEWS_ID`), `NEWSOLD['0.10'…'0.17']` (prozori starijih verzija), `NEWSV`, `VERS` (popis verzija u „O aplikaciji”, gumb „Prikaži novosti ove verzije”), `newsOpen(ver)`, `newsGo(code)` za gumbe „Isprobaj” (`p:<module>:<type>`, `z:<type>`, `l:<module>`, `v:<view>`, `tour`). Nova verzija = novi `NEWS_ID` + novi sadržaj `NEWS` + prethodni `NEWS` premjesti u `NEWSOLD` + redak u `VERS`. **Samo kad Alen to traži.**
- **Ankete:** `fbSurvey('100')` nakon 100 riješenih, `fbSurvey('kz')` nakon prve probne, `gSurvey(topic)` nakon 100 pitanja iz gradiva; nikad dvije unutar 30 min (`SV_GAP`); ne tijekom izazova/KZ/testa. Pregled za administratora: Nastavnik → Povratne → „Isprobaj anketu” (`svPreview`, ništa se ne šalje).
- **Vježbam bez bodovanja / Ponovi moje greške:** `p.freeMode`, `ERRQ`, `freeOn()`; omotač `applyResult` sprema snimku profila i vraća je (razina se ne mijenja), ali se broje `freeN` i tjedni bodovi; odgovor se u bazu sprema s `mode='slobodno'`, `help=true` (ne utječe na težinu pitanja). Pogrešna pitanja se i dalje vraćaju u običnoj vježbi.
- **Povećanje slika:** gumb ⤢ na svakom `.schem` (`zoomOpen`), +/−, dva prsta, zatvaranje klikom pored ili Esc.
- **Animacije:** `<style id="anim">` + skripta na kraju; poštuje `prefers-reduced-motion`.
- **Statistika korištenja (`ev(feature,action,detail,once)`):** RPC `event_log`; administrator vidi Analitika → „Korištenje funkcija” (`anFunLoad`, `FEVN`, `FEVA`, `fevDet`). Bilježi: zadaci dana, izazov, ljestvica, preporuka, KZ1, novosti, bez bodovanja, greške, povećanje, lekcije.
- **Analitika (`renderAn`, async):** kartice Pregled i studenti / Priprema za KZ1: gdje zapinju / Cijela grupa / Korištenje funkcija; filtri kolegij, aktivni, riješeno barem; CSV i potpuni anonimizirani izvoz (`admin_export`).
- **Povratne:** poruke, prijave grešaka, pitanja nastavniku, ankete (`svShowR` prikazuje predanu anketu). Nastavnik može odgovoriti na sve osim anketa (`feedback_reply(…, p_public)`, `fbReplyBox`). Odgovor uvijek stiže pošiljatelju na Napredak (Moja pitanja i prijave, `my_questions`), i kod anonimnih poruka: baza uz njih sprema skrivenu vezu `feedback.owner_id` koju `feedback_list` nikad ne vraća (samo `linked`); ankete se ne vežu. Kvačica „Prikaži odgovor i svima” (`public_reply`) prikazuje odgovor bez teksta poruke uz zadatak (`#pubr`, sklopljeno) ili na Napretku (`public_replies`). Starije anonimne poruke bez veze imaju samo javni odgovor.
- **Uskrsno jaje:** postoji, ne otkrivaj u tekstovima kako se pronalazi.
- **Prezentacija za nastavnike (`prezentacija.html`):** otvara se poveznicom „Prezentacija o aplikaciji” na dnu „O aplikaciji” (`#prezlink`, omotač `renderHelp`), a administrator je može otvoriti i s 5 brzih klikova (razmak < 0,8 s) na naslov prozora „Novosti u verziji 0.10” (`prezN`). Slajdovi 1920×1080 skalirani, tipke ←/→/razmak/PgUp/PgDn, F, T, `#broj` u adresi; ulomci `.f` otkrivaju se redom. Pločice s `data-live` (slajdovi 9, 10, 12, 13) otvaraju pravu aplikaciju (`index.html`) u prozoru `#live` preko `newsGo(kod)`; Slajd 8 se crta sam (`render8`): broj dana od 7. 10., verzije iz `VERS` žive aplikacije (kratki opisi u `VSHORT`), izmjene po danu s GitHub API-ja (spremaju se u localStorage, rezerva `CM8`), nakon 35 dana stupci po tjednu. Datumi i stupci otvaraju snimke iz `prezentacija/verzije/` (popis `SNAP`); **pri svakoj objavi dodaj snimku tog dana** (bez baze, brojača i Supabase skripte, prefiks `cvoriste-vDD:`) i datum u `SNAP`. Rezervirana mjesta `[BROJKA…]`, `[PODATAK IZ ANALITIKE]`, `[SNIMKA…]` (klasa `.ph`) Alen popunjava sam.

---

## 8. Baza (Supabase)

- Projekt: Alenov Supabase (adresa i javni ključ su u HTML-u). Promjene radi isključivo kroz SQL datoteke koje Alen pokreće.
- Tablice: `profiles` (nick, pin hash, token, state jsonb, full_name, show_name, course…), `answers` (qid, topic, score, used_help, mode: `vjezba`/`ispit`/`zadaci`/`slobodno`), `qstats`, `feedback`, `feedback_rl`, `admins`, `week_scores`, `daily_challenge`, `daily_results`, `easter_egg`, `feature_events`.
- Glavne RPC: `register`, `login`, `resume`, `get_me`, `save_state`, `record_answer`, `rename_nick`, `delete_profile`, `public_profile`, `leaderboard*`, `stats*`, `week_*`, `daily_*`, `feedback_*`, `is_admin`, `admin_*`, `event_log`, `topic_recent`, `egg_*`.
- **Pravila za novi SQL:** `create table if not exists`, `create or replace function` (ako se mijenja povratni tip: prvo `drop function if exists …(tipovi)`), RLS uključen, `revoke all` na tablici, `grant execute … to anon, authenticated` na funkciji, admin provjera gdje treba, ograničenja količine (rate limit) za upise iz klijenta. Provjeri na lokalnom Postgresu ako ga imaš.
- **Ukupna ljestvica** (`leaderboard_total`) mora brojati ista gradiva kao `overall(p)` u aplikaciji: `serpar, ruk, estat, kont, cvor, thev, nort, mag` (+ `freeN` u „Riješeno”).
- Supabase 30. 10. 2026. prestaje automatski davati Data API pristup novim tablicama – nama ne smeta jer klijent ne čita tablice izravno (nema `.from()`), samo RPC.

---

## 9. Testiranje (obavezno prije predaje)

Playwright s Chromiumom, Supabase se **mocka** (klijent ne smije dirati pravu bazu):

```js
const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();
const p=await b.newPage({viewport:{width:1280,height:900},colorScheme:'dark'});const errs=[];p.on('pageerror',e=>errs.push(e.message));
await p.route(/fonts|zgo/,r=>r.abort());
await p.route('**/supabase.min.js',r=>r.fulfill({contentType:'text/javascript',body:`window.supabase={createClient:()=>({rpc:async(n,a)=>{
  if(n==='register')return{data:[{token:'t',nick:a.p_nick,state:{course:'etr',tourOffered:true,seenIntro:true}}]};
  if(n==='is_admin')return{data:false};
  return{data:[]}}})}`}));
await p.goto('file://'+process.cwd()+'/test.html');await p.waitForTimeout(800);
await p.fill('#nick','Tst');await p.fill('#pin','1111');await p.click('#reg');await p.waitForTimeout(800);
await p.evaluate(()=>{const P=prof();P.course='etr';P.tourOffered=true;P.newsSeen=NEWS_ID;document.querySelectorAll('#fbm,#tourask').forEach(x=>x.remove());view='home';render()});
// … provjere …
console.log(errs);await b.close()})();
```

- Prije klikanja ukloni prekrivače `#fbm` i `#tourask` (vodič, izbor kolegija, ankete).
- Greška „Cannot read properties of undefined (reading 'estat')” javlja se samo s mockom – zanemari.
- Provjeri i **ulogu studenta** (`is_admin` → false): administratorski gumbi se ne smiju vidjeti.
- Provjeri **mobitel 390×844** (`document.documentElement.scrollWidth` ≤ 390) i **svijetlu i tamnu temu**; snimi zaslon i pogledaj ga.
- Za generirana pitanja provjeri sva automatski (npr. svaki zadatak s trikom riješi algoritmom do kraja bez greške; svako pitanje iz Elektrostatike: odgovor = izračun, crtež i objašnjenje bez greške).
- Za SQL: lokalni Postgres ako postoji, inače barem pažljivo pregledaj i navedi Alenu očekivani rezultat („Success. No rows returned”).

---

## 10. Česte zamke (naučeno)

- `daily_set` u bazi prima **točno 10** pitanja – izazov zato šalje 10, a koristi 5.
- `CHinfo` se ne pamti kad je izazov bio nedostupan (`off`), inače bi do kraja posjeta pisalo „nije dostupan”.
- Rezultati izazova po starom bodovanju (do 100) prikazuju se podijeljeni s 10.
- `estat`: odgovor mora biti točno jedan od 8 smjerova ili „ostaje” (`dirOf` vraća null inače); za doprinos koji nije pod 45° objašnjenje kaže „koso, približno …” (`dirNear`).
- Pri dodavanju pitanja u postojeće banke ne mijenjaj stare id-jeve (statistika i `p.wrong` ih koriste) – nova idu na kraj.
- `renderRuk` za vrste iz `RKTR` ne smije ići u `renderRukMC`.
- Pri ponovnom renderu `main` nestaju elementi dodani izvana – zato se dodaju iz MutationObservera.
- Tekst „+0,0” uz razinu nije greška: Elo daje male promjene za laka pitanja.
- `boardAll`: `false`/`true` nisu stringovi.

---

## 11. Sadržaj i nazivlje

Pitanja i zadaci prate predavanja (EtRpred) i auditorne vježbe (ETR_AV) kolegija: iste oznake (E, R₁, E_T, R_T, U_AB, μ₀, μᵣ…), „priključnice A i B”, „prazni hod”, „kratki spoj”, „ugasiti izvore (naponski → kratki spoj, strujni → prekid)”, „prilagođenje po snazi”. U magnetskom polju uvijek je zadan μᵣ (u zraku μᵣ = 1). Brojevi s decimalnim zarezom.
