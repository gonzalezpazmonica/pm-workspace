# Strategia AST di Savia — Comprensione e Qualità del Codice

> Documento tecnico: come Savia utilizza gli Alberi Sintatici Astratti per comprendere il codice legacy
> e garantire la qualità del codice generato dai suoi agenti.

---

## Il problema risolto

Gli agenti IA generano codice ad alta velocità. Senza validazione strutturale, quel codice può:
- Introdurre pattern async bloccanti che falliscono in produzione
- Creare query N+1 che degradano le prestazioni al 10 % sotto carico reale
- Silenziare eccezioni in blocchi `catch {}` vuoti che nascondono errori critici
- Modificare un file di 300 righe senza comprenderne le dipendenze interne

Savia risolve entrambi i problemi con la stessa tecnologia: AST.

---

## Architettura quadrupla: quattro scopi, un albero

```
Codice sorgente
     │
     ▼
Albero Sintattico Astratto (AST)
     │
     ├──► Comprensione (PRIMA di modificare)          ← hook PreToolUse
     │         Comprende ciò che già esiste
     │         Non modifica nulla
     │         Iniezione di contesto pre-modifica
     │
     ├──► Qualità (DOPO la generazione)               ← hook PostToolUse async
     │         Valida ciò che è appena stato scritto
     │         12 Quality Gate universali
     │         Report con score 0-100
     │
     ├──► Mappe di codice (.acm)                      ← Contesto persistente tra sessioni
     │         Pre-generato prima della sessione
     │         Massimo 150 righe per file .acm
     │         Caricamento progressivo con @include
     │
     └──► Mappe umane (.hcm)                          ← Lotta attiva contro il debito cognitivo
               Narrativa in linguaggio naturale
               Validate da umani, non da CI
               Perché il codice esiste, non solo cosa fa
```

La chiave del design: lo stesso albero serve **quattro** fasi del ciclo di vita del codice,
con strumenti diversi e in momenti diversi della pipeline di hook.

---

## Parte 1 — Comprensione del codice legacy

### Il principio

Prima che un agente modifichi un file, Savia ne estrae la mappa strutturale.
L'agente riceve quella mappa nel suo contesto, come se avesse già letto il codice.

### Pipeline di estrazione (3 livelli)

```
File obiettivo
      │
      ▼
Livello 1: Tree-sitter (universale, 0 dipendenze runtime)
  • Tutti i linguaggi del Language Pack
  • Classi, funzioni, metodi, enum
  • Dichiarazioni di importazione
  • ~1-3s, 95 % di copertura semantica

      │ (se non disponibile)
      ▼
Livello 2: Strumento semantico nativo del linguaggio
  • Python: ast.walk() (modulo built-in, 100 % precisione)
  • TypeScript: ts-morph (Compiler API completa)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, 100 % di copertura semantica

      │ (se non disponibile)
      ▼
Livello 3: Grep-strutturale (0 dipendenze assolute)
  • Regex universale per 16 linguaggi
  • Estrae classi, funzioni, import per pattern
  • <500ms, ~70 % di copertura semantica
  • Sempre disponibile — non fallisce mai
```

**Regola di degradazione garantita**: se tutti gli strumenti avanzati falliscono,
Grep-strutturale funziona sempre. Nessuna modifica viene mai bloccata per mancanza di strumenti.

### Trigger automatico: hook PreToolUse

```
L'utente chiede di modificare un file
         │
         ▼
Hook: ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Legge file_path dall'input JSON dell'hook
  • Verifica: il file ha ≥50 righe?
  • Se sì: esegue ast-comprehend.sh --surface-only (timeout 15s)
  • Estrae: classi, funzioni, complessità ciclomatica
  • Se complessità > 15: emette avviso visibile
         │
         ▼
L'agente riceve nel suo contesto:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  File: src/Services/AuthService.cs
  Righe: 248  |  Classi: 1  |  Funzioni: 12
  Complessità: 42 punti di decisione  ⚠️  Procedere con cautela

  Mappa strutturale:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
L'agente modifica con il contesto completo del file
```

