# Spec: SE-146 — Subagent Stop Gate for High-Criticality Skills

**Task ID:**        SE-146
**Sprint:**         2026-22
**Fecha creación:** 2026-05-27
**Creado por:**     Savia

---

## Status: APPROVED

---

## Objetivo

Prevenir activaciones en cascada cuando una skill de alto impacto es invocada
como subagente delegado por un orquestador. Sin este gate, el orquestador
lanzaría el workflow completo de la skill (con su propio bucle de sub-agentes),
generando runs fuera de control.

## Problema

Skills como `overnight-sprint`, `code-improvement-loop`, `adversarial-security`
contienen bucles de orquestación propios. Si un agente padre las invoca vía `Task`
tool para ejecutar una tarea concreta, la skill activaba todo su pipeline, no solo
la tarea pedida.

## Solución

Insertar un bloque `## Subagent Scope Guard` en las 8 skills de mayor criticidad,
inmediatamente después del frontmatter. El bloque instruye a la skill a:

1. Detectar contexto de subagente (Task tool, `SAVIA_SUBAGENT=1`, flag `--subagent`)
2. Ejecutar solo la tarea asignada
3. Reportar `DONE | DONE_WITH_CONCERNS | BLOCKED` y retornar

## Skills afectadas

| Skill | Path |
|---|---|
| adversarial-security | `.claude/skills/adversarial-security/SKILL.md` |
| code-improvement-loop | `.claude/skills/code-improvement-loop/SKILL.md` |
| consensus-validation | `.claude/skills/consensus-validation/SKILL.md` |
| dag-scheduling | `.claude/skills/dag-scheduling/SKILL.md` |
| overnight-sprint | `.claude/skills/overnight-sprint/SKILL.md` |
| spec-driven-development | `.claude/skills/spec-driven-development/SKILL.md` |
| tdd-vertical-slices | `.claude/skills/tdd-vertical-slices/SKILL.md` |
| verification-lattice | `.claude/skills/verification-lattice/SKILL.md` |

## Criterios de aceptación

- [ ] Las 8 skills contienen el bloque `## Subagent Scope Guard` tras el frontmatter
- [ ] Cada skill afectada tiene ≤150 líneas (Rule 11)
- [ ] `docs/rules/domain/autonomous-safety.md` contiene la sección `## Subagent Scope Guard — SE-146`
- [ ] Commit en `feature/SE-146-subagent-stop` con mensaje canónico

## Referencias

- `docs/rules/domain/autonomous-safety.md` — sección Subagent Scope Guard
- `docs/rules/domain/autonomous-safety.md` — regla inmutable de supervisión humana
