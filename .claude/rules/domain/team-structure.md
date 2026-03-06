---
name: team-structure
description: "Multi-team coordination architecture — departments, boundaries, RACI, escalation"
auto_load: false
paths: [".claude/commands/team-orchestrator*", ".claude/skills/team-coordination/*"]
---

# Regla: Estructura Multi-Equipo

> Basado en: Team Topologies (Skelton & Pais, 2019), Scaled Agile (SAFe)
> Complementa: @.claude/rules/domain/pm-workflow.md
> Complementa: @.claude/rules/domain/rbac-model.md (cuando exista)

**Principio fundamental**: Los equipos operan con autonomía dentro de sus bordes. La coordinación cross-equipo se hace explícita mediante dependencias declaradas, no mediante jerarquía.

## Modelo organizacional

### Jerarquía: Organización → Departamento → Equipo → Miembro

```
org/
├── departments.md              # Índice de departamentos
├── {dept}/
│   ├── dept.md                 # Nombre, responsable, misión, equipos
│   └── {team}/
│       ├── team.md             # Miembros, roles RACI, capacidad, proyectos
│       └── deps.md             # Dependencias con otros equipos
```

### Fichero `team.md` — Schema

```yaml
name: "Backend Core"
department: "engineering"
lead: "@handle"
members:
  - handle: "@ana"
    role: contributor    # RACI: R (Responsible)
    capacity: 1.0        # FTE (0.5 = media jornada)
    projects: ["api-v3", "auth-service"]
  - handle: "@carlos"
    role: pm             # RACI: A (Accountable)
    capacity: 0.8
    projects: ["api-v3"]
capacity_total: 4.5      # Suma FTE
velocity_avg: 42          # Story points / sprint (media 5 sprints)
sprint_cadence: 2w        # 1w | 2w | 3w | 4w
```

### Fichero `deps.md` — Schema de dependencias

```yaml
dependencies:
  - team: "frontend-web"
    type: blocking       # blocking | informational | shared-resource
    description: "API contracts — frontend espera endpoints"
    status: green        # green | amber | red
  - team: "platform"
    type: shared-resource
    description: "Cluster Kubernetes compartido"
    status: amber
```

## Tipos de dependencia

| Tipo | Significado | Acción si rojo |
|---|---|---|
| **blocking** | Equipo A no puede avanzar sin entrega de equipo B | Escalar a dept lead |
| **informational** | Equipo A necesita saber qué hace B (no bloquea) | Sync asíncrono |
| **shared-resource** | Ambos equipos comparten recurso (infra, persona, presupuesto) | Negociar prioridad |

## Roles RACI por equipo

| Rol | Significado | Quién lo tiene |
|---|---|---|
| **R** (Responsible) | Ejecuta el trabajo | Contributors (devs, QA) |
| **A** (Accountable) | Responsable final, aprueba | PM / Tech Lead |
| **C** (Consulted) | Se le consulta antes de decidir | Architect, Security |
| **I** (Informed) | Se le notifica después | Stakeholders, CEO |

## Reglas de escalamiento

1. **Bloqueo < 24h** → Sync directo entre leads de ambos equipos
2. **Bloqueo 24-72h** → Escalar a responsable de departamento
3. **Bloqueo > 72h** → Escalar a dirección + generar `/ceo-alerts`
4. **Dependencia circular detectada** → CRÍTICO: resolver en 48h o rediseñar bordes

## Métricas cross-equipo

| Métrica | Fórmula | Umbral |
|---|---|---|
| **Dependency Health** | % deps en green | ≥80% = sano |
| **Cross-team WIP** | Items con deps bloqueantes activas | ≤3 por equipo |
| **Sync Overhead** | Horas/sprint en ceremonias cross-team | ≤10% capacidad |
| **Lead Time Cross** | Tiempo desde petición a entrega (cross-team) | ≤1.5× lead time interno |

## Team Topologies mapping

| Tipo Skelton-Pais | En pm-workspace | Ejemplo |
|---|---|---|
| Stream-aligned | Equipo de proyecto/feature | "Equipo Pagos" |
| Platform | Equipo de plataforma/infra | "Equipo DevOps" |
| Enabling | Equipo de habilitación/CoP | "Equipo Arquitectura" |
| Complicated-subsystem | Equipo especialista | "Equipo ML/Data Science" |

## Integración con comandos existentes

| Consumidor | Uso de esta regla |
|---|---|
| `/team-orchestrator` | Crear/gestionar estructura multi-equipo |
| `/portfolio-overview` | Incluir datos de equipo en vista portfolio |
| `/capacity-planner` | Calcular capacidad cross-equipo |
| `/ceo-report` | Agregar métricas de salud inter-equipo |

## Anti-patrones

- **Equipo > 10 personas** → dividir (regla de dos pizzas)
- **Equipo sin lead** → asignar accountable explícito
- **Dependencias no declaradas** → cada sprint, revisar deps.md
- **Sync excesivo** → si >10% de capacidad en ceremonias cross-team, reducir