L'hook è **non-asincrono** perché deve completarsi PRIMA che l'agente modifichi.
L'hook esegue sempre `exit 0` — la comprensione è consultiva, non blocca mai.

---

## Parte 2 — Qualità del codice generato

### I 12 Quality Gate universali

| Gate | Nome | Classificazione | Linguaggi |
|------|------|-----------------|-----------|
| QG-01 | Async/concorrenza bloccante | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | Query N+1 | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference senza guard | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Magic number senza costante | WARNING | Tutti i linguaggi |
| QG-05 | Catch vuoto / eccezioni inghiottite | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Complessità ciclomatica >15 | WARNING | Tutti i linguaggi |
| QG-07 | Metodi >50 righe | INFO | Tutti i linguaggi |
| QG-08 | Duplicazione >15 % | WARNING | Tutti i linguaggi |
| QG-09 | Segreti hardcoded | BLOCKER | Tutti i linguaggi |
| QG-10 | Logging eccessivo in produzione | INFO | Tutti i linguaggi |
| QG-11 | Codice morto / dead code | INFO | Tutti i linguaggi |
| QG-12 | Logica di business senza test | BLOCKER | Tutti i linguaggi |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Trigger automatico: hook PostToolUse asincrono

```
L'agente scrive/modifica un file
         │
         ▼
Hook: ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • Esegue in background — non blocca l'agente
  • Rileva il linguaggio dall'estensione
  • Esegue ast-quality-gate.sh con il file
  • Calcola score (0-100) e voto (A-F)
  • Se score < 60 (voto D o F): emette allarme visibile
  • Salva il report in output/ast-quality/
```

---

## Parte 3 — Mappe di codice per agenti (.acm)

### Il problema

Ogni sessione dell'agente riparte da zero. Senza contesto pre-generato, l'agente
consuma il 30–60 % della sua finestra di contesto esplorando l'architettura prima
di scrivere una singola riga di codice.

Le Agent Code Maps (.acm) sono mappe strutturali persistenti tra sessioni,
memorizzate in `.agent-maps/` e ottimizzate per il consumo diretto dagli agenti.

```
.agent-maps/
├── INDEX.acm              ← Punto di ingresso per la navigazione
├── domain/
│   ├── entities.acm       ← Entità di dominio
│   └── services.acm       ← Servizi di business
├── infrastructure/
│   └── repositories.acm   ← Repository e accesso ai dati
└── api/
    └── controllers.acm    ← Controller ed endpoint
```

**Limite di 150 righe per .acm**: se cresce, viene suddiviso automaticamente.
**Sistema @include**: caricamento progressivo su richiesta — l'agente carica solo ciò che serve.

### Modello di freschezza

| Stato | Condizione | Azione dell'agente |
|-------|------------|-------------------|
| `fresco` | Hash .acm corrisponde al codice sorgente | Usare direttamente |
| `obsoleto` | Modifiche interne, struttura intatta | Usare con avviso |
| `rotto` | File eliminati o firme pubbliche cambiate | Rigenerare prima di usare |

### Integrazione nella pipeline SDD

I file .acm vengono caricati PRIMA di `/spec:generate`. L'agente conosce la vera
architettura del progetto dal primo token, senza esplorazione alla cieca.

```
[0] CARICA — /codemap:check && /codemap:load <scope>
[1-5] Pipeline SDD invariata
[post-SDD] AGGIORNA — /codemap:refresh --incremental
```

---

## Parte 4 — Mappe di codice umane (.hcm)

### Il problema

Gli sviluppatori trascorrono il 58 % del tempo a leggere codice e solo il 42 % a scriverlo
(Addy Osmani, 2024). Quel 58 % si moltiplica nelle aree con **debito cognitivo**: sottosistemi
che qualcuno deve re-imparare ogni volta che li tocca perché non esiste una mappa narrativa
che pre-digesta il percorso mentale.

