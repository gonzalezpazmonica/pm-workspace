<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

🌐 [English version](README.en.md) · **Español**

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Hola, soy Savia 🦉

Soy Savia, la buhita que vive dentro de pm-workspace. Mi trabajo es que tus proyectos fluyan: gestiono sprints, descompongo backlog, coordino agentes de código, llevo la facturación, genero informes para dirección y vigilo la deuda técnica — todo desde Claude Code, en el lenguaje que uses. Funciono con Azure DevOps, Jira, o 100% Git-native con Savia Flow. Cuando llegas por primera vez, me presento y te conozco. Me adapto a ti, no al revés.

---

## ¿Quién eres?

Según tu rol, tu experiencia conmigo será diferente. Elige tu quick-start:

| Rol | Qué hago por ti | Quick-start |
|---|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacity, reporting | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| **Tech Lead** | Arquitectura, deuda técnica, tech radar, PRs | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| **Developer** | Specs, implementación, tests, mi sprint | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| **QA** | Testplan, cobertura, regresión, quality gates | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| **Product Owner** | KPIs, backlog, feature impact, stakeholders | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| **CEO / CTO** | Portfolio, DORA, governance, AI exposure | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Cómo fluye la información

Todo en pm-workspace está conectado. Cuando tu equipo imputa horas, eso alimenta los costes; los costes generan facturas; las facturas aparecen en los informes de dirección. Nada se pierde, nada se duplica.

```
Horas (timesheet)  ──→  Costes (cost-mgmt)  ──→  Facturas  ──→  Informe CEO
       ↓                                                              ↑
Sprint items  ──→  Velocity trend  ──→  Capacity forecast  ──→  Alertas directivas
       ↓
Spec (SDD)  ──→  Agente implementa  ──→  Code review  ──→  Tests  ──→  DORA metrics
       ↓
Memoria  ──→  Entity recall  ──→  Context load  ──→  Continuidad entre sesiones
```

Más detalle en la [Guía de flujo de datos](docs/data-flow-guide-es.md).

---

## Dónde vive todo

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 360+ comandos (lo que me puedes pedir)
│   ├── agents/         ← 27 agentes especializados
│   ├── skills/         ← 38 skills con conocimiento de dominio
│   ├── hooks/          ← 14 hooks que refuerzan reglas automáticamente
│   └── rules/          ← reglas de contexto, lenguaje, dominio
├── docs/
│   ├── quick-starts/   ← guías por rol (PM, Dev, QA, PO, TL, CEO)
│   ├── readme/         ← documentación detallada (13 secciones)
│   ├── guides/         ← 13 guías por escenario (Azure, Jira, startup...)
│   └── savia-flow/     ← docs del sistema Git-native
├── scripts/            ← validación, CI, utilidades
├── output/             ← ficheros generados (informes, specs, exports)
└── CLAUDE.md           ← mi identidad y reglas fundamentales
```

Cada comando tiene frontmatter YAML con metadata (modelo, coste de contexto, descripción). Las reglas se auto-cargan por tipo de fichero o dominio. Los skills se activan por demanda.

---

## Qué puedo hacer

**Gestión de proyectos** — Sprints, burndown, capacity, KPIs, dailies, retros. Informes automáticos en Excel y PowerPoint. Predicción de completitud con Monte Carlo.

**Spec-Driven Development** — Las tasks se convierten en specs ejecutables. Implemento handlers, tests y repositorios en 16 lenguajes. Los agentes trabajan en worktrees aislados para evitar conflictos.

**Inteligencia de código** — Detecto patrones de arquitectura (Clean, Hexagonal, DDD, CQRS, Microservices), mido salud arquitectónica con fitness functions, y priorizo deuda técnica por impacto de negocio.

**Seguridad y compliance** — SAST contra OWASP Top 10, SBOM, escaneo de credenciales, compliance regulatorio en 12 sectores, y gobernanza IA con model cards y EU AI Act.

**Infraestructura** — Multi-cloud (Azure, AWS, GCP) con detección automática, tier mínimo por defecto, y escalado solo con tu aprobación. Pipelines CI/CD configurables.

**Memoria y contexto** — Memory store persistente (JSONL), entity recall para stakeholders y componentes, progressive disclosure por coste de contexto, y continuidad entre sesiones.

**Informes ejecutivos** — CEO report multi-proyecto, alertas de dirección, portfolio overview, DORA metrics, value stream mapping.

**Colaboración** — Company Savia (repo compartido con mensajería E2E cifrada), Savia Flow (PM Git-native), Travel Mode, backup cifrado, y Savia School para centros educativos. Referencia completa: [360+ comandos · 27 agentes · 38 skills](docs/readme/12-comandos-agentes.md)

---

## Instalación

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex
```

Configurable con `SAVIA_HOME`, `--skip-tests`. Detalles: `install.sh --help`

---

## Documentación

| Sección | Descripción |
|---|---|
| **Empezar** | |
| [Introducción y ejemplo](docs/readme/01-introduccion.md) | Primeros 5 minutos |
| [Estructura del workspace](docs/readme/02-estructura.md) | Directorios y organización |
| [Configuración inicial](docs/readme/03-configuracion.md) | PAT, constantes, verificación |
| [Guía de adopción](docs/ADOPTION_GUIDE.md) | Paso a paso para consultoras |
| **Uso diario** | |
| [Sprints e informes](docs/readme/04-uso-sprint-informes.md) | Sprint, reporting, KPIs |
| [Spec-Driven Development](docs/readme/05-sdd.md) | SDD: specs, agentes, patrones |
| [Flujo de datos](docs/data-flow-guide-es.md) | Cómo se conectan las partes |
| **Referencia** | |
| [Comandos y agentes](docs/readme/12-comandos-agentes.md) | 360+ comandos + 27 agentes |
| [Guías por escenario](docs/guides/README.md) | Azure, Jira, startup, sanidad... |
| [AI Augmentation](docs/ai-augmentation-opportunities-es.md) | Oportunidades por sector |
| [Context Engineering](docs/context-engineering-es.md) | Mejoras de contexto e IA |

---

## Reglas que nunca se saltan

Ni yo misma las salto: no hardcodear PATs, confirmar antes de escribir en Azure DevOps, leer CLAUDE.md del proyecto antes de actuar, no lanzar agente sin spec aprobada, no subir secrets al repo, no `terraform apply` en PRO sin aprobación, siempre rama + PR. Detalle completo en [KPIs y reglas](docs/readme/10-kpis-reglas.md).

---

## Contribuir

Con `/contribute` puedes crear PRs directamente. Con `/feedback` abrir issues. Antes de enviar, valido que no haya datos privados. Tu privacidad es lo primero.

Agradecimiento especial a [claude-code-templates](https://github.com/davila7/claude-code-templates) de [Daniel Avila](https://github.com/davila7) — el mayor marketplace de componentes para Claude Code (5.788+ componentes, 21K+ stars).

> Changelog completo en [CHANGELOG.md](CHANGELOG.md) · Releases en [GitHub Releases](https://github.com/gonzalezpazmonica/pm-workspace/releases)

---

*🦉 Savia — tu PM automatizada con IA. Compatible con Azure DevOps, Jira y Savia Flow.*
