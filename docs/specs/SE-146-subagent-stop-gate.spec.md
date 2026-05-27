# Spec: SE-146 — SUBAGENT-STOP Gate for High-Criticality Skills

**Task ID:**        SE-146
**Status:**         APPROVED
**Sprint:**         2026-21
**Fecha creación:** 2026-05-26
**Creado por:**     Savia (sesión interactiva)

---

## Contexto

Cuando un agente es despachado como subagente para ejecutar una tarea delegada
específica, puede cargar una skill de alto nivel (spec-driven-development,
adversarial-security, overnight-sprint, etc.) y activar su workflow completo de
orquestación: planificación, security audits, overnight sprints, paralelización
masiva... ninguno de esos efectos era deseado. El subagente debería simplemente
ejecutar la tarea asignada y retornar.

Patrón origen: obra/superpowers (MIT) — SUBAGENT-STOP.

---

## Objetivo

Insertar un bloque `## Subagent Scope Guard` en las 8 skills de mayor criticidad
para que cualquier agente despachado como subagente detecte el guard y salte el
workflow completo, ejecutando únicamente la tarea delegada.

---

## Acceptance Criteria

- [ ] AC-1: Los 8 skills tienen el bloque `## Subagent Scope Guard` inmediatamente
  tras el frontmatter YAML y antes del primer heading de contenido.
- [ ] AC-2: El bloque contiene el texto canónico con instrucciones de: skip workflow,
  execute only delegated task, return DONE/DONE_WITH_CONCERNS/BLOCKED.
- [ ] AC-3: Ningún skill supera 150 líneas tras la modificación.
- [ ] AC-4: `docs/rules/domain/autonomous-safety.md` documenta el patrón SE-146.
- [ ] AC-5: El commit está en rama `feature/SE-146-subagent-stop` (NO en main).

---

## Skills afectadas

| Skill | Riesgo sin guard |
|---|---|
| `spec-driven-development` | Activa workflow SDD completo (analyst→architect→spec→dev) |
| `adversarial-security` | Activa pipeline Red+Blue+Auditor completo |
| `overnight-sprint` | Activa bucle autónomo nocturno completo |
| `code-improvement-loop` | Activa bucle de mejora autónomo con PRs |
| `tdd-vertical-slices` | Activa planning loop TDD completo |
| `dag-scheduling` | Activa orquestación paralela DAG completa |
| `consensus-validation` | Activa panel de 4 jueces completo |
| `verification-lattice` | Activa pipeline de 5 capas completo |

---

## Bloque canónico

```markdown
## Subagent Scope Guard

> If you were dispatched as a subagent to execute a specific delegated task,
> **skip this skill's full orchestration workflow**. Execute only the assigned
> task, report result (DONE / DONE_WITH_CONCERNS / BLOCKED), and return.
> This guard prevents runaway skill activation in nested agent contexts.
```

---

## Referencia

- `docs/rules/domain/autonomous-safety.md` — sección SUBAGENT-STOP (SE-146)
- Patrón origen: Superpowers (obra/superpowers)
