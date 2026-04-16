# Savia-ren AST Estrategia — Kodearen Ulermena eta Kalitatea

> Dokumentu teknikoa: Savia-k nola erabiltzen dituen Zuhaitz Sintaktiko Abstraktuak
> kode legatua ulertzeko eta bere agenteek sortutako kodearen kalitatea bermatzeko.

---

## Konpontzen duen arazoa

IA agenteek abiadura handian sortzen dute kodea. Egiturazko balioztapenik gabe, kode horrek hau egin dezake:
- Produkzioan huts egiten duten async blokeo-ereduak sartu
- Benetako kargapean errendimendua %10era degradatzen duten N+1 kontsultak sortu
- `catch {}` bloke hutsetan salbuespenak isilarazi, akats kritikoak ezkutatuz
- 300 lerroko fitxategi bat barne-mendekotasunak ulertu gabe aldatu

Savia-k bi arazoak teknologia berarekin konpontzen ditu: AST.

---

## Arkitektura laukoitza: lau helburu, zuhaitz bat

```
Iturburu-kodea
     │
     ▼
Zuhaitz Sintaktiko Abstraktua (AST)
     │
     ├──► Ulermena (editatu AURRETIK)                   ← PreToolUse hook-a
     │         Dagoeneko dagoena ulertzen du
     │         Ez du ezer aldatzen
     │         Editatu aurreko testuinguru-injekzioa
     │
     ├──► Kalitatea (sortu ONDOREN)                      ← PostToolUse async hook-a
     │         Idatzi berri dena balioztatu
     │         12 Quality Gate unibertsal
     │         0-100 puntuaziodun txostena
     │
     ├──► Kode-mapak (.acm)                              ← Saio arteko testuinguru iraunkorra
     │         Saio aurretik aurre-sortua
     │         Gehienez 150 lerro .acm fitxategiko
     │         @include bidezko karga progresiboa
     │
     └──► Giza-mapak (.hcm)                              ← Zor kognitiboaren aurkako borroka aktiboa
               Hizkuntza naturaleko narratiba
               Gizakiek balioztatu, ez CI-ak
               Kodea zergatik existitzen den, ez soilik zer egiten duen
```

Diseinu-gakoa: zuhaitz berberak kodearen bizitza-zikloaren **lau** fasetan balio du,
tresna ezberdinekin eta hook pipeline-aren momentu ezberdinetan.

---

## 1. zatia — Kode legatuaren ulermena

### Printzipioa

Agente batek fitxategi bat editatu aurretik, Savia-k bere egitura-mapa erauzten du.
Agenteek mapa hori bere testuinguruan jasotzen du, kodea aurrez irakurri balu bezala.

### Erauzte-pipeline-a (3 geruza)

```
Helburu-fitxategia
      │
      ▼
1. geruza: Tree-sitter (unibertsala, 0 runtime-menpekotasun)
  • Language Pack-eko hizkuntza guztiak
  • Klaseak, funtzioak, metodoak, enumak
  • Import deklarazioak
  • ~1-3s, %95 estaldura semantikoa

      │ (erabilgarri ez bada)
      ▼
2. geruza: Hizkuntzaren tresna semantiko natibo
  • Python: ast.walk() (built-in modulua, %100 zehaztasuna)
  • TypeScript: ts-morph (Compiler API osoa)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, %100 estaldura semantikoa

      │ (erabilgarri ez bada)
      ▼
3. geruza: Grep-estrukturala (menpekotasun zero absolutua)
  • 16 hizkuntzarako regex unibertsala
  • Klaseak, funtzioak, importak ereduen arabera erauzten ditu
  • <500ms, ~%70 estaldura semantikoa
  • Beti erabilgarri — ez du inoiz huts egiten
```

**Bermatutako degradazio-araua**: tresna aurreratuek huts egiten badute,
grep-estrukturalak beti funtzionatzen du. Tresna faltaren ondorioz editazioa inoiz ez da blokeatzen.

### Abiarazle automatikoa: PreToolUse hook-a

```
Erabiltzaileak fitxategia editatzeko eskatzen du
         │
         ▼
Hook-a: ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Hookearen JSON inputetik file_path irakurtzen du
  • Egiaztatzen du: fitxategiak ≥50 lerro ditu?
  • Bai bada: ast-comprehend.sh --surface-only exekutatzen du (15s timeout)
  • Erauzten du: klaseak, funtzioak, konplexutasun ziklomatikoa
  • Konplexutasuna > 15 bada: ohartarazpen ikusgarria igortzen du
         │
         ▼
Agenteek bere testuinguruan jasotzen du:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  Fitxategia: src/Services/AuthService.cs
  Lerroak: 248  |  Klaseak: 1  |  Funtzioak: 12
  Konplexutasuna: 42 erabaki-puntu  ⚠️  Arretaz jokatu

  Egitura-mapa:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
Agenteek fitxategiaren testuinguru osoarekin editatzen du
```

