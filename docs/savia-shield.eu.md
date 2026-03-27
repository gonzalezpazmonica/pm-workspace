# Savia Shield — Datuen Subiranotasun Sistema IA Agentikorako

> Zure bezeroaren datuak ez dira zure makinatik irtengo zure baimenik gabe.

---

## Zer da Savia Shield

Savia Shield 4 geruzako sistema bat da, bezero-proiektuen datu konfidentzialak
babesten dituena IA laguntzaileekin (Claude, GPT, etab.) lan egiten denean.
Datu bakoitza makina lokaletik atera aurretik sailkatzen du, eta entitate
sentikorrak maskaratzen ditu testu-prozesatzaile sakonari cloud APIetara
bidaltzeko behar denean.

**Konpontzen duen arazoa:** IA tresnek promptak kanpoko zerbitzarietara
bidaltzen dituzte. Promptak bezero-izenak, barne-IPak, kredentzialak edo
bileretako datuak baditu, NDAs eta RGPD urratzen dituen datu-ihes bat
gertatzen da.

**Nola konpontzen duen:** 4 geruza independente, bakoitza gizakiek
auditatu dezaketeena.

---

## 4 geruzak

### 1. Geruza — Ate determinista (regex)

Edukia regex ereduekin eskaneatzen du fitxategi bat idatzi aurretik.
Fitxategi publiko batean kredentzialak, IP pribatuak, API tokenak edo
gako pribatuak detektatzen baditu, **idazketa blokeatzen du**.

- Latentzia: < 2 segundo
- Menpekotasunak: bash, grep, jq (POSIX estandarra)
- Beti aktibo, interneterako konexiorik gabe ere
- base64 detekzioa: blob susmagarriak deskodifikatzen ditu eta berriro eskaneatzen

### 2. Geruza — Sailkapen lokala LLMrekin (Ollama)

Regexak ezin duen edukia ebaluatzeko (testu semantikoa, bilera-aktak,
negozio-deskribapenak), IA modelo lokal batek (qwen2.5:7b) testua
KONFIDENTZIALA edo PUBLIKOA gisa sailkatzen du.

- Modeloa localhost:11434-en exekutatzen da — datuak **ez dira inoiz irtengo**
- Latentzia: 2-5 segundo
- Prompt injection-aren aurkako erresistentzia:
  - [BEGIN/END DATA] mugatzaileek testua promptetik isolatzen dute
  - Sandwich defense: instrukzioa datuak ondoren errepikatu
  - Balioztapen zorrotza: erantzuna ez bada zehazki
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, CONFIDENTIAL gisa tratatzen da
- Degradazioa: Ollama martxan ez badago, 1. Geruza bakarrik erabiltzen da

### 3. Geruza — Idazketaren ondoko auditoretza

Idazketa bakoitzaren ondoren, hook asinkrono batek diskoko fitxategi
osoa berriro eskaneatzen du (moztu gabe) 1-2. Geruzek galdutako ihesak
bilatuz.

- Lan-fluxua ez du blokeatzen
- Fitxategi OSOA eskaneatzen du (moztu gabe)
- Ihesa detektatzen badu, berehalako abisua

### 4. Geruza — Maskaraketa itzulgarria

Claude Opus edo Sonnet-en potentzia analisi konplexurako behar duzunean,
Savia Shield-ek entitate errealak (pertsonak, enpresak, proiektuak,
sistemak, IPak) izen fiktizio koherenteekin ordezkatzen ditu.

**Fluxu osoa (5 urrats):**

