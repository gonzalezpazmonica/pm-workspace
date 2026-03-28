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

## Arquitectura — Daemon + Proxy + Fallback

### Flux principal (daemon actiu)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon unificat)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Flux fallback (daemon caigut)

```
gate.sh detecta daemon offline → inline regex + NFKC + base64 + cross-write
  → mateixes deteccions, sense NER (Presidio no disponible sense daemon)
```

El fallback garanteix que Shield **sempre protegeix**, fins i tot sense daemon.

---

## Les 4 capes

### Capa 1 — Porta determinista (regex + NFKC + base64 + cross-write)

Escaneja el contingut abans d'escriure un fitxer públic. Inclou:

- Regex per a credencials, IPs, tokens, claus privades, SAS tokens
- Normalització Unicode NFKC (detecta dígits fullwidth)
- Descodificació base64 de blobs sospitosos
- Cross-write: combina contingut existent en disc + nou per detectar divisions
- Normalització de path (resol `../` traversal)
- Latència: < 2s. Dependències: bash, grep, jq, python3

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
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
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

| Component | Fitxer | Descripció |
|-----------|--------|------------|
| Daemon unificat | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health a localhost:8444 |
| Proxy API | `scripts/savia-shield-proxy.py` | Intercepta prompts Claude, emmascara/desemmascara |
| NER daemon | `scripts/shield-ner-daemon.py` | Presidio+spaCy persistent en RAM (~100ms) |
| Gate hook | `.claude/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Auditoria hook | `.claude/hooks/data-sovereignty-audit.sh` | PostToolUse async: re-scan fitxer complet |
| Classificador LLM | `scripts/ollama-classify.sh` | Capa 2 Ollama (fallback si daemon caigut) |
| Emmascarador | `scripts/sovereignty-mask.py` | Capa 4 mask/unmask reversible |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | Scan fitxers staged abans de commit |
| Setup | `scripts/savia-shield-setup.sh` | Instal·lador: deps, models, token, daemons |
| Force-push guard | `.claude/hooks/block-force-push.sh` | Bloqueja force-push, push a main, amend |
| Regla de domini | `.claude/rules/domain/data-sovereignty.md` | Arquitectura i polítiques |

**Logs d'auditoria:**
- `output/data-sovereignty-audit.jsonl` — decisions de les capes 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisions del LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operacions de masking

---

## Qualitat i testing

- Suite automatitzada de tests (BATS) amb cobertura de core, edge cases i mocks
- Auditories de seguretat independents (Red Team, Confidencialitat, Code Review)
- Mapeig a frameworks de compliance (RGPD, ISO 27001, EU AI Act)

---

## Capacitats de detecció avançades

- **Base64**: descodifica blobs sospitosos i re-escaneja el contingut descodificat
- **Unicode NFKC**: normalitza caràcters fullwidth i variants abans d'aplicar regex
- **Cross-write**: combina contingut existent en disc amb el nou per detectar patrons dividits entre escriptures
- **Proxy API**: intercepta tots els prompts sortints i emmascara entitats automàticament
- **NER bilingüe**: anàlisi en espanyol i anglès combinat, amb deny-list per projecte
- **Anti-injection**: triple defensa en el classificador local (delimitadors, sandwich, validació estricta)

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

L'instal·lador:
1. Verifica dependències (python3, jq, ollama, presidio, spacy)
2. Descarrega models necessaris (qwen2.5:7b, es_core_news_md)
3. Genera token d'autenticació (`~/.savia/shield-token`)
4. Arrenca `savia-shield-daemon.py` a localhost:8444 (scan/mask/unmask)
5. Arrenca `savia-shield-proxy.py` a localhost:8443 (proxy API)
6. Arrenca `shield-ner-daemon.py` (NER persistent en RAM)

Després d'executar, tota comunicació amb l'API passa pel proxy que
emmascara entitats sensibles automàticament.

**Sense daemon:** els hooks de gate i auditoria segueixen funcionant en
mode fallback (regex + NFKC + base64 + cross-write). Claude Code
mai es bloqueja per falta de daemon.

---

## Estat per defecte — Desactivat

Savia Shield està **desactivat per defecte**. Els hooks estan instal·lats
però no s'executen fins que els activeu. Això evita latència innecessària
en màquines sense projectes privats.

Activeu-lo quan comenceu a treballar amb dades de clients.

## Activar i desactivar

```bash
# Amb la comanda slash (recomanat)
/savia-shield enable    # Activar
/savia-shield disable   # Desactivar
/savia-shield status    # Verificar estat i instal·lació
```

O editant `.claude/settings.local.json` directament:

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

Per desactivar, canviar `"true"` per `"false"`.
