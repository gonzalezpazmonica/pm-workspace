---
title: "docs/ — Índice navegable"
category: meta
order: 1
stale: null
---

# docs/ — Índice navegable

Punto de entrada a los documentos más importantes de pm-workspace.
Si es tu primera vez aquí, empieza por la sección "Para empezar".

---

## Para empezar

Los 10 documentos más importantes para orientarse:

| # | Documento | Para qué sirve |
|---|---|---|
| 1 | [CLAUDE.md](../CLAUDE.md) | Instrucciones maestras del workspace — roles, reglas críticas, lazy-refs |
| 2 | [ROADMAP.md](ROADMAP.md) | Todas las eras, specs en curso y próximas iniciativas |
| 3 | [RESOLVER.md](RESOLVER.md) | Tabla de dispatch intent → skill / agente |
| 4 | [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitectura del workspace: capas, patrones, decisiones |
| 5 | [STRUCTURE.md](STRUCTURE.md) | Taxonomía oficial de docs/ — dónde va cada cosa |
| 6 | [docs/rules/domain/critical-rules-extended.md](rules/domain/critical-rules-extended.md) | Reglas 9-25: secrets, infra, git, CI, UX, PII |
| 7 | [docs/memory-system.md](memory-system.md) | Sistema de memoria: L0-L3, auto-memory, episodios |
| 8 | [docs/best-practices-claude-code.md](best-practices-claude-code.md) | Buenas prácticas de desarrollo con Claude Code / OpenCode |
| 9 | [AGENTS.md](AGENTS.md) | Catálogo de agentes del workspace con tabla de selección |
| 10 | [docs/agent-teams-sdd.md](agent-teams-sdd.md) | Orquestación multi-agente SDD — equipos y flujos |

---

## Por caso de uso

### Para trabajar en un sprint

| Documento | Descripción |
|---|---|
| [docs/rules/domain/pm-workflow.md](rules/domain/pm-workflow.md) | Cadencia scrum, comandos de sprint, ceremonias |
| [docs/rules/domain/pm-config.md](rules/domain/pm-config.md) | Configuración del workspace: paths, constantes |
| [docs/ROADMAP.md](ROADMAP.md) | Estado actual de las specs e iniciativas |
| [docs/savia-flow/](savia-flow/) | Savia Flow: dual-track, métricas de flujo |

### Para implementar una feature (SDD)

| Documento | Descripción |
|---|---|
| [docs/agent-teams-sdd.md](agent-teams-sdd.md) | Flujo completo: business-analyst → spec → dev → review |
| [docs/agent-notes-protocol.md](agent-notes-protocol.md) | Protocolo de handoff entre agentes |
| [docs/rules/domain/agents-catalog.md](rules/domain/agents-catalog.md) | Catálogo de 75 agentes con criterios de selección |
| [docs/rules/domain/language-packs.md](rules/domain/language-packs.md) | 16 language packs: qué lenguaje usar para cada proyecto |
| [docs/best-practices-claude-code.md](best-practices-claude-code.md) | Optimización de contexto, refactoring, patrones |

### Para entender la arquitectura

| Documento | Descripción |
|---|---|
| [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Visión general: capas, patrones, decisiones |
| [docs/memory-system.md](memory-system.md) | Sistema de memoria persistente L0-L3 |
| [docs/memory-architecture.md](memory-architecture.md) | Arquitectura detallada de memory: episódica, semántica, procedimental |
| [docs/rules/domain/context-placement-confirmation.md](rules/domain/context-placement-confirmation.md) | Dónde guardar datos: niveles N1-N4b |
| [docs/SAVIA-GENESIS.md](SAVIA-GENESIS.md) | Documento fundacional: origen y evolución de Savia |
| [docs/eras-timeline.md](eras-timeline.md) | Línea temporal de las eras del workspace |

### Para configurar seguridad y permisos

| Documento | Descripción |
|---|---|
| [docs/confidentiality-levels.md](confidentiality-levels.md) | Niveles de confidencialidad N1-N4b y manejo de datos |
| [docs/rules/domain/radical-honesty.md](rules/domain/radical-honesty.md) | Regla #24: Honestidad radical (mandato central) |
| [docs/rules/domain/autonomous-safety.md](rules/domain/autonomous-safety.md) | Seguridad en modos autónomos: overnight, code-improvement |
| [docs/savia-shield.md](savia-shield.md) | Savia Shield: capa de protección de identidad y datos |

### Para entender el ecosistema Enterprise

| Documento | Descripción |
|---|---|
| [docs/ENTERPRISE_ROADMAP.md](ENTERPRISE_ROADMAP.md) | Roadmap de specs SE-* (Enterprise) |
| [docs/enterprise/](enterprise/) | Módulos Enterprise documentados |
| [docs/savia-enterprise-mit-forever.md](savia-enterprise-mit-forever.md) | Compromiso MIT + soberanía de datos |
| [docs/data-sovereignty-architecture.md](data-sovereignty-architecture.md) | Arquitectura de soberanía de datos |

### Para operaciones y mantenimiento

| Documento | Descripción |
|---|---|
| [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Guía de resolución de problemas comunes |
| [docs/release-procedure.md](release-procedure.md) | Procedimiento de release |
| [docs/EMERGENCY.md](EMERGENCY.md) | Protocolo de emergencia (LocalAI fallback) |
| [docs/operations/](operations/) | Runbooks y procedimientos operacionales |

---

## Taxonomía de docs/

Ver [docs/STRUCTURE.md](STRUCTURE.md) para la taxonomía oficial completa.

### Subdirectorios principales

| Directorio | Propósito |
|---|---|
| `docs/core/` | Conceptos fundamentales de Savia |
| `docs/guides/` | Guías de uso por rol y objetivo |
| `docs/rules/` | Reglas y políticas del workspace |
| `docs/specs/` | Specs ejecutables |
| `docs/propuestas/` | RFCs y backlog de specs |
| `docs/decisions/` | ADRs — Architecture Decision Records |
| `docs/operations/` | Runbooks y procedimientos |
| `docs/learning/` | Investigación y hallazgos |
| `docs/enterprise/` | Módulos Enterprise (opt-in) |
| `docs/i18n/` | Traducciones (en, fr, de, it, pt, ca, eu, gl) |
| `docs/reference/` | Catálogos de referencia (agentes, comandos, skills) |
| `docs/archive/` | Documentos obsoletos — histórico |

---

## Auditoría de la estructura

```bash
# Ver qué docs están en raíz y deberían estar en subcarpetas
bash scripts/docs-audit.sh

# Formato JSON para integración
bash scripts/docs-audit.sh --json

# Guardar informe en output/
bash scripts/docs-audit.sh --output auto
```

---

_Actualizado: 2026-06-24 · Maintainer: Savia (scripts/docs-audit.sh)_
