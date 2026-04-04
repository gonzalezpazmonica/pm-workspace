<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Deutsch** | [Spanisch](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Catala](README.ca.md) | [Francais](README.fr.md) | [Portugues](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Euer Entwicklungsteam verdient eine PM, die nie schlaeft

Sprints geraten ausser Kontrolle. Das Backlog waechst ohne Priorisierung. Berichte fuer die Geschaeftsleitung werden von Hand erstellt. Technische Schulden haeufen sich ungemessen an. KI-Agenten generieren Code ohne Specs und ohne Tests.

**pm-workspace** loest das. Es ist eine vollstaendige PM, die in Claude Code lebt: verwaltet Sprints, zerlegt Backlogs, koordiniert Code-Agenten mit ausfuehrbaren Specs, erstellt Berichte fuer die Geschaeftsleitung und ueberwacht technische Schulden — in eurer Sprache, mit euren Daten geschuetzt auf eurem Rechner.

---

## In 3 Minuten starten

```bash
# 1. Installieren
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Claude Code im Verzeichnis oeffnen
cd pm-workspace && claude

# 3. Savia begruesst dich und fragt nach deinem Namen. Dann:
/sprint-status          # ← dein erster Befehl
```

Savia passt sich an dich an. Fuer PMs zeigt sie Sprints und Kapazitaet. Fuer Entwickler Backlog und Specs. Fuer CEOs Portfolio und DORA-Metriken.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Welche Probleme es loest

| Problem | Ohne pm-workspace | Mit pm-workspace |
|---|---|---|
| Sprint-Status | Azure DevOps oeffnen, filtern, berechnen | `/sprint-status` → vollstaendiges Dashboard |
| Bericht fuer Geschaeftsleitung | 2h in Excel/PowerPoint | `/ceo-report` → mit echten Daten generiert |
| Feature implementieren | Dev interpretiert das Ticket | `/spec-generate` → ausfuehrbare Spec → Agent implementiert → Tests → PR |
| Technische Schulden | "Beheben wir spaeter" | `/debt-analyze` → nach Auswirkung priorisiert |
| Code Review | 300 Zeilen manuell pruefen | `/pr-review` → 3 Perspektiven (Sicherheit, Architektur, Business) |
| Onboarding neuer Dev | 2 Wochen Code lesen | `/onboard` → personalisierte Anleitung + KI-Buddy |

---

## Hallo, ich bin Savia 🦉

Ich bin die kleine Eule, die in pm-workspace lebt. Ich passe mich an deine Rolle, deine Sprache und deine Arbeitsweise an. Ich arbeite mit Azure DevOps, Jira oder 100% Git-native mit Savia Flow.

**Quick-Starts nach Rolle:**

| Rolle | Quick-Start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Was drin steckt

**508 Befehle · 48 Agenten · 89 Skills · 48 Hooks · 16 Sprachen · 106 Test-Suiten**

### Projektmanagement
Sprints, Burndown, Kapazitaet, Dailies, Retros, KPIs. Berichte in Excel und PowerPoint. Vorhersage mit Monte Carlo. Abrechnung und Kosten.

### Spec-Driven Development (SDD)
Aufgaben werden zu Specs. Agenten implementieren in 16 Sprachen (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) in isolierten Worktrees. Automatisches Code-Review + obligatorisches menschliches Review.

### Sicherheit
SAST gegen OWASP Top 10, Red/Blue/Auditor-Pipeline, dynamisches Pentesting, SBOM, Compliance in 12 Sektoren. Savia Shield: lokale Datenklassifizierung mit On-Premise-LLM, reversible Maskierung, kryptographische PR-Signierung. Emergency Watchdog: automatischer Fallback auf lokales LLM (Gemma 4 / Qwen) bei Internetausfall.

### Persistenter Speicher
Klartext (JSONL). Entity Recall, semantische Suche, sitzungsuebergreifende Kontinuitaet. Automatische Entscheidungsextraktion vor Komprimierung. AES-256-verschluesselter Personal Vault.

### Barrierefreiheit
Gefuehrtes Arbeiten fuer Menschen mit Behinderung (visuell, motorisch, ADHS, Autismus, Dyslexie). Micro-Tasks, Blockadeerkennung, adaptive Umformulierung.

### Code-Intelligenz
Architekturerkennung (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness Functions. Human Code Maps (.hcm) zur Reduzierung kognitiver Schulden.

### Autonome Modi
Nacht-Sprint, Code-Verbesserung, technische Forschung. Agenten schlagen auf `agent/*`-Branches mit Draft-PRs vor — der Mensch entscheidet immer.

### Erweiterungen
[Savia Mobile](projects/savia-mobile-android/README.md) (natives Android) · [Savia Web](projects/savia-web/README.md) (Vue.js Dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + Full-Duplex-Sprache)

---

## Struktur

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 508 Befehle
│   ├── agents/         ← 48 spezialisierte Agenten
│   ├── skills/         ← 89 Domaenen-Skills
│   ├── hooks/          ← 48 deterministische Hooks
│   └── rules/          ← Kontext- und Sprachregeln
├── docs/               ← Anleitungen nach Rolle, Szenario, Sektor
├── projects/           ← Projekte (git-ignoriert fuer Datenschutz)
├── scripts/            ← Validierung, CI, Werkzeuge
├── zeroclaw/           ← ESP32-Hardware + Sprache
└── CLAUDE.md           ← Identitaet und Grundregeln
```

---

## Dokumentation

| Abschnitt | Beschreibung |
|---|---|
| [Erste Schritte](docs/getting-started.md) | Von Null auf produktiv |
| [Datenfluss](docs/data-flow-guide-es.md) | Wie die Teile verbunden sind |
| [Vertraulichkeit](docs/confidentiality-levels.md) | 5 Stufen (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Datensouveraenitaet |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Befehle und Agenten](docs/readme/12-comandos-agentes.md) | Vollstaendige Referenz |
| [Szenario-Anleitungen](docs/guides/README.md) | Azure, Jira, Startup, Gesundheit... |
| [Einfuehrung](docs/ADOPTION_GUIDE.md) | Schritt fuer Schritt fuer Beratungen |

---

## Prinzipien

1. **Klartext ist Wahrheit** — .md und .jsonl. Wenn die KI weg ist, bleiben die Daten lesbar
2. **Absoluter Datenschutz** — Benutzerdaten verlassen nie den Rechner
3. **Der Mensch entscheidet** — KI schlaegt vor, nie autonomer Merge oder Deploy
4. **Apache 2.0 / MIT** — kein Vendor Lock-in, keine Telemetrie

---

## Beitragen

Lies [CONTRIBUTING.md](CONTRIBUTING.md) und [SECURITY.md](SECURITY.md). PRs willkommen.

## Lizenz

[MIT](LICENSE) — Erstellt von [Monica Gonzalez Paz](https://github.com/gonzalezpazmonica)
