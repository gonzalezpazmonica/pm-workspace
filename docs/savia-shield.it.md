# Savia Shield — Sistema di sovranità dei dati per l'IA agentica

> I dati del tuo cliente non lasciano mai la tua macchina senza il tuo permesso.

---

## Cos'è Savia Shield

Savia Shield è un sistema a 4 livelli che protegge i dati riservati
dei progetti cliente quando si lavora con assistenti IA (Claude,
GPT, ecc.). Classifica ogni dato prima che possa uscire dalla macchina
locale, e maschera le entità sensibili quando è necessario inviare
testo ad API cloud per elaborazione approfondita.

**Problema che risolve:** Gli strumenti IA inviano prompt a
server esterni. Se il prompt contiene nomi di clienti, IP
interne, credenziali o dati di riunioni, si produce una fuga di dati
che viola NDA e GDPR.

**Come lo risolve:** 4 livelli indipendenti, ognuno verificabile dagli esseri umani.

---

## Architettura — Daemon + Proxy + Fallback

### Flusso principale (daemon attivo)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon unificato)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Flusso fallback (daemon inattivo)

```
gate.sh rileva daemon offline → inline regex + NFKC + base64 + cross-write
  → stessi rilevamenti, senza NER (Presidio non disponibile senza daemon)
```

Il fallback garantisce che Shield **protegge sempre**, anche senza daemon.

---

## I 4 livelli

### Livello 1 — Porta deterministica (regex + NFKC + base64 + cross-write)

Scansiona il contenuto prima di scrivere un file pubblico. Include:

- Regex per credenziali, IP, token, chiavi private, token SAS
- Normalizzazione Unicode NFKC (rileva cifre fullwidth)
- Decodifica base64 di blob sospetti
- Cross-write: combina il contenuto esistente su disco + il nuovo per rilevare split
- Normalizzazione dei percorsi (risolve `../` traversal)
- Latenza: < 2s. Dipendenze: bash, grep, jq, python3

### Livello 2 — Classificazione locale con LLM (Ollama)

Per contenuto che il regex non può valutare (testo semantico, verbali
di riunioni, descrizioni di business), un modello IA locale
(qwen2.5:7b) classifica il testo come CONFIDENZIALE o PUBBLICO.

- Il modello gira su localhost:11434 — i dati **non escono mai**
- Latenza: 2-5 secondi
- Resistente a prompt injection:
  - Delimitatori [BEGIN/END DATA] isolano il testo dal prompt
  - Sandwich defense: istruzione ripetuta dopo i dati
  - Validazione rigorosa: se la risposta non è esattamente
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, viene trattata come CONFIDENTIAL
- Degradazione: se Ollama non è in esecuzione, si usa solo il Livello 1

### Livello 3 — Audit post-scrittura

Dopo ogni scrittura, un hook asincrono ri-scansiona il file
completo su disco (senza troncarlo) cercando fughe che i Livelli 1-2
potrebbero aver mancato.

- Non blocca il flusso di lavoro
- Scansiona il file COMPLETO (non troncato)
- Avviso immediato se rileva una fuga

### Livello 4 — Mascheramento reversibile

Quando hai bisogno della potenza di Claude Opus o Sonnet per analisi
complesse, Savia Shield sostituisce tutte le entità reali (persone,
aziende, progetti, sistemi, IP) con nomi fittizi coerenti.

**Flusso completo (5 passi):**

```
PASSO 1 — L'utente ha un testo con dati reali (N4)
  "Il PM del cliente ha chiesto di prioritizzare il modulo di fatturazione"

PASSO 2 — sovereignty-mask.sh mask → sostituisce le entità
  Persone reali       → nomi fittizi (Alice, Bob, Carol...)
  Azienda cliente     → azienda fittizia (Acme Corp, Zenith...)
  Progetto reale      → progetto fittizio (Project Aurora...)
  Sistemi interni     → sistemi fittizi (CoreSystem, DataHub...)
  IP private          → IP di test RFC 5737 (198.51.100.x)
  La mappa viene salvata in mask-map.json (locale, N4)

PASSO 3 — Il testo mascherato viene inviato a Claude Opus/Sonnet
  Claude elabora "Alice Chen di Acme Corp ha chiesto di prioritizzare CoreSystem"
  Claude NON vede dati reali — lavora con entità fittizie
  Il ragionamento e l'analisi sono ugualmente approfonditi

PASSO 4 — Claude risponde con entità fittizie
  "Raccomando che Alice Chen di Acme Corp prioritizzi CoreSystem
   rispetto a DataHub dato il deadline del Q3..."

PASSO 5 — sovereignty-mask.sh unmask → ripristina i dati reali
  Inverte la mappa: Alice Chen → persona reale, Acme Corp → azienda reale
  L'utente riceve la risposta con i nomi corretti
  La mappa viene eliminata o conservata secondo la politica del progetto
```

**Garanzie:**
- Mappa delle corrispondenze locale (N4, mai in git)
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
- Ogni operazione di mask/unmask registrata nell'audit log
- Coerenza: la stessa entità mappa sempre allo stesso fittizio

---

## 5 livelli di riservatezza

