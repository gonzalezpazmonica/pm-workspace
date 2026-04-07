<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**Español** | [English](README.en.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Tu equipo de desarrollo merece una PM que nunca duerme

Los sprints se descontrolan. El backlog crece sin priorizar. Los informes para dirección se hacen a mano. La deuda técnica se acumula sin que nadie la mida. Los agentes de IA generan código sin specs y sin tests.

**pm-workspace** resuelve esto. Es una PM completa que vive dentro de Claude Code: gestiona sprints, descompone backlog, coordina agentes de código con specs ejecutables, genera informes para dirección, y vigila la deuda técnica — en el idioma que uses, con los datos protegidos en tu máquina.

---

## Empieza en 3 minutos

```bash
# 1. Instala
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Abre Claude Code en el directorio
cd pm-workspace && claude

# 3. Savia te saluda y te pregunta tu nombre. Después:
/sprint-status          # ← tu primer comando
```

Savia se adapta a ti. Si eres PM, te muestra sprints y capacity. Si eres developer, te muestra tu backlog y specs. Si eres CEO, te muestra portfolio y DORA metrics.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## Qué problemas resuelve

| Problema | Sin pm-workspace | Con pm-workspace |
|---|---|---|
| Sprint status | Abrir Azure DevOps, filtrar, calcular | `/sprint-status` → dashboard completo |
| Informe para dirección | 2h en Excel/PowerPoint | `/ceo-report` → generado con datos reales |
| Implementar feature | Pedir al dev que interprete el ticket | `/spec-generate` → spec ejecutable → agente implementa → tests → PR |
| Deuda técnica | "Ya lo arreglaremos" | `/debt-analyze` → priorizado por impacto |
| Code review | Revisar a mano 300 líneas | `/pr-review` → 3 perspectivas (seguridad, arquitectura, negocio) |
| Onboarding nuevo dev | 2 semanas leyendo código | `/onboard` → guía personalizada + buddy IA |

---

## Hola, soy Savia 🦉

Soy la buhita que vive dentro de pm-workspace. Me adapto a tu rol, tu idioma y tu forma de trabajar. Funciono con Azure DevOps, Jira, o 100% Git-native con Savia Flow.

**Quick-starts por rol:**

| Rol | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## Lo que hay dentro

**508 comandos · 48 agentes · 90 skills · 49 hooks · 16 lenguajes · 130 test suites**

### Gestión de proyectos
Sprints, burndown, capacity, dailies, retros, KPIs. Informes en Excel y PowerPoint. Predicción con Monte Carlo. Facturación y costes.

### Desarrollo con specs ejecutables (SDD)
Las tasks se convierten en specs. Los agentes implementan en 16 lenguajes (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) en worktrees aislados. Code review automático + revisión humana obligatoria.

### Seguridad
SAST contra OWASP Top 10, pipeline Red/Blue/Auditor, pentesting dinámico, SBOM, compliance en 12 sectores. Savia Shield: clasificación local de datos con LLM on-premise, masking reversible, firma criptográfica de PRs. Emergency Watchdog: fallback automático a LLM local (Gemma 4 / Qwen) si cae internet.

### Memoria persistente
Texto plano (JSONL). Entity recall, búsqueda semántica, continuidad entre sesiones. Extracción automática de decisiones antes de compactar. Personal Vault cifrado AES-256.

### Accesibilidad
Trabajo guiado para personas con discapacidad (visual, motora, TDAH, autismo, dislexia). Micro-tareas, detección de bloqueos, reformulación adaptativa.

### Inteligencia de código
Detección de arquitectura (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) que reducen la deuda cognitiva.

### Modos autónomos
Sprint nocturno, mejora de código, investigación técnica. Los agentes proponen en ramas `agent/*` con PRs Draft — el humano siempre decide.

### Extensiones
[Savia Mobile](projects/savia-mobile-android/README.md) (Android nativo) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + voz full-duplex)

---

## Estructura

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 508 comandos
│   ├── agents/         ← 48 agentes especializados
│   ├── skills/         ← 90 skills de dominio
│   ├── hooks/          ← 49 hooks deterministas
│   └── rules/          ← reglas de contexto y lenguaje
├── docs/               ← guías por rol, escenario, sector
├── projects/           ← proyectos (git-ignorados por privacidad)
├── scripts/            ← validación, CI, utilidades
├── zeroclaw/           ← hardware ESP32 + voz
└── CLAUDE.md           ← identidad y reglas fundamentales
```

---

## Documentación

| Sección | Descripción |
|---|---|
| [Guía de inicio](docs/getting-started.md) | De cero a productivo |
| [Flujo de datos](docs/data-flow-guide-es.md) | Cómo se conectan las partes |
| [Confidencialidad](docs/confidentiality-levels.md) | 5 niveles (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Soberanía de datos |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Comandos y agentes](docs/readme/12-comandos-agentes.md) | Referencia completa |
| [Guías por escenario](docs/guides/README.md) | Azure, Jira, startup, sanidad... |
| [Adopción](docs/ADOPTION_GUIDE.md) | Paso a paso para consultoras |

---

## Principios

1. **Texto plano es la verdad** — .md y .jsonl. Si se pierde la IA, los datos siguen legibles
2. **Privacidad absoluta** — datos del usuario nunca salen de su máquina
3. **El humano decide** — la IA propone, nunca merge ni deploy autónomo
4. **Apache 2.0 / MIT** — sin vendor lock-in, sin telemetría

---

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md) y [SECURITY.md](SECURITY.md). PRs bienvenidos.

## Licencia

[MIT](LICENSE) — Creado por [Mónica González Paz](https://github.com/gonzalezpazmonica)
