<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

Galego | [Castellano](README.md) | [English](README.en.md) | [Euskara](README.eu.md) | [Catala](README.ca.md) | [Francais](README.fr.md) | [Deutsch](README.de.md) | [Portugues](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Ola, son Savia

Son Savia, a bufetixa que vive dentro de pm-workspace. O meu traballo e que os teus proxectos fluan: xestiono sprints, descompono backlog, coordino axentes de codigo, levo a facturacion, xero informes para direccion e vixio a debeda tecnica — todo dende Claude Code, na lingua que uses.

Funciono con Azure DevOps, Jira, ou 100% Git-native con Savia Flow. Cando chegas por primeira vez, presentome e conezote. Adaptome a ti, non ao reves.

---

## Quen es?

| Rol | Que fago por ti |
|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacidade, informes |
| **Tech Lead** | Arquitectura, debeda tecnica, tech radar, PRs |
| **Developer** | Specs, implementacion, tests, o meu sprint |
| **QA** | Testplan, cobertura, regresion, quality gates |
| **Product Owner** | KPIs, backlog, feature impact, stakeholders |
| **CEO / CTO** | Portfolio, DORA, gobernanza, exposicion IA |

---

## Como funciono por dentro

Son un workspace de Claude Code con 496 comandos, 46 axentes e 82 skills. A mina arquitectura e **Command > Agent > Skills**: o usuario invoca un comando, o comando delega nun axente especializado, e o axente usa skills de coñecemento reutilizables.

A mina memoria persiste en texto plano (JSONL) con indexacion vectorial opcional para busqueda semantica. Non envio datos a ningun servidor — **cero telemetria**. Todo se executa localmente.

Para sacar o maximo partido de min:
1. **Explora antes de implementar** — `/plan` para pensar, despois implementar
2. **Dame forma de verificar** — tests, builds, screenshots
3. **Un obxectivo por sesion** — `/clear` entre tarefas diferentes
4. **Compacta frecuentemente** — `/compact` ao 50% de contexto

---

## Privacidade e Telemetria

**Cero telemetria.** pm-workspace non envia datos a ningun servidor. Non hai analytics, non hai tracking, non hai phone-home. Todo se executa localmente. Offline-first por deseño.

---

## Instalacion

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
claude  # Savia presentase automaticamente
```

Documentacion completa: [README.md](README.md) (castellano) | [README.en.md](README.en.md) (ingles)

> *Savia — a tua PM automatizada con IA. Compatible con Azure DevOps, Jira e Savia Flow.*
