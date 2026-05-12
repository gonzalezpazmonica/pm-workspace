---
name: flow-trace
description: >
  Imprime la traza JSONL de un run de flow. Wrapper bash mínimo sobre
  scripts/flow_runner.py trace. SPEC-AGENTIC-FLOW-GRAPH §2.6.
---

# /flow-trace — Traza de un run

**Argumentos:** `$ARGUMENTS` — `[--run <run_id>] [--node <node_id>]`.

## 1. Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔬 /flow-trace — Traza de ejecución
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Ejecución

```bash
source scripts/savia-env.sh
python3 scripts/flow_runner.py trace $ARGUMENTS
```

Sin `--run` muestra el último; con `--node` filtra.
