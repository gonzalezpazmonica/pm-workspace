<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Italiano** | [Spagnolo](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Catala](README.ca.md) | [Francais](README.fr.md) | [Deutsch](README.de.md) | [Portugues](README.pt.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Il tuo team di sviluppo merita una PM che non dorme mai

Gli sprint vanno fuori controllo. Il backlog cresce senza priorita. I report per la direzione si fanno a mano. Il debito tecnico si accumula senza che nessuno lo misuri. Gli agenti IA generano codice senza spec ne test.

**pm-workspace** risolve questo. E una PM completa che vive dentro Claude Code: gestisce sprint, decompone il backlog, coordina agenti di codice con spec eseguibili, genera report per la direzione e monitora il debito tecnico — nella lingua che usi, con i dati protetti sulla tua macchina.

---

## Inizia in 3 minuti

```bash
# 1. Installa
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Apri Claude Code nella directory
cd pm-workspace && claude

# 3. Savia ti saluta e ti chiede il nome. Poi:
/sprint-status          # ← il tuo primo comando
```

Savia si adatta a te. Se sei PM, ti mostra sprint e capacita. Se sei developer, il tuo backlog e le spec. Se sei CEO, portfolio e metriche DORA.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Quali problemi risolve

| Problema | Senza pm-workspace | Con pm-workspace |
|---|---|---|
| Stato dello sprint | Aprire Azure DevOps, filtrare, calcolare | `/sprint-status` → dashboard completa |
| Report per la direzione | 2h in Excel/PowerPoint | `/ceo-report` → generato con dati reali |
| Implementare feature | Chiedere al dev di interpretare il ticket | `/spec-generate` → spec eseguibile → agente implementa → test → PR |
| Debito tecnico | "Lo sistemeremo poi" | `/debt-analyze` → prioritizzato per impatto |
| Code review | Revisionare a mano 300 righe | `/pr-review` → 3 prospettive (sicurezza, architettura, business) |
| Onboarding nuovo dev | 2 settimane a leggere codice | `/onboard` → guida personalizzata + buddy IA |

---

## Ciao, sono Savia 🦉

Sono la civettina che vive dentro pm-workspace. Mi adatto al tuo ruolo, alla tua lingua e al tuo modo di lavorare. Funziono con Azure DevOps, Jira, o 100% Git-native con Savia Flow.

**Quick-start per ruolo:**

| Ruolo | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Cosa c'e dentro

**508 comandi · 48 agenti · 89 skill · 49 hook · 16 linguaggi · 125 suite di test**

### Gestione progetti
Sprint, burndown, capacita, daily, retro, KPI. Report in Excel e PowerPoint. Previsione con Monte Carlo. Fatturazione e costi.

### Sviluppo con spec eseguibili (SDD)
I task diventano spec. Gli agenti implementano in 16 linguaggi (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) in worktree isolati. Code review automatica + revisione umana obbligatoria.

### Sicurezza
SAST contro OWASP Top 10, pipeline Red/Blue/Auditor, pentesting dinamico, SBOM, compliance in 12 settori. Savia Shield: classificazione locale dei dati con LLM on-premise, mascheramento reversibile, firma crittografica dei PR. Emergency Watchdog: fallback automatico a LLM locale (Gemma 4 / Qwen) se cade internet.

### Memoria persistente
Testo semplice (JSONL). Entity recall, ricerca semantica, continuita tra sessioni. Estrazione automatica delle decisioni prima della compattazione. Personal Vault cifrato AES-256.

### Accessibilita
Lavoro guidato per persone con disabilita (visiva, motoria, ADHD, autismo, dislessia). Micro-task, rilevamento blocchi, riformulazione adattiva.

### Intelligenza del codice
Rilevamento architettura (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness function. Human Code Maps (.hcm) che riducono il debito cognitivo.

### Modalita autonome
Sprint notturno, miglioramento codice, ricerca tecnica. Gli agenti propongono su branch `agent/*` con PR Draft — l'umano decide sempre.

### Estensioni
[Savia Mobile](projects/savia-mobile-android/README.md) (Android nativo) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboard) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + voce full-duplex)

---

## Struttura

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 508 comandi
│   ├── agents/         ← 48 agenti specializzati
│   ├── skills/         ← 89 skill di dominio
│   ├── hooks/          ← 49 hook deterministici
│   └── rules/          ← regole di contesto e linguaggio
├── docs/               ← guide per ruolo, scenario, settore
├── projects/           ← progetti (git-ignorati per privacy)
├── scripts/            ← validazione, CI, utilita
├── zeroclaw/           ← hardware ESP32 + voce
└── CLAUDE.md           ← identita e regole fondamentali
```

---

## Documentazione

| Sezione | Descrizione |
|---|---|
| [Guida introduttiva](docs/getting-started.md) | Da zero a produttivo |
| [Flusso dati](docs/data-flow-guide-es.md) | Come si collegano le parti |
| [Riservatezza](docs/confidentiality-levels.md) | 5 livelli (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Sovranita dei dati |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Comandi e agenti](docs/readme/12-comandos-agentes.md) | Riferimento completo |
| [Guide per scenario](docs/guides/README.md) | Azure, Jira, startup, sanita... |
| [Adozione](docs/ADOPTION_GUIDE.md) | Passo a passo per societa di consulenza |

---

## Principi

1. **Il testo semplice e la verita** — .md e .jsonl. Se l'IA sparisce, i dati restano leggibili
2. **Privacy assoluta** — i dati dell'utente non lasciano mai la sua macchina
3. **L'umano decide** — l'IA propone, mai merge ne deploy autonomo
4. **Apache 2.0 / MIT** — nessun vendor lock-in, nessuna telemetria

---

## Contribuire

Leggi [CONTRIBUTING.md](CONTRIBUTING.md) e [SECURITY.md](SECURITY.md). PR benvenute.

## Licenza

[MIT](LICENSE) — Creato da [Monica Gonzalez Paz](https://github.com/gonzalezpazmonica)
