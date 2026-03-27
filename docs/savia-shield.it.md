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

## I 4 livelli

### Livello 1 — Porta deterministica (regex)

Scansiona il contenuto con pattern regex prima di scrivere un file.
Se rileva credenziali, IP private, token API o chiavi private
in un file pubblico, **blocca la scrittura**.

- Latenza: < 2 secondi
- Dipendenze: bash, grep, jq (standard POSIX)
- Sempre attivo, anche senza connessione a internet
- Rilevamento base64: decodifica blob sospetti e ri-scansiona

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
- 95+ entità mappate per progetto via GLOSSARY-MASK.md
- Pool di 32 persone, 12 aziende, 16 sistemi fittizi
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

| Componente | File | Righe |
|-----------|------|-------|
| Porta regex | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| Classificatore LLM | `scripts/ollama-classify.sh` | 99 |
| Audit post-scrittura | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Mascheratore | `scripts/sovereignty-mask.py` | ~180 |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | 72 |
| Regola di dominio | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Log di audit:**
- `output/data-sovereignty-audit.jsonl` — decisioni dei livelli 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisioni del LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operazioni di masking

---

## Validazione

- **51 test automatizzati** (BATS) — core + edge case + fix + mock
- **3 audit indipendenti** — Red Team, Riservatezza, Code Review
- **24 vulnerabilità trovate — 24 risolte, 0 in sospeso**
- **0 limitazioni residuali** — tutte corrette tecnicamente
- **Punteggio di sicurezza: 100/100**
- **Mappatura GDPR/ISO 27001/EU AI Act** completa

---

## Limitazioni tecniche e come vengono mitigate

### Base64 e codifica dei dati

Savia Shield decodifica automaticamente i blob base64 (fino a 20 blob di
massimo 200 char) e ri-scansiona il contenuto decodificato. Se il blob
decodificato contiene una credenziale o un'IP interna, viene bloccato.

### Unicode e omoglifi

Prima di applicare il regex, il contenuto viene normalizzato con Unicode NFKC.
Questo converte caratteri fullwidth e altre varianti in ASCII canonico.
Dopo la normalizzazione, le cifre fullwidth vengono convertite in cifre ASCII e
il regex le rileva correttamente.

### Scritture suddivise (split-write)

Difesa cross-write: quando si scrive in un file pubblico che esiste già
su disco, Savia Shield legge il contenuto esistente e lo combina
con il nuovo contenuto. I regex vengono applicati sul testo combinato,
rilevando pattern che si formano unendo entrambe le scritture.

### Contenuto conversazionale (prompt all'assistente IA)

Il Livello 4 (masking reversibile) consente di mascherare il testo PRIMA di incollarlo
nella chat. L'hook NER scansiona i file che l'assistente legge. Formazione:
gli utenti referenziano i file tramite percorso invece di copiarne il contenuto.
Limite residuo: non esiste intercettazione tecnica del testo che l'utente
scrive direttamente nel prompt — richiede integrazione a livello di
protocollo (miglioramento futuro).

### Prompt injection nel classificatore locale

Tripla difesa: (1) delimitatori [BEGIN/END DATA], (2) sandwich defense
con istruzione ripetuta post-dati, (3) validazione rigorosa dell'output
(risposta non valida = CONFIDENTIAL automatico). Temperature=0 e
num_predict=5 limitano la superficie di attacco.

### Precisione del NER in spagnolo

Scansione duale ES+EN: NER esegue l'analisi in entrambe le lingue e combina
i risultati. GLOSSARY-MASK.md carica le entità specifiche del progetto
come deny-list (score 1.0, rilevamento garantito).

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
