<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Deutsch | [Castellano](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Hallo, ich bin Savia

Ich bin Savia, die kleine Eule, die in pm-workspace lebt. Meine Aufgabe ist es, eure Projekte zum Fliessen zu bringen: Ich verwalte Sprints, zerlege den Backlog, koordiniere Code-Agenten, kuemmere mich um die Abrechnung, erstelle Berichte fuer die Geschaeftsleitung und ueberwache technische Schulden — alles aus Claude Code heraus, in der Sprache, die ihr verwendet.

Ich funktioniere mit Azure DevOps, Jira, oder 100% Git-native mit Savia Flow. Wenn ihr zum ersten Mal kommt, stelle ich mich vor und lerne euch kennen. Ich passe mich an euch an, nicht umgekehrt.

---

## Wer bist du?

| Rolle | Was ich fuer dich tue |
|---|---|
| **PM / Scrum Master** | Sprints, Dailies, Kapazitaet, Berichte |
| **Tech Lead** | Architektur, technische Schulden, Tech Radar, PRs |
| **Developer** | Specs, Implementierung, Tests, mein Sprint |
| **QA** | Testplan, Abdeckung, Regression, Quality Gates |
| **Product Owner** | KPIs, Backlog, Feature Impact, Stakeholder |
| **CEO / CTO** | Portfolio, DORA, Governance, KI-Exposition |

**Zum ersten Mal hier?** Lies die [Erste-Schritte-Anleitung](docs/getting-started.de.md) — von Null auf produktiv in 15 Minuten. Fuer den Schutz von Kundendaten: [Savia Shield Anleitung](docs/savia-shield-guide.de.md).

---

## Wie ich von innen funktioniere

Ich bin ein Claude Code Workspace mit 505 Befehlen, 49 Agenten und 85 Skills. Meine Architektur ist **Command > Agent > Skills**: Der Benutzer ruft einen Befehl auf, der Befehl delegiert an einen spezialisierten Agenten, und der Agent nutzt wiederverwendbare Wissens-Skills.

Mein Gedaechtnis wird in Klartext (JSONL) gespeichert, mit optionaler Vektor-Indexierung fuer semantische Suche. Ich sende keine Daten an irgendeinen Server — **null Telemetrie**. Alles wird lokal ausgefuehrt.

Um das Beste aus mir herauszuholen:
1. **Erkunden vor dem Implementieren** — `/plan` zum Nachdenken, dann implementieren
2. **Gib mir eine Moeglichkeit zu verifizieren** — Tests, Builds, Screenshots
3. **Ein Ziel pro Sitzung** — `/clear` zwischen verschiedenen Aufgaben
4. **Regelmaessig komprimieren** — `/compact` bei 50% Kontext

---
So funktioniert es im Detail: **[Mein Gedachtnissystem](docs/memory-architecture.md)**

## Datenschutz und Telemetrie

**Null Telemetrie.** pm-workspace sendet keine Daten an irgendeinen Server. Keine Analytics, kein Tracking, kein Phone-Home. Alles wird lokal ausgefuehrt. Offline-first by Design.

---


> **[AST-Strategie](docs/ast-strategy.de.md)** — Verständnis von Legacy-Code + 12 universelle Quality Gates. Duale AST-Architektur: Verständnis vor der Bearbeitung und Validierung nach der Generierung. **Human Code Maps (.hcm)** — narrative Karten in natürlicher Sprache, die den ersten Durchgang durch ein Subsystem vorverdauen. Jedes Projekt trägt seine Karten in `.human-maps/` innerhalb seines eigenen Ordners. Befehle: `/codemap:generate-human`, `/codemap:walk`, `/codemap:debt-report`. Aktiver Kampf gegen kognitive Schulden: Entwickler verbringen 58% ihrer Zeit damit, Code zu lesen; diese Karten reduzieren diesen Aufwand von Sitzung zu Sitzung.
> **[Savia Shield](docs/savia-shield.de.md)** — Datensouveranitatssystem. Lokale Klassifizierung mit LLM, reversible Maskierung, vollstandiges Audit.
> **Era 164** — Adaptive Qualitaet: Responsibility Judge (deterministischer Hook, 7 Muster), Trace-to-Prompt-Optimierung, Instinktkollaps-Erkennung, Anforderungs-Pushback, Dev-Session-Discard, risikobasierte Review-Tiefe, Reaction Engine, 13-Zustands-State-Machine, rekursive Aufgabenzerlegung.

## Installation

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia stellt sich automatisch vor
```

Vollstaendige Dokumentation: [README.md](README.md) (Spanisch) | [README.en.md](README.en.md) (Englisch)

> *Savia — deine KI-automatisierte PM. Kompatibel mit Azure DevOps, Jira und Savia Flow.*
