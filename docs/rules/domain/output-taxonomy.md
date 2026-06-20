---
context_tier: L2
token_budget: 720
---

# Regla: Ubicación canónica de outputs (output/ taxonomy)

> **REGLA OPERATIVA** — Aplica cada vez que Savia (o un agente delegado) genera un fichero en `output/`. Define DÓNDE va cada tipo de fichero. La política de **qué mostrar en pantalla** está en `file-output-summary.md` (complementaria).

## Principio

`output/` está gitignored. Todo lo que generan agentes vive aquí. **Pero la raíz de `output/` NO es un cajón desastre** — hay 5 sub-categorías estables con convenciones distintas. Poner ficheros en el sitio equivocado genera drift, dificulta `grep` cross-referencial y rompe la trazabilidad spec→origen.

## Taxonomía canónica

| Tipo de fichero | Path | Naming | Quién escribe |
|---|---|---|---|
| **Informe one-off pedido por usuario** (sprint status, weekly, executive, cost, time-tracking) | `output/` raíz | `YYYYMMDD-tipo-proyecto.ext` | Comandos `/sprint-*`, `/weekly-*`, `/executive-*`, `/cost-*` |
| **Investigación que origina specs** (research de repos, papers, técnicas externas) | `output/research/` | `{tema}-{YYYYMMDD}.md` | Skills `tech-research-agent`, `web-research`, sesiones manuales de research |
| **Audit logs append-only** (telemetría continua) | `output/` raíz | `{audit-name}.jsonl` o `{audit-name}-YYYYMMDD.jsonl` | Hooks, jueces, tribunales |
| **Artifacts de pipeline** (CI runs, test results, coverage) | `output/{pipeline-name}/` | Definido por la pipeline | Pipelines, agentes autónomos |
| **State operacional** (sesión viva, dev-sessions, parallel-runs) | `output/session-state/`, `output/dev-sessions/`, `output/parallel-runs/` | Definido por el dominio | Comandos de sesión, dev-orchestrator |

## Casos canónicos

### Caso 1: Usuario pide informe (NO origina spec)

Usuario pide weekly report de proyecto X. Savia genera en raíz de `output/` con naming `YYYYMMDD-tipo-proyecto.ext`. Origen: pm-workflow Rule #5.

### Caso 2: Usuario pide investigación que puede originar spec

Usuario pide investigar técnica externa. Savia genera:
- Investigación en `output/research/{tema}-{YYYYMMDD}.md`
- Spec (si aplica) en `docs/propuestas/SE-NNN-*.md`
- Entrada en `docs/ROADMAP.md` con priority_score V×U/E

### Caso 3: Skill `tech-research-agent` autónomo

Misma convención que Caso 2: `output/research/{tema}-{YYYYMMDD}.md`. Drift histórico (path sin slash) corregido en la sesión que originó esta regla.

### Caso 4: Audit log continuo

Hooks y jueces appendean a `output/{audit-name}.jsonl`. Ejemplos: judge-verdict-validation-errors, quality-gate-history, anti-adulation-telemetry, context-token-log.

### Caso 5: Postmortem de incidente

`output/postmortems/YYYYMMDD-{incident-id}.md`. Origen: `docs/rules/domain/postmortem-policy.md`.

## Decisión rápida (árbol)

```
¿El fichero contiene...?

  ├── ...datos que el usuario pidió ver (sprint, weekly, exec) ?
  │     → raíz de output/ con naming YYYYMMDD-tipo-proyecto.ext
  │
  ├── ...investigación de tema externo (repo, paper, técnica) ?
  │     → output/research/ con naming {tema}-{YYYYMMDD}.md
  │       (y considera generar spec en docs/propuestas/)
  │
  ├── ...telemetría continua / audit log ?
  │     → raíz de output/ con naming {audit-name}.jsonl
  │
  ├── ...artefactos de pipeline (CI, tests, coverage) ?
  │     → subdirectorio output/{pipeline-name}/
  │
  ├── ...estado operacional vivo (sesión, dev-session) ?
  │     → output/session-state/ | output/dev-sessions/ | output/parallel-runs/
  │
  └── ...postmortem de incidente ?
        → output/postmortems/ con naming YYYYMMDD-{incident-id}.md
```

## Antipatrones

| Antipatrón | Síntoma | Fix |
|---|---|---|
| Investigación en raíz de `output/` | fichero de research aislado fuera del subdirectorio research | mover a `output/research/{tema}-{YYYYMMDD}.md` |
| Informe one-off en `output/research/` | mezcla user-output con investigación interna | mover a raíz `output/` con naming canónico |
| Spec en `output/` | confusión spec/research | spec va a `docs/propuestas/SE-NNN-*.md` o `docs/specs/SPEC-*.md` |
| Audit log con fecha pegada al nombre genérico | extensión jsonl en mitad del nombre | usar `{audit-name}-YYYYMMDD.jsonl` (extensión al final) |

## Relación con otras reglas

- `docs/rules/domain/pm-workflow.md` Rule #5 — formato `YYYYMMDD-tipo-proyecto.ext` (informes one-off)
- `docs/rules/domain/file-output-summary.md` — política de qué mostrar en pantalla
- `docs/rules/domain/autonomous-safety.md` — outputs de agentes autónomos van con AUTONOMOUS_REVIEWER
- `docs/rules/domain/session-state-location.md` — state operacional en `output/session-state/`
- `docs/rules/domain/postmortem-policy.md` — postmortems en su subdirectorio

## Origen

Lección durante sesión de investigación: research generado inicialmente en raíz de `output/` cuando la convención establecida (11 ficheros previos) era `output/research/`. Usuario detectó el drift. Esta regla codifica el patrón real ya en uso para que no vuelva a ocurrir.

Drift histórico corregido en la misma sesión que originó esta regla:
- `.opencode/skills/tech-research-agent/SKILL.md` y su gemelo `.claude/skills/tech-research-agent/SKILL.md` — actualizados a `output/research/{tema}-{YYYYMMDD}.md`.
- `docs/rules/domain/autonomous-safety.md` — actualizado.
- `.claude/commands/tech-research.md` — actualizado.