I file `.hcm` combattono attivamente il debito cognitivo: sono il gemello umano
dei `.acm`. Mentre `.acm` dice a un agente "cosa esiste e dove", `.hcm` dice
a uno sviluppatore "perché esiste e come pensarlo".

### Formato .hcm

```markdown
# {Componente} — Mappa umana (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{componente}.acm

## La storia (1 paragrafo)
Quale problema risolve, in linguaggio umano.

## Il modello mentale
Come pensare a questo componente. Analogie se aiutano.

## Punti di ingresso (compito → da dove iniziare)
- Per aggiungere X → inizia in {file}:{sezione}
- Se Y fallisce → il punto di ingresso è {hook/script}

## Gotchas (comportamenti non ovvi)
- Ciò che sorprende gli sviluppatori che arrivano nuovi
- Le trappole documentate di questo sottosistema

## Perché è costruito così
- Decisioni di design con la loro motivazione
- Compromessi accettati consapevolmente

## Indicatori di debito
- Aree note di confusione o refactor in attesa
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Mappa fresca
4-6: Rivedere presto
7-10: Debito attivo — sta costando denaro ora
```

### Posizione per progetto

Ogni progetto gestisce le proprie mappe all'interno della sua cartella:

```
projects/{progetto}/
├── CLAUDE.md
├── .human-maps/               ← Mappe narrative per sviluppatori
│   ├── {progetto}.hcm         ← Mappa generale del progetto
│   └── _archived/             ← Componenti eliminati o uniti
└── .agent-maps/               ← Mappe strutturali per agenti
    ├── {progetto}.acm
    └── INDEX.acm
```

### Ciclo di vita

```
Creazione (/codemap:generate-human) → Validazione umana → Attivo
         ↓ modifiche al codice
      .acm rigenerato → .hcm marcato come obsoleto → Aggiornamento (/codemap:walk)
```

**Regola immutabile:** Un `.hcm` non può mai avere `last-walk` più recente del suo `.acm`.
Se il `.acm` è obsoleto, lo è anche il `.hcm`, indipendentemente dalla propria data.

### Comandi

```bash
# Generare la bozza .hcm da .acm + codice
/codemap:generate-human projects/il-mio-progetto/

# Sessione guidata di ri-lettura (aggiornamento)
/codemap:walk il-mio-modulo

# Mostrare i debt-score di tutti i .hcm del progetto
/codemap:debt-report

# Forzare l'aggiornamento del .hcm indicato
/codemap:refresh-human projects/il-mio-progetto/.human-maps/il-mio-modulo.hcm
```

---

## Garanzie del sistema

1. **Non blocca mai una modifica**: RN-COMP-02 — se la comprensione fallisce, sempre exit 0
2. **Non distrugge mai il codice**: RN-COMP-02 — la comprensione è di sola lettura
3. **Ha sempre un fallback**: RN-COMP-05 — Grep-strutturale garantisce copertura minima
4. **Criteri agnostici**: i 12 QG si applicano allo stesso modo a tutti i linguaggi
5. **Schema unificato**: tutti gli output sono comparabili tra linguaggi

---

## Riferimenti

- Skill comprensione: `.claude/skills/ast-comprehension/SKILL.md`
- Skill qualità: `.claude/skills/ast-quality-gate/SKILL.md`
- Hook comprensione: `.claude/hooks/ast-comprehend-hook.sh`
- Hook qualità: `.claude/hooks/ast-quality-gate-hook.sh`
- Script comprensione: `scripts/ast-comprehend.sh`
- Script qualità: `scripts/ast-quality-gate.sh`
- Skill mappe di codice: `.claude/skills/agent-code-map/SKILL.md`
- Regola mappe umane: `.claude/rules/domain/hcm-maps.md`
- Skill mappe umane: `.claude/skills/human-code-map/SKILL.md`
- Mappe del workspace: `.human-maps/`
- Mappe di progetto: `projects/*/.human-maps/*.hcm`
