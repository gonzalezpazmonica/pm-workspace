---
name: savia-flow-practice
description: Implementación práctica de Savia Flow — dual-track, specs ejecutables, métricas de flujo
globs: []
---

# Savia Flow — Implementación Práctica

> Savia Flow es una metodología de desarrollo orientada a outcomes, flujo continuo y specs ejecutables.
> Esta skill lleva la teoría (docs/savia-flow/) a la práctica: configuración real, ejemplos y comandos.

## Cuándo usar esta skill

- Configurar un proyecto nuevo con Savia Flow (`/flow-setup`)
- Visualizar el tablero dual-track (`/flow-board`)
- Mover specs listas a producción (`/flow-intake`)
- Consultar métricas de flujo (`/flow-metrics`)
- Crear specs desde outcomes de exploración (`/flow-spec`)

## Cuándo NO usar

- Si el equipo usa Scrum clásico → usar `sprint-management`
- Si solo necesitas descomponer PBIs → usar `pbi-decomposition`
- Si solo necesitas escribir specs → usar `spec-driven-development`

## Prerrequisitos (skills existentes)

| Skill | Uso en Savia Flow |
|---|---|
| `azure-devops-queries` | Queries WIQL, REST API, MCP tools |
| `devops-validation` | Auditar configuración del proyecto |
| `spec-driven-development` | Generar specs ejecutables |
| `pbi-decomposition` | Descomponer specs en tasks |
| `capacity-planning` | Calcular capacidad y WIP |
| `product-discovery` | JTBD + PRD en exploration track |

## Conceptos clave

### Dual-Track
Dos flujos paralelos que se alimentan mutuamente:

**Exploration Track** — Descubrir qué construir (Elena lidera):
Discovery → Spec-Writing → Spec-Ready

**Production Track** — Construir lo que está listo (Ana + Isabel):
Ready → Building → Gates → Deployed → Validating

### Handoff
El puente entre tracks es la **Spec-Ready**: una spec completa con outcome, métricas de éxito, especificación funcional, restricciones técnicas y Definition of Done. Solo items Spec-Ready entran a Production.

### Roles Savia Flow

| Rol Savia Flow | Quién | Foco |
|---|---|---|
| Flow Facilitator | PM/CTO | Optimizar flujo, desbloquear, métricas |
| AI Product Manager | Producto/QA | Discovery, hypothesis, escribir specs |
| Pro Builder | Devs | Orquestar IA, arquitectura, code review |
| Quality Architect | QA | Diseñar gates, supervisar agentes, defect escapes |

### Métricas (DORA + IA)

| Métrica | Target | Cálculo |
|---|---|---|
| Cycle Time | 3-7 días | Deploy Date - Build Start |
| Lead Time | 7-14 días | Deploy Date - Idea Date |
| Throughput | 8-12 items/sem | Items deployed / semana |
| CFR | <5% | Deploys con incidente / Total deploys |
| Spec-to-Built | <5 días | Build Start - Spec-Ready Date |
| Rework Rate | <15% | Features reescritas / Total |

## References

| Fichero | Contenido |
|---|---|
| `azure-devops-config.md` | Board columns, custom fields, area paths, tags |
| `backlog-structure.md` | Dos backlogs, prioridad, WIP limits, handoff |
| `task-template-sdd.md` | Plantilla spec 5 componentes, acceptance criteria |
| `meetings-cadence.md` | Cadencia reuniones, calendario equipo 4 personas |
| `dual-track-coordination.md` | Quién hace qué, capacidad por track, dependencias |
| `example-socialapp.md` | Ejemplo completo: SocialApp (Ionic + microservicios) |

## Comandos

| Comando | Propósito |
|---|---|
| `/flow-setup` | Configurar Azure DevOps para Savia Flow |
| `/flow-board` | Visualizar tablero dual-track |
| `/flow-intake` | Mover Spec-Ready → Production |
| `/flow-metrics` | Dashboard métricas de flujo |
| `/flow-spec` | Crear spec desde outcome |

## Compatibilidad

Savia Flow coexiste con Scrum. No es necesario migrar todo de golpe:
- Sprint-management sigue funcionando para equipos en Scrum
- Los comandos flow-* pueden usarse gradualmente
- Un equipo puede empezar con `/flow-metrics` para medir, sin cambiar su proceso

## Plataformas soportadas

| Plataforma | Estado | Reference |
|---|---|---|
| Azure DevOps | ✅ Completo | `azure-devops-config.md` |
| GitLab | 🔜 Planned | — |
| Jira Cloud | 🔜 Planned | — |
| GitHub Projects | 🔜 Planned | — |

Diseño agnóstico: los comandos abstraen "Exploration/Production track". Cada plataforma tendrá su propio reference de configuración.
