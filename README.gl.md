<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Galego | [Castellano](README.md) | [English](README.en.md) | [Euskara](README.eu.md) | [Catalá](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Ola, son Savia

Son Savia, a mouchiña que vive dentro de pm-workspace. O meu traballo é que os teus proxectos flúan: xestiono sprints, descompoño backlog, coordino axentes de código, levo a facturación, xero informes para dirección e vixío a débeda técnica — todo dende Claude Code, na lingua que uses.

Funciono con Azure DevOps, Jira, ou 100% Git-native con Savia Flow. Cando chegas por primeira vez, preséntome e coñézote. Adáptome a ti, non ao revés.

---

## Quen es?

| Rol | Que fago por ti |
|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacidade, informes |
| **Tech Lead** | Arquitectura, débeda técnica, tech radar, PRs |
| **Developer** | Specs, implementación, tests, o meu sprint |
| **QA** | Testplan, cobertura, regresión, quality gates |
| **Product Owner** | KPIs, backlog, feature impact, stakeholders |
| **CEO / CTO** | Portfolio, DORA, gobernanza, exposición IA |

---

## Como funciono por dentro

Son un workspace de Claude Code con 497 comandos, 46 axentes e 82 skills. A miña arquitectura é **Command > Agent > Skills**: o usuario invoca un comando, o comando delega nun axente especializado, e o axente usa skills de coñecemento reutilizábeis.

A miña memoria persiste en texto plano (JSONL) con indexación vectorial opcional para busca semántica. Non envío datos a ningún servidor — **cero telemetría**. Todo se executa localmente.

Para sacar o máximo partido de min:
1. **Explora antes de implementar** — `/plan` para pensar, despois implementar
2. **Dame forma de verificar** — tests, builds, capturas de pantalla
3. **Un obxectivo por sesión** — `/clear` entre tarefas diferentes
4. **Compacta frecuentemente** — `/compact` ao 50% de contexto

---
Como funciona por dentro en detalle: **[O meu Sistema de Memoria](docs/memory-architecture.md)**

## Privacidade e Telemetría

**Cero telemetría.** pm-workspace non envía datos a ningún servidor. Non hai analytics, non hai tracking, non hai phone-home. Todo se executa localmente. Offline-first por deseño.

---


> **[Savia Shield](docs/savia-shield.gl.md)** — Sistema de soberania de datos. Clasificacion local con LLM, enmascaramento reversible, auditoria completa.

## Instalación

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia preséntase automáticamente
```

Documentación completa: [README.md](README.md) (castelán) | [README.en.md](README.en.md) (inglés)

> *Savia — a túa PM automatizada con IA. Compatíbel con Azure DevOps, Jira e Savia Flow.*
