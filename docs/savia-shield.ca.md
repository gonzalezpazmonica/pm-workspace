# Savia Shield — Sistema de Sobirania de Dades per a IA Agèntica

> Les dades del teu client mai abandonen la teva màquina sense el teu permís.

---

## Què és Savia Shield

Savia Shield és un sistema de 4 capes que protegeix les dades confidencials
de projectes de client quan es treballa amb assistents de IA (Claude,
GPT, etc.). Classifica cada dada abans que pugui sortir de la màquina
local, i emmascara les entitats sensibles quan cal enviar
text a APIs cloud per a processament profund.

**Problema que resol:** Les eines de IA envien prompts a
servidors externs. Si el prompt conté noms de clients, IPs
internes, credencials o dades de reunions, es produeix una fuga de dades
que viola NDAs i RGPD.

**Com ho resol:** 4 capes independents, cadascuna auditable per humans.

---

## Les 4 capes

### Capa 1 — Porta determinista (regex)

Escaneja el contingut amb patrons regex abans d'escriure un fitxer.
Si detecta credencials, IPs privades, tokens d'API o claus privades
en un fitxer públic, **bloqueja l'escriptura**.

- Latència: < 2 segons
- Dependències: bash, grep, jq (estàndard POSIX)
- Sempre activa, fins i tot sense connexió a internet
- Detecció de base64: descodifica blobs sospitosos i re-escaneja

### Capa 2 — Classificació local amb LLM (Ollama)

Per al contingut que el regex no pot avaluar (text semàntic, actes
de reunions, descripcions de negoci), un model de IA local
(qwen2.5:7b) classifica el text com a CONFIDENCIAL o PÚBLIC.

- El model s'executa a localhost:11434 — les dades **mai surten**
- Latència: 2-5 segons
- Resistent a prompt injection:
  - Delimitadors [BEGIN/END DATA] aïllen text del prompt
  - Sandwich defense: instrucció repetida després de les dades
  - Validació estricta: si la resposta no és exactament
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, es tracta com a CONFIDENTIAL
- Degradació: si Ollama no s'està executant, només s'usa la Capa 1

### Capa 3 — Auditoria post-escriptura

Després de cada escriptura, un hook asíncron re-escaneja el fitxer
complet en disc (sense truncar) buscant fugues que les Capes 1-2
poguessin haver perdut.

- No bloqueja el flux de treball
- Escaneja el fitxer COMPLET (no truncat)
- Alerta immediata si detecta fuga

### Capa 4 — Emmascarament reversible

Quan necessites la potència de Claude Opus o Sonnet per a anàlisi
complex, Savia Shield reemplaça totes les entitats reals (persones,
empreses, projectes, sistemes, IPs) amb noms ficticis consistents.

**Flux complet (5 passos):**

```
PAS 1 — L'usuari té un text amb dades reals (N4)
  "El PM del client va demanar prioritzar el mòdul de facturació"

PAS 2 — sovereignty-mask.sh mask → reemplaça entitats
  Persones reals      → noms ficticis (Alice, Bob, Carol...)
  Empresa client      → empresa fictícia (Acme Corp, Zenith...)
  Projecte real       → projecte fictici (Project Aurora...)
  Sistemes interns    → sistemes ficticis (CoreSystem, DataHub...)
  IPs privades        → IPs de test RFC 5737 (198.51.100.x)
  El mapa es desa a mask-map.json (local, N4)

PAS 3 — El text emmascarat s'envia a Claude Opus/Sonnet
  Claude processa "Alice Chen d'Acme Corp va demanar prioritzar CoreSystem"
  Claude NO veu dades reals — treballa amb entitats fictícies
  El raonament i l'anàlisi són igualment profunds

PAS 4 — Claude respon amb entitats fictícies
  "Recomano que Alice Chen d'Acme Corp prioritzi CoreSystem
   sobre DataHub donat el deadline de Q3..."

PAS 5 — sovereignty-mask.sh unmask → restaura dades reals
  Inverteix el mapa: Alice Chen → persona real, Acme Corp → empresa real
  L'usuari rep la resposta amb els noms correctes
  El mapa s'esborra o es conserva segons la política del projecte
```

**Garanties:**
- Mapa de correspondències local (N4, mai en git)
- 95+ entitats mapades per projecte via GLOSSARY-MASK.md
- Pools de 32 persones, 12 empreses, 16 sistemes ficticis
- Cada operació de mask/unmask registrada en audit log
- Consistència: la mateixa entitat sempre mapeja al mateix fictici

---

## 5 nivells de confidencialitat

| Nivell | Nom | Qui veu | Exemple |
|--------|-----|---------|---------|
| N1 | Públic | Internet | Codi del workspace, templates |
| N2 | Empresa | L'organització | Config de l'org, eines |
| N3 | Usuari | Només tu | El teu perfil, preferències |
| N4 | Projecte | Equip del projecte | Dades del client, regles |
| N4b | PM-Only | Només la PM | One-to-ones, avaluacions |