| Livello | Nome | Chi vede | Esempio |
|---------|------|----------|---------|
| N1 | Pubblico | Internet | Codice del workspace, template |
| N2 | Azienda | L'organizzazione | Config dell'org, strumenti |
| N3 | Utente | Solo tu | Il tuo profilo, preferenze |
| N4 | Progetto | Team del progetto | Dati del cliente, regole |
| N4b | Solo-PM | Solo la PM | One-to-one, valutazioni |

**Savia Shield protegge i confini N4/N4b → N1.**
Scrivere dati sensibili in posizioni private (N2-N4b) è sempre consentito.

---

## Cosa rileva (Livello 1)

- Connection string (JDBC, MongoDB, SQL Server)
- Chiavi AWS (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Token Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Chiavi private (-----BEG​IN...PRIVATE KEY-----)
- IP private RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Segreti codificati in base64

---

## Come utilizzarlo

### Masking per inviare a Claude

```bash
# Mascherare il testo prima di inviarlo
bash scripts/sovereignty-mask.sh mask "Testo con dati del cliente" --project my-project

# Smascherare la risposta di Claude
bash scripts/sovereignty-mask.sh unmask "Risposta con Acme Corp"

# Visualizzare la tabella delle corrispondenze
bash scripts/sovereignty-mask.sh show-map
```

### Verificare che il gate funzioni

```bash
# Eseguire i test
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Verificare che Ollama sia su localhost
netstat -an | grep 11434
```

---

## Verificabilità — Zero scatole nere

Ogni componente è un file di testo semplice leggibile dagli esseri umani:

| Componente | File | Descrizione |
|-----------|------|-------------|
| Daemon unificato | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health su localhost:8444 |
| Proxy API | `scripts/savia-shield-proxy.py` | Intercetta i prompt Claude, maschera/smaschera |
| Daemon NER | `scripts/shield-ner-daemon.py` | Presidio+spaCy persistente in RAM (~100ms) |
| Hook gate | `.claude/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Hook audit | `.claude/hooks/data-sovereignty-audit.sh` | PostToolUse async: ri-scansione file completo |
| Classificatore LLM | `scripts/ollama-classify.sh` | Livello 2 Ollama (fallback se daemon inattivo) |
| Mascheratore | `scripts/sovereignty-mask.py` | Livello 4 mask/unmask reversibile |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | Scansione file staged prima del commit |
| Setup | `scripts/savia-shield-setup.sh` | Installer: deps, modelli, token, daemon |
| Force-push guard | `.claude/hooks/block-force-push.sh` | Blocca force-push, push su main, amend |
| Regola di dominio | `docs/rules/domain/data-sovereignty.md` | Architettura e politiche |

**Log di audit:**
- `output/data-sovereignty-audit.jsonl` — decisioni dei livelli 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisioni del LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operazioni di masking

---

## Qualità e test

- Suite automatizzata di test (BATS) con copertura di core, edge case e mock
- Audit di sicurezza indipendenti (Red Team, Riservatezza, Code Review)
- Mappatura verso framework di compliance (GDPR, ISO 27001, EU AI Act)

---

## Capacità di rilevamento avanzate

- **Base64**: decodifica blob sospetti e ri-scansiona il contenuto decodificato
- **Unicode NFKC**: normalizza caratteri fullwidth e varianti prima di applicare il regex
- **Cross-write**: combina il contenuto esistente su disco con il nuovo per rilevare pattern suddivisi tra scritture
- **Proxy API**: intercetta tutti i prompt in uscita e maschera le entità automaticamente
- **NER bilingue**: analisi combinata in spagnolo e inglese, con deny-list per progetto
- **Anti-injection**: tripla difesa nel classificatore locale (delimitatori, sandwich, validazione rigorosa)

---

## Documentazione tecnica (EN, per il comitato di sicurezza)

- `docs/data-sovereignty-architecture.md` — Architettura tecnica
- `docs/data-sovereignty-operations.md` — Compliance e rischio
- `docs/data-sovereignty-auditability.md` — Guida all'audit
- `docs/data-sovereignty-finetune-plan.md` — Piano del modello fine-tuned

---

## Requisiti

- Ollama installato (`ollama --version`)
- Modello scaricato (`ollama pull qwen2.5:7b`)
- jq installato (per il parsing JSON)
- Python 3.12+ (per masking e NER)
- Presidio (`pip install presidio-analyzer`) — per il Livello 1.5 NER
- spaCy modello italiano (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM minimo (16+ raccomandati)


---

## Installazione rapida

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

L'installer:
1. Verifica le dipendenze (python3, jq, ollama, presidio, spacy)
2. Scarica i modelli necessari (qwen2.5:7b, es_core_news_md)
3. Genera il token di autenticazione (`~/.savia/shield-token`)
4. Avvia `savia-shield-daemon.py` su localhost:8444 (scan/mask/unmask)
5. Avvia `savia-shield-proxy.py` su localhost:8443 (proxy API)
6. Avvia `shield-ner-daemon.py` (NER persistente in RAM)

Dopo l'esecuzione, tutta la comunicazione con l'API passa attraverso il proxy
che maschera automaticamente le entità sensibili.

**Senza daemon:** gli hook di gate e audit continuano a funzionare in
modalità fallback (regex + NFKC + base64 + cross-write). Claude Code
non si blocca mai per mancanza del daemon.
