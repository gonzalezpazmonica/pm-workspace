---
spec_id: SE-228
slice: S1
context_tier: L2
token_budget: 900
---

# Loop State Schema — STATE.md canónico para skills autónomos

> Canonical schema for STATE.md used by `overnight-sprint`, `code-improvement-loop`,
> and `tech-research-agent`. Every autonomous skill that runs in a loop MUST follow
> this schema so that state survives session boundaries and is human-readable.
>
> Ref: SE-228 Slice 1 · `docs/rules/domain/autonomous-safety.md`

## Por qué

Sin STATE.md canónico, cada run reinicia desde cero:
- Los PRs anteriores se re-crean duplicados
- Los ítems ignorados vuelven a ser procesados
- El historial de intentos se pierde entre sesiones

STATE.md es la **memoria operativa** del loop entre runs.

---

## Estructura obligatoria

Cada `output/loop-state/<skill>/STATE.md` DEBE contener exactamente estas secciones
en este orden:

```markdown
# Loop State — <nombre-skill>

Last run: YYYY-MM-DD HH:MM UTC

## High Priority (loop actuando o esperando humano)

## Watch List

## Recently Resolved

## Noise / Ignored
```

---

## Secciones: definición y semántica

**Header**: `# Loop State — <nombre-skill>` — identifica el skill propietario.

**Last run**: `Last run: YYYY-MM-DD HH:MM UTC` — actualizar al inicio de cada run.

**High Priority** (loop actuando/esperando humano):
`- [ ] #ID — descripción (Loop action: X. Waiting: Y. attempt N/3)`. Cuando N=3 → Noise/Ignored.

**Watch List** (monitorizado, sin acción):
`- [ ] #ID — descripción (reason: X)`

**Recently Resolved** (últimos 7 días):
`- [x] #ID — descripción (resolved: YYYY-MM-DD, outcome: merged|closed|discarded)`. Gestionado por `loop-state-prune.sh`.

**Noise / Ignored** (descartados permanentemente):
`- [-] #ID — descripción (reason: X)`

## Reglas de modificación

| Regla | Descripción |
|---|---|
| **Append-only** | Nunca borrar entradas. Solo mover entre secciones o marcar `[x]`/`[-]` |
| **Prune explícito** | Para eliminar entradas antiguas usar `loop-state-prune.sh` |
| **Last run primero** | El primer write de cada run actualiza `Last run:` |
| **attempt 3/3 → Noise** | Al llegar a 3 intentos fallidos, mover a Noise / Ignored |
| **Resolved ≤7 días** | Recently Resolved solo conserva los últimos 7 días (o `--max-resolved N`) |

---

## Paths canónicos

| Skill | STATE.md path |
|---|---|
| `overnight-sprint` | `output/loop-state/overnight-sprint/STATE.md` |
| `code-improvement-loop` | `output/loop-state/code-improvement-loop/STATE.md` |
| `tech-research-agent` | `output/loop-state/tech-research-agent/STATE.md` |

---

## Scripts de gestión

| Script | Propósito |
|---|---|
| `scripts/loop-state-init.sh` | Crea STATE.md desde template si no existe |
| `scripts/loop-state-prune.sh` | Archiva ítems cerrados en Recently Resolved |

Referencia completa: comentarios inline en cada script.

---

