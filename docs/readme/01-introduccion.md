# PM-Workspace — AI-Powered Project Management for Claude Code

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> Plataforma de gestión de proyectos **multi-lenguaje** con IA, impulsada por Claude Code como PM automatizada con capacidad de delegar implementación técnica a agentes de IA y gestionar infraestructura cloud. Compatible con Azure DevOps, Jira y Savia Flow (Git-native).

> **🚀 ¿Primera vez aquí?** Consulta la [Guía de Adopción para Consultoras](../ADOPTION_GUIDE.md) — paso a paso desde el registro en Claude hasta la incorporación de proyectos y equipo.

---

## ¿Qué es esto?

Este workspace convierte a Claude Code en un **Project Manager automatizado con IA** para proyectos de **cualquier lenguaje**. Funciona con Azure DevOps, Jira, o 100% Git-native con Savia Flow. Soporta 16 lenguajes (C#/.NET, TypeScript, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter) con convenciones, reglas y agentes especializados para cada uno. Su característica más avanzada es el **Spec-Driven Development (SDD)**: un proceso en el que las tareas técnicas se documentan como contratos ejecutables, y Claude puede implementarlas como agente de código.

**Gestión de sprints:** seguimiento de burndown, capacity del equipo, estado del board, KPIs, reportes automáticos de retrospectiva y review en Excel/PowerPoint.

**Descomposición de PBIs:** Claude analiza el backlog, descompone cada PBI en tasks con estimación en horas, detecta el balance de carga del equipo y propone asignaciones con un algoritmo de scoring (expertise × disponibilidad × balance × crecimiento).

**Spec-Driven Development:** las tasks se convierten en especificaciones ejecutables. Un "developer" puede ser un humano o un agente Claude. Claude puede implementar automáticamente handlers, repositorios, unit tests y más en el lenguaje del proyecto, siguiendo la spec como contrato.

**Infraestructura como Código:** gestión multi-cloud (Azure, AWS, GCP) con detección automática de recursos existentes, creación al tier más bajo posible, y escalado solo con aprobación humana.

**Multi-entorno:** soporte para DEV/PRE/PRO (o cualquier configuración personalizada) con protección de configuración confidencial — las connection strings y secrets nunca van al repositorio.

---

## Ejemplo — Primeros cinco minutos con el workspace

_Escenario: Es lunes por la mañana. Abres Claude Code por primera vez desde la raíz de `~/claude/`._

**Tú escribes:**
```
¿Qué proyectos tengo configurados y qué puedo hacer?
```

**Claude responde:**
```
Tengo configurados 2 proyectos activos:
  • ProyectoAlpha  — equipo de 6 personas, sprint 2026-04 activo
  • ProyectoBeta   — equipo de 4 personas, precio fijo, sprint 2026-04 activo

Puedo ayudarte con:
  Sprint      → /sprint-status, /sprint-plan, /sprint-review, /sprint-retro
  Informes    → /report-hours, /report-executive, /report-capacity
  Backlog     → /pbi-decompose, /pbi-plan-sprint, /pbi-assign
  SDD (agentes) → /spec-generate, /agent-run, /spec-status

¿Por dónde quieres empezar? Si es lunes, te recomiendo /sprint-status
para ver el estado actual del sprint antes de la Daily.
```

**Tú escribes:**
```
/sprint-status --project ProyectoAlpha
```

**Claude responde:**
```
══════════════════════════════════════════
  Sprint 2026-04 · ProyectoAlpha · Día 6/10
══════════════════════════════════════════

  Burndown  ████████░░░░░░░░  40% completado  ⚠️ por debajo del plan
  Objetivo sprint: Módulo de Pacientes v2

  Items activos (In Progress): 4
    AB#1021  Crear endpoint POST /patients  → Laura S.   [3/5h]
    AB#1022  Unit tests PatientService      → 🤖 agente  [En ejecución]
    AB#1023  Migración tabla Alergias       → Diego T.   [0/4h] ⚠️ sin avance
    AB#1024  Swagger annotations            → 🤖 agente  [Terminado, en Review]

  🔴 Alertas:
    • AB#1023 lleva 2 días sin movimiento — ¿está bloqueado?
    • Burndown al 40% en día 6 → riesgo de no completar el sprint goal
    • WIP actual: 4 items (límite configurado: 5) ✅

  Capacidad restante: 68h humanas + ~12h de agente disponibles
```

---
