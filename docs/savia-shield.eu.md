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

## Arkitektura — Daemon + Proxy + Fallback

### Fluxu nagusia (daemon aktibo)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon bateratua)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Fallback fluxua (daemon eroria)

```
gate.sh daemon offline detektatzen du → inline regex + NFKC + base64 + cross-write
  → detekzio berdinak, NER gabe (Presidio ez dago daemonik gabe)
```

Fallback-ak bermatzen du Shield-ek **beti babesten** duela, daemonrik gabe ere.

---

## 4 geruzak

### 1. Geruza — Ate determinista (regex + NFKC + base64 + cross-write)

Edukia eskaneatzen du fitxategi publiko bat idatzi aurretik. Biltzen du:

- Regex kredentzialetarako, IPetarako, tokenetarako, gako pribatuetarako, SAS tokenetarako
- Unicode NFKC normalizazioa (fullwidth digituak detektatzen ditu)
- base64 deskodifikazioa blob susmagarrietan
- Cross-write: diskoko lehendik dagoen edukia + eduki berria konbinatzen ditu splita detektatzeko
- Path normalizazioa (`../` traversal ebazten du)
- Latentzia: < 2s. Menpekotasunak: bash, grep, jq, python3

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
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Izen fiktizio pool pertsonentzat, enpresentzat eta sistementzat (konfiguragarria)
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

| Osagaia | Fitxategia | Deskribapena |
|---------|------------|--------------|
| Daemon bateratua | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health localhost:8444-en |
| API Proxy | `scripts/savia-shield-proxy.py` | Claude promptak atzematen ditu, maskaratzen/desmaskaratzen |
| NER daemon | `scripts/shield-ner-daemon.py` | Presidio+spaCy iraunkorra RAM-ean (~100ms) |
| Gate hook | `.opencode/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Auditoretza hook | `.opencode/hooks/data-sovereignty-audit.sh` | PostToolUse async: fitxategi osoa berriro eskaneatzen |
| LLM sailkatzailea | `scripts/ollama-classify.sh` | 2. Geruza Ollama (fallback daemon eroria bada) |
| Maskaratzailea | `scripts/sovereignty-mask.py` | 4. Geruza mask/unmask itzulgarria |
| Git pre-commit | `scripts/pre-commit-sovereignty.sh` | Staged fitxategiak eskaneatzen commit aurretik |
| Setup | `scripts/savia-shield-setup.sh` | Instalatzailea: deps, modeloak, tokena, daemonak |
| Force-push guard | `.opencode/hooks/block-force-push.sh` | Force-push, main-era push eta amend blokeatzen ditu |
| Domeinu araua | `docs/rules/domain/data-sovereignty.md` | Arkitektura eta politikak |

**Auditoretza-logak:**
- `output/data-sovereignty-audit.jsonl` — 1-3 geruzaren erabakiak
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — LLMaren erabakiak
- `output/data-sovereignty-validation/mask-audit.jsonl` — masking eragiketak

---

## Kalitatea eta testak

- Test suite automatizatua (BATS) core, edge case eta mock-en estaldurarekin
- Segurtasun auditoretza independenteak (Red Team, Konfidentzialtasuna, Code Review)
- Compliance framework-etarako mapaketa (RGPD, ISO 27001, EU AI Act)

---

## Detekzio gaitasun aurreratuak

- **Base64**: blob susmagarriak deskodikatzen ditu eta deskodifikatutako edukia berriro eskaneatzen du
- **Unicode NFKC**: fullwidth karaktereak eta aldaerak normalizatzen ditu regex aplikatu aurretik
- **Cross-write**: diskoko lehendik dagoen edukia berriarekin konbinatzen du idazketa artean zatitutako ereduak detektatzeko
- **API Proxy**: irteten diren prompt guztiak atzematen ditu eta entitateak automatikoki maskaratzen ditu
- **NER elebidunak**: gaztelaniaz eta ingelesez konbinatutako analisia, proiektu bakoitzeko deny-list-ekin
- **Anti-injection**: hiru defentsa sailkatzaile lokalean (mugatzaileak, sandwich, balioztapen zorrotza)

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

Instalatzaileak:
1. Menpekotasunak egiaztatzen ditu (python3, jq, ollama, presidio, spacy)
2. Beharrezko modeloak deskargatzen ditu (qwen2.5:7b, es_core_news_md)
3. Autentifikazio tokena sortzen du (`~/.savia/shield-token`)
4. `savia-shield-daemon.py` abiarazten du localhost:8444-en (scan/mask/unmask)
5. `savia-shield-proxy.py` abiarazten du localhost:8443-en (API proxy)
6. `shield-ner-daemon.py` abiarazten du (NER iraunkorra RAM-ean)

Exekutatu ondoren, APIarekin komunikazio guztia proxy-tik pasatzen da,
entitate sentikorrak automatikoki maskaratzen dituena.

**Daemonik gabe:** gate eta auditoretza hook-ak fallback moduan
funtzionatzen jarraitzen dute (regex + NFKC + base64 + cross-write).
Claude Code ez da inoiz blokeatzen daemon faltagatik.

---

## Lehenetsitako egoera — Desgaituta

Savia Shield **lehenetsita desgaituta** dago. Hook-ak instalatuta daude
baina ez dira exekutatzen aktibatu arte. Honek beharrezkoa ez den
latentzia saihesten du proiektu pribatuak ez dituzten makinetan.

Aktibatu bezero-datuekin lan hasi aurretik.

## Aktibatu eta desgaitu

```bash
# Slash komandoarekin (gomendatua)
/savia-shield enable    # Aktibatu
/savia-shield disable   # Desgaitu
/savia-shield status    # Egoera eta instalazioa egiaztatu
```

Edo `.claude/settings.local.json` zuzenean editatuz:

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

Desgaitzeko, aldatu `"true"` `"false"`-ra.
