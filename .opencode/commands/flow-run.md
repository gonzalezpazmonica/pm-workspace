---
name: flow-run
description: >
  Ejecuta un flow agéntico secuencial. Wrapper bash mínimo (Rule #26)
  sobre scripts/flow_runner.py. SPEC-AGENTIC-FLOW-GRAPH §2.5.
---

# /flow-run — Ejecutor de Agentic Flow Graph

**Argumentos:** `$ARGUMENTS` — `flow_id [--input k=v ...] [--dry-run]`.

## 1. Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌊 /flow-run — Ejecutando flow agéntico
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Prerrequisitos

- `.venv/` activable: `source scripts/savia-env.sh`.
- Flow validado: `/flow-validate <flow_id>` debe estar en verde.

## 3. Ejecución

```bash
source scripts/savia-env.sh
python3 scripts/flow_runner.py run $ARGUMENTS
```

Sin args → uso: `/flow-run <flow_id> [--input k=v] [--dry-run]`.

## 4. Salida

JSON con `flow_id`, `run_id`, `ok`, paths a `trace.jsonl` y `state.json`.
Estado persistido en `output/flows/{run_id}/`.

## 5. Códigos de salida

| Code | Significado |
|------|-------------|
| 0    | flow OK o dry-run |
| 1    | nodo falló o timeout |
| 3    | flow no encontrado / I/O |
