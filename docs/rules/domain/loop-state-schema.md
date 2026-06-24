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

### Header

```
# Loop State — <nombre-skill>
```

Identifica el skill propietario. `<nombre-skill>` es el nombre exacto del directorio
en `.opencode/skills/` (e.g. `overnight-sprint`, `code-improvement-loop`).

### Last run

```
Last run: YYYY-MM-DD HH:MM UTC
```

Actualizado al **inicio** de cada run, antes de cualquier otra operación.
Formato ISO 8601 truncado a minutos, siempre UTC.

### High Priority (loop actuando o esperando humano)

Ítems que el loop está procesando activamente o que esperan acción humana.

Formato de ítem:

```
- [ ] #ID — descripción breve (Loop action: <acción tomada>. Waiting: <qué se espera>. attempt N/3)
```

| Campo | Descripción |
|---|---|
| `#ID` | Identificador del ítem: PR number, branch name, task ID, etc. |
| `descripción` | Resumen humano en ≤80 caracteres |
| `Loop action` | Última acción tomada por el loop (e.g. "PR created", "Fix applied") |
| `Waiting` | Qué bloquea el progreso (e.g. "human review", "CI green", "—") |
| `attempt N/3` | Contador de intentos. Cuando N=3 → mover a Noise / Ignored |

Ejemplo:

```
- [ ] #1042 — Fix linter warnings in auth module (Loop action: PR created. Waiting: human review. attempt 1/3)
- [ ] agent/overnight-20260620-add-tests — Add unit tests UserService (Loop action: tests failed. Waiting: —. attempt 2/3)
```

### Watch List

Ítems monitorizados que el loop observa pero sobre los que no actúa todavía.
No se crean PRs ni commits para estos ítems.

Formato de ítem:

```
- [ ] #ID — descripción (reason: <por qué está en watch, no en high priority>)
```

Ejemplo:

```
- [ ] #1099 — Dependency update for lodash (reason: pending upstream release v4.18.0)
```

### Recently Resolved

Ítems cerrados, mergeados o descartados en los **últimos 7 días**.
El loop mueve aquí los ítems de High Priority cuando detecta que el PR está
merged o el branch está cerrado.

Formato de ítem:

```
- [x] #ID — descripción (resolved: YYYY-MM-DD, outcome: <merged|closed|discarded>)
```

Ejemplo:

```
- [x] #1035 — Fix null ref in user controller (resolved: 2026-06-20, outcome: merged)
- [x] agent/overnight-20260619-lint — Lint fixes (resolved: 2026-06-21, outcome: discarded — tests failed)
```

El script `loop-state-prune.sh` gestiona esta sección automáticamente.

### Noise / Ignored

Señales descartadas permanentemente: flakes, dependabot ruido, ítems fuera de scope,
o ítems que agotaron los 3 intentos.

Formato de ítem:

```
- [-] #ID — descripción (reason: <por qué se ignora>)
```

Ejemplo:

```
- [-] dependabot/npm_and_yarn/lodash-4.17.21 — Dependabot auto-patch (reason: handled by external policy)
- [-] #1041 — Flaky test in CI (reason: attempt 3/3 exhausted, requires human investigation)
```

---

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

## Ejemplo completo

```markdown
# Loop State — overnight-sprint

Last run: 2026-06-25 02:15 UTC

## High Priority (loop actuando o esperando humano)

- [ ] #1042 — Fix linter warnings in auth module (Loop action: PR created. Waiting: human review. attempt 1/3)
- [ ] #1043 — Add missing index on users.email (Loop action: branch created. Waiting: CI green. attempt 1/3)

## Watch List

- [ ] #1099 — Dependency update lodash (reason: pending upstream release)

## Recently Resolved

- [x] #1035 — Fix null ref user controller (resolved: 2026-06-20, outcome: merged)
- [x] #1038 — Add test coverage auth service (resolved: 2026-06-21, outcome: merged)

## Noise / Ignored

- [-] dependabot/npm_and_yarn/lodash-4.17.21 (reason: handled by external policy)
```