```
1. URRATSA — Erabiltzaileak datu errealak dituen testu bat du (N4)
  "Bezero PM-ak fakturazio modulua lehenetsi zuela eskatu zuen"

2. URRATSA — sovereignty-mask.sh mask → entitateak ordezkatzen ditu
  Pertsona errealak     → izen fiktizoak (Alice, Bob, Carol...)
  Bezero enpresa        → enpresa fiktizio (Acme Corp, Zenith...)
  Proiektu erreala      → proiektu fiktizio (Project Aurora...)
  Barne-sistemak        → sistema fiktizio (CoreSystem, DataHub...)
  IP pribatuak          → RFC 5737 proba-IPak (198.51.100.x)
  Mapa mask-map.json-en gordetzen da (lokala, N4)

3. URRATSA — Maskaratutako testua Claude Opus/Sonnet-era bidaltzen da
  Claude-k "Acme Corp-eko Alice Chen-ek CoreSystem lehenetsi zuela eskatu zuen" prozesatzen du
  Claude-k ez ditu datu errealak ikusten — entitate fiktizoekin lan egiten du
  Arrazonamendua eta analisia berdinak dira

4. URRATSA — Claude-k entitate fiktizoekin erantzuten du
  "Acme Corp-eko Alice Chen-ek CoreSystem DataHub-en gainetik
   lehenetsi dezala gomendatzen dut Q3 epemuga dela eta..."

5. URRATSA — sovereignty-mask.sh unmask → datu errealak berrezartzen ditu
  Mapa alderantzikatzen du: Alice Chen → pertsona erreala, Acme Corp → enpresa erreala
  Erabiltzaileak erantzuna izen zuzenetan jasotzen du
  Mapa ezabatzen da edo gordetzen da proiektuaren politikaren arabera
```

**Bermeak:**
- Korrespondentzia-mapa lokala (N4, inoiz ez git-en)
- 95+ entitate mapeatu proiektu bakoitzeko GLOSSARY-MASK.md bidez
- 32 pertsona, 12 enpresa, 16 sistema fiktizio pool
- mask/unmask eragiketa bakoitza audit log-ean erregistratua
- Koherentzia: entitate berberak beti mapea berdina du

---

## 5 konfidentzialtasun maila

| Maila | Izena | Nork ikusten du | Adibidea |
|-------|-------|-----------------|---------|
| N1 | Publikoa | Internet | Workspace kodea, txantiloiak |
| N2 | Enpresa | Erakundea | Org konfigurazioa, tresnak |
| N3 | Erabiltzailea | Zuk bakarrik | Zure profila, lehentasunak |
| N4 | Proiektua | Proiektu-taldea | Bezero-datuak, arauak |
| N4b | PM bakarrik | PM-ak bakarrik | One-to-one-ak, ebaluazioak |

**Savia Shield-ek N4/N4b → N1 mugak babesten ditu.**
Datu sentikorrak kokapen pribatutan (N2-N4b) idaztea beti onartuta dago.

---

## Zer detektatzen du (1. Geruza)

