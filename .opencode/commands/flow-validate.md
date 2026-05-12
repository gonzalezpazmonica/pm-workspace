---
name: flow-validate
description: >
  Valida flows agénticos en .scm/flows/*.flow.yaml. Comprueba schema JSON,
  referencias entre nodos, ciclos sin guard y compila toda expresión CEL
  (when / exit_when) vía celpy. SPEC-AGENTIC-FLOW-GRAPH §2.7 + AMENDMENT-01.
---

# /flow-validate — Gate estático de flows

**Argumentos:** `$ARGUMENTS` — `flow_id`, ruta a un `.flow.yaml`, o `all`.

## 1. Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 /flow-validate — Validando flows
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Prerrequisitos

- `.venv/` activable: `source scripts/savia-env.sh` (carga `_savia_activate_venv`).
- Dependencias: `pyyaml`, `jsonschema`, `cel-python` (módulo `celpy`) — instaladas vía `requirements.txt`.

## 3. Ejecución

```bash
source scripts/savia-env.sh
python3 scripts/flow_validate.py "$ARGUMENTS"
```

Sin argumento → uso: `/flow-validate <flow_id|path|all>`.

## 4. Salida

- `[OK] <path>` por cada flow válido.
- `[FAIL] <path>` seguido de errores anotados:
  - `schema[<jsonpath>]: ...` para violaciones del schema JSON.
  - `CEL[<location>]: compile error: ...` para expresiones que no compilan.
  - `cycle without exit_when guard: ...` para ciclos no acotados.

## 5. Códigos de salida

| Code | Significado |
|------|-------------|
| 0    | todos los flows válidos |
| 1    | error de schema o semántico (refs/ciclos) |
| 2    | error de compilación CEL (AMENDMENT-01) |
| 3    | error de I/O o uso |

## 6. Reglas (Rule #26)

Wrapper bash mínimo (≤15 líneas). Toda lógica estructurada vive en
`scripts/flow_validate.py`. NO `jq`/`awk`/`sed` para parsear YAML.
