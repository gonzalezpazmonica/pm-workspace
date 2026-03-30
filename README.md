<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Español** | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

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

**Primera vez?** Lee la [Guia de Inicio](docs/getting-started.md) — de cero a productivo en 15 minutos. Para proteccion de datos de clientes: [Guia de Savia Shield](docs/savia-shield-guide.md).

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

Mas detalle en la [Guia de flujo de datos](docs/data-flow-guide-es.md) y en **[Mi Sistema de Memoria](docs/memory-architecture.md)** — como persisto en texto plano, busco por significado y aprendo de cada sesión.

---

## Dónde vive todo

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 505 comandos (lo que me puedes pedir)
│   ├── agents/         ← 49 agentes especializados
│   ├── skills/         ← 85 skills con conocimiento de dominio
│   ├── hooks/          ← 35 hooks que refuerzan reglas automáticamente
│   └── rules/          ← reglas de contexto, lenguaje, dominio
├── docs/
│   ├── quick-starts/   ← guías por rol (PM, Dev, QA, PO, TL, CEO)
│   ├── readme/         ← documentación detallada (13 secciones)
│   ├── guides/         ← 15 guías por escenario (Azure, Jira, startup, memoria...)
│   └── savia-flow/     ← docs del sistema Git-native
├── projects/
│   ├── savia-mobile-android/  ← app Android nativa + bridge
│   └── savia-web/             ← Vue.js web client para dashboards
├── zeroclaw/
│   ├── firmware/       ← MicroPython para ESP32 (selftest, heartbeat, LCD)
│   ├── host/           ← bridge, daemon, voz, guardrails, brain
│   ├── savia-voice/    ← daemon de voz next-gen (full-duplex, Kokoro TTS)
│   ├── tests/          ← 77 tests sin hardware
│   └── ROADMAP.md      ← fases 0-6 hacia autonomía
├── scripts/            ← validación, CI, utilidades, savia-bridge.py
├── output/             ← ficheros generados (informes, specs, exports)
└── CLAUDE.md           ← mi identidad y reglas fundamentales
```

Cada comando tiene frontmatter YAML con metadata (modelo, coste de contexto, descripción). Las reglas se auto-cargan por tipo de fichero o dominio. Los skills se activan por demanda.

---

## Qué puedo hacer

**Gestión de proyectos** — Sprints, burndown, capacity, KPIs, dailies, retros. Informes automáticos en Excel y PowerPoint. Predicción de completitud con Monte Carlo.

**Spec-Driven Development** — Las tasks se convierten en specs ejecutables. Implemento handlers, tests y repositorios en 16 lenguajes. Los agentes trabajan en worktrees aislados para evitar conflictos.

**Inteligencia de código** — Detecto patrones de arquitectura (Clean, Hexagonal, DDD, CQRS, Microservices), mido salud arquitectónica con fitness functions, y priorizo deuda técnica por impacto de negocio. Genero diagramas de arquitectura, flujo, secuencia y organigramas de equipo exportables a Draw.io, Miro o Mermaid local. Importo organigramas existentes para generar la estructura de equipos automáticamente (`/orgchart-import`). **Human Code Maps (.hcm)** — mapas narrativos en lenguaje humano que pre-digieren el primer paseo por un subsistema. Cada proyecto lleva sus mapas en `.human-maps/` dentro de su propia carpeta. Comandos: `/codemap:generate-human`, `/codemap:walk`, `/codemap:debt-report`. Lucha activa contra la deuda cognitiva: los desarrolladores pasan el 58% del tiempo leyendo código; estos mapas reducen ese coste de sesión en sesión.

**Seguridad y compliance** — SAST contra OWASP Top 10, SBOM, escaneo de credenciales, compliance regulatorio en 12 sectores, gobernanza IA con model cards y EU AI Act. Auditoría de confidencialidad pre-PR con agente contextual + firma criptográfica HMAC-SHA256 verificada en CI.

**Infraestructura** — Multi-cloud (Azure, AWS, GCP) con detección automática, tier mínimo por defecto, y escalado solo con tu aprobación. Pipelines CI/CD configurables.

**Memoria y contexto** — Memory store persistente (JSONL), entity recall, progressive disclosure, continuidad entre sesiones. Personal Vault (N3) con repo git independiente para datos del usuario, cifrado AES-256. Context Gate (SPEC-015) salta el scoring de skills en prompts triviales. Progressive Loading L0/L1/L2 (SPEC-012) reduce tokens de skills un 40-60%. Intelligent Compact (SPEC-016) extrae decisiones y correcciones antes de compactar — zero-loss. Session Memory Extraction (SPEC-013) persiste conocimiento al cerrar sesión.

**Informes ejecutivos** — CEO report multi-proyecto, alertas de dirección, portfolio overview, DORA metrics, value stream mapping.

**Accesibilidad universal** — Trabajo guiado para personas con discapacidad (visual, motora, TDAH, autismo, dislexia, auditiva). Micro-tareas de 3-5 min, detección de bloqueos, reformulación adaptativa.

**Verticales sectoriales** — Research lab, hardware lab, legal, healthcare, nonprofit, insurance, retail y telco — 32 comandos especializados cubriendo 8 industrias con sus flujos de trabajo nativos.

**Seguridad adversarial e inteligencia adaptativa** — Pipeline Red/Blue/Auditor con score 0-100, threat modeling STRIDE/PASTA. Pentesting dinámico con pipeline autónomo de 5 fases (Shannon-inspired), queue-driven, política "no exploit, no report". Lab local con servicios intencionalmente vulnerables. Motor de evaluación de skills con auto-detección de 7 tipos de proyecto y sistema de instintos con scoring de confianza.

**Modos autónomos** — Sprint nocturno, bucle de mejora de código, investigación técnica y onboarding con buddy IA. Los agentes proponen, el humano dispone: ramas `agent/*`, PRs Draft, revisión humana obligatoria.

**Era 164 — Calidad adaptativa** — Responsibility Judge (hook determinista que detecta 7 patrones de atajo), trace-to-prompt optimization, deteccion de colapso de instintos (AMI/CDS/PAR), requirement pushback (desafia suposiciones de specs), dev-session discard (abort limpio de sesiones fallidas), review de profundidad ajustable por riesgo (quick/standard/thorough), reaction engine (bucle declarativo CI/review), state machine de 13 estados para dev sessions, y descomposicion recursiva de tareas (atomica/compuesta).

**Colaboración** — Company Savia (mensajería E2E cifrada), Savia Flow (PM Git-native), Travel Mode, backup cifrado, Savia School. Referencia: [505 comandos · 49 agentes · 85 skills](docs/readme/12-comandos-agentes.md)

**Savia Mobile** — App Android nativa (Kotlin/Compose) que conecta con pm-workspace vía [Savia Bridge](scripts/savia-bridge.py) — un servidor HTTPS/SSE que envuelve Claude Code CLI. Chat con streaming en tiempo real, persistencia local cifrada, tema Material 3. Detalles: [Savia Mobile](projects/savia-mobile-android/README.md)

**Savia Web** — Cliente web Vue.js 3 + TypeScript + Vite con 10 páginas de dashboards (sprints, deuda, DORA, capacidad, etc.) y 10 componentes ECharts. [Savia Bridge](scripts/savia-bridge.py) expone 8 endpoints de reporting (velocity, burndown, DORA, workload, quality, debt, cycle-time, portfolio). Script de deploy en `setup-savia-web.sh`. Detalles: [Savia Web](projects/savia-web/README.md)

**SaviaClaw** — Savia en el mundo fisico. ESP32 con LCD 16x2, firmware MicroPython (selftest, heartbeat, comandos JSON, WiFi). Host daemon con reconexion automatica. Brain Bridge: ESP32 → Claude CLI → LCD. Savia Voice v2.4: daemon full-duplex con Silero VAD + faster-whisper + Claude stream-json + Kokoro TTS local (200ms/frase). Conversation model con clasificacion de overlaps (backchannel/stop/collaborative). Pre-cache de 64 frases para latencia cero. 7 guardrails deterministas. 77 tests sin hardware. [Roadmap](zeroclaw/ROADMAP.md)

**Soberania de dependencias** — SPEC-017: USB de 32GB que contiene Savia completa para instalación offline. Python standalone, pip wheels, modelos Whisper/Kokoro/Ollama, ffmpeg, jq, Node.js, Claude Code. 4 tiers (4-20GB). SaviaOS: distro Ubuntu minimal booteable desde USB, arranca en cualquier PC x86_64 sin tocar el disco. `sovereignty-pack.sh` prepara el USB desde maquina con internet.

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
| [Introducción y ejemplo](docs/readme/01-introduccion.md) | Primeros 5 minutos |
| [Estructura del workspace](docs/readme/02-estructura.md) | Directorios y organización |
| [Configuración inicial](docs/readme/03-configuración.md) | PAT, constantes, verificación |
| [Guía de adopción](docs/ADOPTION_GUIDE.md) | Paso a paso para consultoras |
| [Sprints e informes](docs/readme/04-uso-sprint-informes.md) | Sprint, reporting, KPIs |
| [Spec-Driven Development](docs/readme/05-sdd.md) | SDD: specs, agentes, patrones |
| [Flujo de datos](docs/data-flow-guide-es.md) | Cómo se conectan las partes |
| [Confidencialidad](docs/confidentiality-levels.md) | 5 niveles (N1-N4b) y mecanismos |
| [**Estrategia AST**](docs/ast-strategy.md) | Comprensión de código legado + 12 Quality Gates universales + Human Code Maps (.hcm) |
| [**Savia Shield**](docs/savia-shield.md) | Soberanía de datos: clasificación local, masking reversible, LLM on-premise |
| [Comandos y agentes](docs/readme/12-comandos-agentes.md) | 505 comandos + 49 agentes |
| [Guías por escenario](docs/guides/README.md) | Azure, Jira, startup, sanidad... |
| [AI Augmentation](docs/ai-augmentation-opportunities-es.md) | Oportunidades por sector |
| [Context Engineering](docs/context-engineering-es.md) | Mejoras de contexto e IA |
| [Savia Mobile](projects/savia-mobile-android/README.md) | App Android + Bridge |
| [SaviaClaw Roadmap](zeroclaw/ROADMAP.md) | Hardware: ESP32 + voz + sensores |

---

## Reglas que nunca se saltan

Ni yo misma las salto: no hardcodear PATs, confirmar antes de escribir en Azure DevOps, leer CLAUDE.md del proyecto antes de actuar, no lanzar agente sin spec aprobada, no subir secrets al repo, no `terraform apply` en PRO sin aprobación, siempre rama + PR. Detalle completo en [KPIs y reglas](docs/readme/10-kpis-reglas.md).

---

## Aprendizaje clave: hooks > prompts

Los LLMs olvidan instrucciones. No siempre, pero sí en un ~20% de los casos en sesiones largas o con contexto alto. Para las reglas que no pueden olvidarse — no hacer force-push a main, no filtrar datos de proyecto a ficheros públicos, no commitear sin tests — confiar solo en el CLAUDE.md no es suficiente.

**La solución: los hooks son deterministas, los prompts no lo son.**

Un hook de bash que bloquea `git push --force` funciona el 100% de las veces, independientemente de cuántos tokens hayas consumido o de cuántas instrucciones haya en contexto. El CLAUDE.md instruye; los hooks garantizan.

Esta conclusión emergió de forma independiente en varios proyectos de la comunidad (gstack, ECC, Astromesh) y es el principio arquitectónico más importante de pm-workspace:

```
Regla crítica  →  hook determinista (bash)   ← 100% de garantía
Convención     →  CLAUDE.md / rules/          ← orientación, no garantía
Flujo de trabajo →  commands + skills         ← orquestación inteligente
```

pm-workspace incluye 35 hooks en tres niveles de activación:

| Perfil | Hooks activos | Cuándo usarlo |
|---|---|---|
| `minimal` | Solo seguridad (credential leak, force-push, infra destructiva, soberanía de datos) | Demos, onboarding, debug de hooks |
| `standard` | Seguridad + calidad + workflow | Desarrollo diario (por defecto) |
| `strict` | Todo, incluyendo escrutinio extra | Pre-release, código crítico |
| `ci` | Igual que standard, sin interacción | Pipelines CI/CD |

Cambiar perfil: `/hook-profile set minimal` o `export SAVIA_HOOK_PROFILE=ci`

---

## Privacidad y Telemetría

**Zero telemetría.** pm-workspace no envia datos a ningun servidor. No hay analytics, no hay tracking, no hay phone-home. Todo se ejecuta localmente. La búsqueda vectorial usa un modelo local (22 MB). Los embeddings se generan en tu CPU. Los datos de tus proyectos nunca salen de tu maquina. Offline-first por diseno.

---

## Contribuir

Con `/contribute` puedes crear PRs directamente. Con `/feedback` abrir issues. Antes de enviar, valido que no haya datos privados. Tu privacidad es lo primero.

Créditos a los proyectos, estudios y personas que inspiraron funcionalidades: [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).

> Changelog completo en [CHANGELOG.md](CHANGELOG.md) · Releases en [GitHub Releases](https://github.com/gonzalezpazmonica/pm-workspace/releases)

*🦉 Savia — tu PM automatizada con IA. Compatible con Azure DevOps, Jira y Savia Flow.*