Hook-a **ez-asinkrono** da, agenteek editatu AURRETIK osatu behar baitu.
Hook-ak beti `exit 0` egiten du — ulermena aholku-emailea da, inoiz ez du blokeatzen.

---

## 2. zatia — Sortutako kodearen kalitatea

### 12 Quality Gate unibertsal

| Gate | Izena | Sailkapena | Hizkuntzak |
|------|-------|------------|------------|
| QG-01 | Async/konkurrentziak blokeatua | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | N+1 kontsultak | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference guardarik gabe | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Konstanterik gabeko zenbaki magikoak | WARNING | Hizkuntza guztiak |
| QG-05 | Catch hutsa / irentsitako salbuespenak | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Konplexutasun ziklomatikoa >15 | WARNING | Hizkuntza guztiak |
| QG-07 | Metodoak >50 lerro | INFO | Hizkuntza guztiak |
| QG-08 | Bikoizketa >%15 | WARNING | Hizkuntza guztiak |
| QG-09 | Hardcodeaturiko sekretuak | BLOCKER | Hizkuntza guztiak |
| QG-10 | Produkzioan gehiegizko logging | INFO | Hizkuntza guztiak |
| QG-11 | Kode hila / dead code | INFO | Hizkuntza guztiak |
| QG-12 | Proba gabeko negozio-logika | BLOCKER | Hizkuntza guztiak |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Abiarazle automatikoa: PostToolUse async hook-a

```
Agenteek fitxategia idazten/editatzen du
         │
         ▼
Hook-a: ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • Atzeko planoan exekutatzen da — ez du agentea blokeatzen
  • Hizkuntza luzapenaren arabera detektatzen du
  • ast-quality-gate.sh exekutatzen du fitxategiarekin
  • Puntuazioa (0-100) eta kalifikazio (A-F) kalkulatzen du
  • Puntuazioa < 60 bada (D edo F maila): alerta ikusgarria igortzen du
  • Txostena output/ast-quality/ karpetan gordetzen du
```

---

## 3. zatia — Agenteetarako kode-mapak (.acm)

### Arazoa

Agente-saio bakoitza hutsetik hasten da. Aurrez sortutako testuingurunik gabe,
agenteek bere testuinguru-leihoarenn %30–60 kontsumitzen du arkitektura
aztertzen, kode-lerro bat idatzi aurretik.

Agent Code Maps (.acm) saio artean iraunkorrak diren egitura-mapak dira,
`.agent-maps/` karpetan gordetakoak eta agenteak zuzenean kontsumitzeko
optimizatuak.

```
.agent-maps/
├── INDEX.acm              ← Nabigazio sarrera-puntua
├── domain/
│   ├── entities.acm       ← Domeinu-entitateak
│   └── services.acm       ← Negozio-zerbitzuak
├── infrastructure/
│   └── repositories.acm   ← Biltegiak eta datuen sarbidea
└── api/
    └── controllers.acm    ← Kontroladoreak eta amaierako puntuak
```

**.acm fitxategiko 150 lerroko muga**: hazten bada, azpikarpetetan automatikoki banatzen da.
**@include sistema**: eskaerazko karga progresiboa — agenteek behar duena soilik kargatzen du.

### Freskotasun-eredua

| Egoera | Baldintza | Agente-ekintza |
|--------|-----------|----------------|
| `fresko` | .acm hashak iturburu-kodearekin bat dator | Zuzenean erabili |
| `zaharkitua` | Barne-aldaketak, egitura osasuntsu | Ohar batekin erabili |
| `hautsia` | Fitxategiak ezabatuta edo sinadura publikoak aldatuta | Erabili aurretik birsortu |

### SDD pipeline-rako integrazioa

.acm fitxategiak `/spec:generate` AURRETIK kargatzen dira. Agenteek proiektuaren
benetako arkitektura ezagutzen du lehen tokenetik, itsu-bilaketa gabe.

```
[0] KARGATU — /codemap:check && /codemap:load <scope>
[1-5] SDD Pipeline aldatu gabe
[SDD-ostean] EGUNERATU — /codemap:refresh --incremental
```

---

## 4. zatia — Giza kode-mapak (.hcm)

### Arazoa

