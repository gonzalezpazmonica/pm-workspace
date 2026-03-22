<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Italiano | [Castellano](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Ciao, sono Savia

Sono Savia, la civettina che vive dentro pm-workspace. Il mio lavoro e far scorrere i tuoi progetti: gestisco gli sprint, decompongo il backlog, coordino gli agenti di codice, gestisco la fatturazione, genero report per la direzione e monitoro il debito tecnico — tutto da Claude Code, nella lingua che usi.

Funziono con Azure DevOps, Jira, o 100% Git-native con Savia Flow. Quando arrivi per la prima volta, mi presento e ti conosco. Mi adatto a te, non il contrario.

---

## Chi sei?

| Ruolo | Cosa faccio per te |
|---|---|
| **PM / Scrum Master** | Sprint, daily, capacita, report |
| **Tech Lead** | Architettura, debito tecnico, tech radar, PR |
| **Developer** | Spec, implementazione, test, il mio sprint |
| **QA** | Piano di test, copertura, regressione, quality gate |
| **Product Owner** | KPI, backlog, impatto delle feature, stakeholder |
| **CEO / CTO** | Portfolio, DORA, governance, esposizione IA |

---

## Come funziono dentro

Sono un workspace Claude Code con 496 comandi, 46 agenti e 82 skill. La mia architettura e **Command > Agent > Skills**: l'utente invoca un comando, il comando delega a un agente specializzato, e l'agente usa skill di conoscenza riutilizzabili.

La mia memoria persiste in testo semplice (JSONL) con indicizzazione vettoriale opzionale per la ricerca semantica. Non invio dati a nessun server — **zero telemetria**. Tutto viene eseguito localmente.

Per sfruttarmi al massimo:
1. **Esplora prima di implementare** — `/plan` per pensare, poi implementare
2. **Dammi un modo per verificare** — test, build, screenshot
3. **Un obiettivo per sessione** — `/clear` tra compiti diversi
4. **Compatta frequentemente** — `/compact` al 50% del contesto

---
Como funciona por dentro en detalle: **[Mi Sistema de Memoria](docs/memory-architecture.md)**

## Privacy e Telemetria

**Zero telemetria.** pm-workspace non invia dati a nessun server. Niente analytics, niente tracking, niente phone-home. Tutto viene eseguito localmente. Offline-first per design.

---

## Installazione

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia si presenta automaticamente
```

Documentazione completa: [README.md](README.md) (spagnolo) | [README.en.md](README.en.md) (inglese)

> *Savia — la tua PM automatizzata con IA. Compatibile con Azure DevOps, Jira e Savia Flow.*
