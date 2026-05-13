---
description: Recomienda si usar ACM/HCM/Graphify segun task_scope y model_tier
---

# /heavy-context-recommend

Recomienda si usar **Agent Code Map**, **Human Code Map** o **Graphify** en
funcion del scope de la tarea y el tier del modelo activo. Implementa la
matriz canonica de `docs/rules/domain/heavy-context-tools-criteria.md`
(SPEC-HEAVY-CONTEXT-CRITERIA).

## Uso

```
/heavy-context-recommend <scope> <tier> [--project NAME] [--tool TOOL]
/heavy-context-recommend --show-matrix
/heavy-context-recommend --migrate
```

### Argumentos

- `scope`: `systemic | cross-module | single-file | lookup`
- `tier`: `fast | mid | heavy`
- `--project NAME`: proyecto activo (opcional, se loguea).
- `--tool TOOL`: `agent-code-map | human-code-map | graphify` (opcional).

### Modos

- **active**: prereqs cumplidos (`~/.savia/usage.db` + tabla
  `heavy_context_invocations` + datos en `turns`) -> registra la decision con
  `outcome='unknown'` en `heavy_context_invocations`.
- **advisory**: prereqs no cumplidos -> muestra matriz, NO loguea, banner
  `[ADVISORY MODE]`.

### Tentative flag

Las celdas `model_tier=heavy` llevan `(tentative, N<10)` mientras no haya
>=10 invocaciones logueadas con `model_tier='heavy'`. Aplica solo a la
columna heavy.

## Ejemplo

```
$ /heavy-context-recommend single-file mid
Decision: AVOID
Reason:   Single-file con mid: baseline gana 2/3; CAC innecesario.
Logged:   heavy_context_invocations[ts=2026-05-13T18:22:00Z, outcome=unknown]
```

## Ejecucion

```bash
python3 scripts/heavy-context-recommend.py "$@"
```

## Referencias

- Spec: `docs/specs/SPEC-HEAVY-CONTEXT-CRITERIA.spec.md`
- Regla: `docs/rules/domain/heavy-context-tools-criteria.md`
- Informe origen: "Context vs Tokens" (2026-05, n=108)