- Connection strings (JDBC, MongoDB, SQL Server)
- AWS gakoak (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Azure SAS tokenak (sv=20XX-)
- Google API Keys (AIza...)
- Gako pribatuak (-----BEG​IN...PRIVATE KEY-----)
- RFC 1918 IP pribatuak (10.x, 172.16-31.x, 192.168.x)
- base64-n kodetutako sekretuak

---

## Nola erabili

### Claude-ra bidaltzeko maskaraketa

```bash
# Testua bidaltzeko aurretik maskaratu
bash scripts/sovereignty-mask.sh mask "Bezero-datuak dituen testua" --project my-project

# Claude-ren erantzuna desmaskaratu
bash scripts/sovereignty-mask.sh unmask "Acme Corp duen erantzuna"

# Korrespondentzia-taula ikusi
bash scripts/sovereignty-mask.sh show-map
```

### Atea funtzionatzen duela egiaztatu

```bash
# Testak exekutatu
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Ollama localhost-en dagoela egiaztatu
netstat -an | grep 11434
```

---

## Auditatzeko gaitasuna — Zero kutxa beltz

Osagai bakoitza gizakiak irakur dezakeen testu-lau fitxategi bat da:

| Osagaia | Fitxategia | Lerroak |
|---------|------------|---------|
| Regex atea | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| LLM sailkatzailea | `scripts/ollama-classify.sh` | 99 |
| Idazketaren ondoko auditoretza | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Maskaratzailea | `scripts/sovereignty-mask.py` | ~180 |
| Git pre-commit | `scripts/pre-commit-sovereignty.sh` | 72 |
| Domeinu araua | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Auditoretza-logak:**
- `output/data-sovereignty-audit.jsonl` — 1-3 geruzaren erabakiak
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — LLMaren erabakiak
- `output/data-sovereignty-validation/mask-audit.jsonl` — masking eragiketak

---

## Balioztatze

- **51 test automatizatu** (BATS) — core + edge cases + fixes + mocks
- **3 auditoretza independente** — Red Team, Konfidentzialtasuna, Code Review
- **24 ahultasun aurkitu — 24 konponduta, 0 zain**
- **0 hondar-muga** — denak teknikoki zuzendu
- **Segurtasun-puntuazioa: 100/100**
- **RGPD/ISO 27001/EU AI Act mapaketa** osoa

---

## Muga teknikoak eta nola arintzen diren

### base64 eta datu-kodeketa

Savia Shield-ek automatikoki dekodikatzen ditu base64 blob-ak (gehienez
200 karaktereko 20 blob arte) eta deskodifikatutako edukia berriro
eskaneatzen du. Deskodifikatutako blob-ak kredentzial bat edo IP barne
bat badauka, blokeatzen da.

### Unicode eta homoglifoak

Regex aplikatu aurretik, edukia Unicode NFKC-rekin normalizatzen da.
Honek fullwidth karaktereak eta beste aldaerak ASCII kanonikora bihurtzen
ditu. Normalizazioaren ondoren, fullwidth digituak ASCII digitutan
bihurtzen dira eta regexak behar bezala detektatzen ditu.

### Idazketa zatituak (split-write)

Cross-write defentsa: dagoeneko diskoan dagoen fitxategi publiko batean
idazten denean, Savia Shield-ek lehendik dagoen edukia irakurtzen du eta
eduki berriarenarekin konbinatzen du. Regexak testu konbinatuaren gainean
aplikatzen dira, bi idazketen konbinaketak osatutako ereduak detektatuz.

### Elkarrizketa-edukia (IA laguntzaileari egindako promptak)

4. Geruzak (maskaraketa itzulgarria) testua txatera itsatsi aurretik
maskaratzea ahalbidetzen du. NER hook-ak laguntzaileak irakurtzen dituen
fitxategiak eskaneatzen ditu. Prestakuntza: erabiltzaileek fitxategiei
bidez erreferentzia egiten diete edukia kopiatzen beharrean. Hondar-muga:
ez dago erabiltzaileak promptan zuzenean idazten duen testuaren
interceptazio teknikorik — protokolo-mailan integrazioa behar da
(etorkizuneko hobekuntza).

### Prompt injection sailkatzaile lokalean

Hiru defentsa: (1) [BEGIN/END DATA] mugatzaileak, (2) sandwich defense
datu-ondoren instrukzioa errepikatuz, (3) outputaren balioztapen zorrotza
(erantzun baliogabea = automatikoki CONFIDENTIAL). temperature=0 eta
num_predict=5 eraso-azalera mugatzen dute.

### NER doitasuna gaztelaniaz

ES+EN eskaneatze bikoitza: NER-ek analisia bi hizkuntzetan exekutatzen du
eta emaitzak konbinatzen ditu. GLOSSARY-MASK.md-k proiektu-entitate
espezifikoak deny-list gisa kargatzen ditu (score 1.0, detekzio bermatua).

---

## Dokumentazio teknikoa (EN, segurtasun batzordearentzat)

- `docs/data-sovereignty-architecture.md` — Arkitektura teknikoa
- `docs/data-sovereignty-operations.md` — Compliance eta arriskua
- `docs/data-sovereignty-auditability.md` — Auditoretza gida
- `docs/data-sovereignty-finetune-plan.md` — Fine-tuned modelo plana

---

## Eskakizunak

- Ollama instalatuta (`ollama --version`)
- Modeloa deskargatuta (`ollama pull qwen2.5:7b`)
- jq instalatuta (JSON parsing-erako)
- Python 3.12+ (masking eta NER-erako)
- Presidio (`pip install presidio-analyzer`) — 1.5 Geruza NER-erako
- spaCy gaztelaniako modeloa (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM gutxienez (16+ gomendatua)


---

## Instalazio azkarra

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```