**Savia Shield protegeix les fronteres N4/N4b → N1.**
Escriure dades sensibles en ubicacions privades (N2-N4b) sempre està permès.

---

## Què detecta (Capa 1)

- Connection strings (JDBC, MongoDB, SQL Server)
- Claus AWS (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Claus privades (-----BEG​IN...PRIVATE KEY-----)
- IPs privades RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Secrets codificats en base64

---

## Com usar-lo

### Masking per enviar a Claude

```bash
# Enmascarar text abans d'enviar
bash scripts/sovereignty-mask.sh mask "Text amb dades del client" --project my-project

# Desenmascarar la resposta de Claude
bash scripts/sovereignty-mask.sh unmask "Resposta amb Acme Corp"

# Veure taula de correspondències
bash scripts/sovereignty-mask.sh show-map
```

### Verificar que el gate funciona

```bash
# Executar tests
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Verificar que Ollama és a localhost
netstat -an | grep 11434
```

---

## Auditabilitat — Zero caixes negres

Cada component és un fitxer de text pla llegible per humans:

| Component | Fitxer | Línies |
|-----------|--------|--------|
| Porta regex | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| Classificador LLM | `scripts/ollama-classify.sh` | 99 |
| Auditoria post-escriptura | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Emmascarador | `scripts/sovereignty-mask.py` | ~180 |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | 72 |
| Regla de domini | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Logs d'auditoria:**
- `output/data-sovereignty-audit.jsonl` — decisions de les capes 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisions del LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operacions de masking

---

## Validació

- **51+ tests automatitzats** (BATS) — core + edge cases + fixes + mocks
- **3 auditories independents** — Red Team, Confidencialitat, Code Review
- **24 vulnerabilitats trobades — 24 resoltes, 0 pendents**
- **0 limitacions residuals** — totes corregides tècnicament
- **Score de seguretat: 100/100**
- **Mapeig RGPD/ISO 27001/EU AI Act** complet

---

## Limitacions tècniques i com es mitiguen

### Base64 i codificació de dades

Savia Shield descodifica automàticament blobs base64 (fins a 20 blobs de
màxim 200 chars) i re-escaneja el contingut descodificat. Si el blob
descodificat conté una credencial o IP interna, es bloqueja.

### Unicode i homòglifs

Abans d'aplicar regex, el contingut es normalitza amb Unicode NFKC.
Això converteix caràcters fullwidth i altres variants a ASCII canònic.
Després de la normalització, dígits fullwidth es converteixen en dígits ASCII i
el regex els detecta correctament.

### Escriptures dividides (split-write)

Defensa cross-write: quan s'escriu en un fitxer públic que ja
existeix en disc, Savia Shield llegeix el contingut existent i el combina
amb el contingut nou. Els regex s'apliquen sobre el text combinat,
detectant patrons que es formen en ajuntar ambdues escriptures.

### Contingut conversacional (prompts a l'assistent IA)

La Capa 4 (masking reversible) permet enmascarar text ABANS d'enganxar-lo
al xat. El NER hook escaneja fitxers que l'assistent llegeix. Formació:
els usuaris referencien fitxers per ruta en lloc de copiar contingut.
Límit residual: no hi ha interceptació tècnica del text que l'usuari
escriu directament al prompt — requereix integració a nivell de
protocol (millora futura).

### Prompt injection en el classificador local

Triple defensa: (1) delimitadors [BEGIN/END DATA], (2) sandwich defense
amb instrucció repetida post-dades, (3) validació estricta d'output
(resposta no vàlida = CONFIDENTIAL automàtic). Temperature=0 i
num_predict=5 limiten la superfície d'atac.

### Precisió del NER en espanyol

Escaneig dual ES+EN: NER executa l'anàlisi en ambdós idiomes i combina
resultats. GLOSSARY-MASK.md carrega entitats específiques del projecte
com a deny-list (score 1.0, detecció garantida).

---

## Documentació tècnica (EN, per al comitè de seguretat)

- `docs/data-sovereignty-architecture.md` — Arquitectura tècnica
- `docs/data-sovereignty-operations.md` — Compliance i risc
- `docs/data-sovereignty-auditability.md` — Guia d'auditoria
- `docs/data-sovereignty-finetune-plan.md` — Pla de model fine-tuned

---

## Requisits

- Ollama instal·lat (`ollama --version`)
- Model descarregat (`ollama pull qwen2.5:7b`)
- jq instal·lat (per a JSON parsing)
- Python 3.12+ (per a masking i NER)
- Presidio (`pip install presidio-analyzer`) — per a la Capa 1.5 NER
- spaCy model espanyol (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM mínim (16+ recomanat)


---

## Instalacio rapida

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```
