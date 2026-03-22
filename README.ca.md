<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Catala | [Castellano](README.md) | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Francais](README.fr.md) | [Deutsch](README.de.md) | [Portugues](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Hola, soc Savia

Soc Savia, la mussola que viu dins de pm-workspace. La meva feina es que els teus projectes flueixin: gestiono sprints, descomposo backlog, coordino agents de codi, porto la facturacio, genero informes per a direccio i vigilo el deute tecnic — tot des de Claude Code, en l'idioma que facis servir.

Funciono amb Azure DevOps, Jira, o 100% Git-native amb Savia Flow. Quan arribes per primera vegada, em presento i et conec. M'adapto a tu, no al reves.

---

## Qui ets?

| Rol | Que faig per tu |
|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacitat, informes |
| **Tech Lead** | Arquitectura, deute tecnic, tech radar, PRs |
| **Developer** | Specs, implementacio, tests, el meu sprint |
| **QA** | Testplan, cobertura, regressio, quality gates |
| **Product Owner** | KPIs, backlog, feature impact, stakeholders |
| **CEO / CTO** | Portfolio, DORA, governanca, exposicio IA |

---

## Com funciono per dins

Soc un workspace de Claude Code amb 496 comandes, 46 agents i 82 skills. La meva arquitectura es **Command > Agent > Skills**: l'usuari invoca una comanda, la comanda delega en un agent especialitzat, i l'agent utilitza skills de coneixement reutilitzables.

La meva memoria persisteix en text pla (JSONL) amb indexacio vectorial opcional per a cerca semantica. No envio dades a cap servidor — **zero telemetria**. Tot s'executa localment.

Per treure el maxim profit de mi:
1. **Explora abans d'implementar** — `/plan` per pensar, despres implementar
2. **Dona'm manera de verificar** — tests, builds, captures de pantalla
3. **Un objectiu per sessio** — `/clear` entre tasques diferents
4. **Compacta frequentment** — `/compact` al 50% de context

---

## Privacitat i Telemetria

**Zero telemetria.** pm-workspace no envia dades a cap servidor. No hi ha analytics, no hi ha tracking, no hi ha phone-home. Tot s'executa localment. Offline-first per disseny.

---

## Installacio

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia es presenta automaticament
```

Documentacio completa: [README.md](README.md) (castella) | [README.en.md](README.en.md) (angles)

> *Savia — la teva PM automatitzada amb IA. Compatible amb Azure DevOps, Jira i Savia Flow.*
