---
name: scaling-patterns
description: "Scaling tiers (small/medium/large), optimization recommendations, vendor sync patterns, knowledge search, CI/CD governance"
auto_load: false
paths: [".claude/commands/scale-optimizer*", ".claude/skills/scaling-operations/*"]
---

# Regla: Patrones de Escalabilidad

> Basado en: Team Topologies (Skelton & Pais), Accelerate (Forsgren et al.)
> Complementa: @docs/rules/domain/team-structure.md, @docs/rules/domain/command-ux-feedback.md

**Principio fundamental**: Cada tier de escala requiere reorganización de contexto, concurrencia, y gobernanza.

## Tiers de escalabilidad

### Tier 1 — Small (1-5 proyectos, 5-30 personas)

Características:
- Un contexto de proyecto en memoria
- Pair programming = síncrono directo
- 1 release rhythm global
- Reuniones: daily + refinement semanal

Optimizaciones:
- Context: cargar completo (< 50KB)
- Agents: secuencial (1 spec → 1 dev agent)
- Workflows: Savia LITE (3 comandos core)

### Tier 2 — Medium (5-20 proyectos, 30-100 personas)

Características:
- Multiple teams, pero low coupling
- Async communication CRITICAL
- 2-3 release rhythms (por equipo)
- Reuniones: daily async, refinement async

Optimizaciones:
- Context: per-team (100-200KB total)
- Agents: 2-3 paralelos (batch specs)
- Workflows: multi-fase (SDD full)
- Worktree strategy: 1 main + 1 per team

### Tier 3 — Large (20-50 proyectos, 100-500 personas)

Características:
- Stream-aligned teams (independientes)
- Cross-team dependencies tracked
- Platform team + enabling teams
- Async-first culture

Optimizaciones:
- Context: fragments only (50KB límite)
- Agents: 5+ paralelos (subagent pool)
- Workflows: SDD + governance layer
- Worktree strategy: 1 main + 1 per dept

## Recomendaciones por Tier

| Aspecto | Small | Medium | Large |
|---|---|---|---|
| **Context optimization** | Load all | Per-team segments | Fragment-based |
| **Parallel agents** | 1-2 | 3-4 | 5+ |
| **Worktree strategy** | None | 1 feature | 1 per dept |
| **Meeting frequency** | Daily sync | Daily async | Weekly async |
| **Decision latency** | < 24h | < 48h | < 72h |
| **Dependency tracking** | Implicit | Explicit (deps.md) | Registry + alerts |

## Integración de vendors

**Patrón**: config → skill → output (idéntico para todos)

```
1. config.md: leer parámetros
2. skill ejecuta lógica (agnóstico vendor)
3. output: formato estándar markdown
```

**Sync patrón**: snapshot → diff → conflict resolution

1. Tomar snapshot de estado remoto (Azure DevOps / Jira)
2. Detectar cambios locales
3. Merge: mantener local, actualizar timestamp
4. NUNCA auto-resolver conflictos

## Búsqueda de conocimiento

Full-text search across:
- decision-log.md
- ADRs (architecture decision records)
- Specs (.spec.md files)
- Rules (@docs/rules/domain/)
- Agent memory (.claude/agent-memory/)

## Gobernanza CI/CD

**PR Guardian estandarización**: mismo checklist para todos los repos

Requisitos por tier:
- Small: build + test + review
- Medium: build + test + review + security scan
- Large: build + test + review + security + governance + compliance

**Hooks compartidos**: `.claude/hooks/` en mono-repo o multi-repo sync