Garatzaileek denbora %58 irakurtzen dute kodea eta %42 soilik idazten
(Addy Osmani, 2024). %58 hori biderkatu egiten da **zor kognitiboa** duten eremuetan:
inork ukitzen duen bakoitzean berriz ikasi behar dituen azpisistemak, zor kognitiboa.

`.hcm` fitxategiak zor kognitiboaren aurkako borrokan aktibo dabiltza: `.acm` fitxategien
giza bikiak dira. `.acm`-ak agente bati esaten dion bitartean "zer dagoen eta non",
`.hcm`-ak garatzaile bati esaten dio "zergatik dagoen eta nola pentsatu".

### .hcm formatua

```markdown
# {Osagaia} — Giza mapa (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{osagaia}.acm

## Historia (1 paragrafo)
Zer arazo konpontzen duen, giza hizkuntzan.

## Buruko eredua
Osagai hau nola pentsatu. Analogiak lagungarriak badira.

## Sarrera-puntuak (zeregina → non hasi)
- X gehitzeko → hasi {fitxategia}:{atala}
- Y huts egiten badu → sarrera-puntua da {hook/script}

## Gotchas (portaera ez-agerikoak)
- Garatzaile berrien harridurak
- Azpisistemaren dokumentatutako tranpak

## Zergatik horrela eraikita dagoen
- Diseinu-erabakiak beren motibazioaz
- Konpromiso onartu kontzienteak

## Zorren adierazleak
- Nahasmen-eremu ezagunak edo berregiturapen-zain daudenak
```

### Zor puntuazioa (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Mapa freskoa
4-6: Laster berrikusi
7-10: Zor aktiboa — diru-kostua orain
```

### Proiektuko kokapena

Proiektu bakoitzak bere mapak kudeatzen ditu bere karpetaren barruan:

```
projects/{proiektua}/
├── CLAUDE.md
├── .human-maps/               ← Garatzaileentzako narraziozkoak
│   ├── {proiektua}.hcm        ← Proiektuaren mapa orokorra
│   └── _archived/             ← Ezabatutako edo bateratutako osagaiak
└── .agent-maps/               ← Agenteentzako estrukturalak
    ├── {proiektua}.acm
    └── INDEX.acm
```

### Bizi-zikloa

```
Sorrera (/codemap:generate-human) → Giza balioztapena → Aktibo
         ↓ kode aldaketak
      .acm birsortu → .hcm zaharkitu markatuta → Freskatze (/codemap:walk)
```

**Arau aldaezina:** `.hcm` batek ezin du inoiz `.acm` berria baino berriago den `last-walk` bat eduki.
`.acm` zaharkitua bada, `.hcm` ere zaharkitua da, bere dataren independienteki.

### Komandoak

```bash
# .acm + kodetik .hcm zirriborroa sortu
/codemap:generate-human projects/nire-proiektua/

# Birrakurketarako gidatutako saioa (freskatze)
/codemap:walk nire-modulua

# Proiektuko .hcm guztien zor-puntuazioak erakutsi
/codemap:debt-report

# Adierazitako .hcm-ren freskatzea behartu
/codemap:refresh-human projects/nire-proiektua/.human-maps/nire-modulua.hcm
```

---

## Sistemaren bermeak

1. **Inoiz ez du editazioa blokeatzen**: RN-COMP-02 — ulermena huts egiten badu, beti exit 0
2. **Inoiz ez du kodea suntsitzen**: RN-COMP-02 — ulermena irakurtzeko soilik da
3. **Beti du itzulera-bidea**: RN-COMP-05 — grep-estrukturalak gutxieneko estaldura bermatzen du
4. **Irizpide agnostikoak**: 12 QG hizkuntza guztiei berdin aplikatzen zaizkie
5. **Eskema bateratua**: irteera guztiak hizkuntzeen artean konparagarriak dira

---

## Erreferentziak

- Ulermen-skill: `.claude/skills/ast-comprehension/SKILL.md`
- Kalitate-skill: `.claude/skills/ast-quality-gate/SKILL.md`
- Ulermen-hook: `.claude/hooks/ast-comprehend-hook.sh`
- Kalitate-hook: `.claude/hooks/ast-quality-gate-hook.sh`
- Ulermen-scripta: `scripts/ast-comprehend.sh`
- Kalitate-scripta: `scripts/ast-quality-gate.sh`
- Kode-mapen skill: `.claude/skills/agent-code-map/SKILL.md`
- Giza mapen araua: `docs/rules/domain/hcm-maps.md`
- Giza mapen skill: `.claude/skills/human-code-map/SKILL.md`
- Workspace-mapak: `.human-maps/`
- Proiektuen mapak: `projects/*/.human-maps/*.hcm`
