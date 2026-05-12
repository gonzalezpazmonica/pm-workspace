---
name: flow-to-obsidian
description: >
  Renderiza cada `.scm/flows/*.flow.yaml` como nota Obsidian con backlinks a
  sus nodos (commands, agents, skills, hooks, subflows). La metacúpula los
  visualiza como grafo nativo. SPEC-AGENTIC-FLOW-GRAPH §3.4 (Slice 4).
---

# /flow-to-obsidian — Render flows como notas Obsidian

**Argumentos:** `$ARGUMENTS` — `flow_id`, ruta a `.flow.yaml`, o vacío para todos.

## 1. Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗺️  /flow-to-obsidian — Render flows
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Prerrequisitos

- `.venv/` activable: `source scripts/savia-env.sh`.
- Dep: `pyyaml` (vía `requirements.txt`).

## 3. Ejecución

```bash
source scripts/savia-env.sh
python3 scripts/flow_to_obsidian.py $ARGUMENTS
```

Sin argumentos → renderiza todos los `.scm/flows/*.flow.yaml`.

## 4. Salida

- Una nota por flow en `output/obsidian/flows/flow-<flow_id>.md`.
- Cada nota contiene: descripción, tabla de nodos con backlinks `[[kind-name]]`,
  diagrama Mermaid del grafo, y sección Backlinks plana (Obsidian la indexa).

## 5. Códigos de salida

| Code | Significado |
|------|-------------|
| 0    | al menos un flow renderizado |
| 1    | ningún flow renderizado |
| 3    | error de I/O o dependencia faltante |

## 6. Reglas (Rule #26)

Wrapper bash mínimo. Toda la lógica estructurada vive en
`scripts/flow_to_obsidian.py`.
