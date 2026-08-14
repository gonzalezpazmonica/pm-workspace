---
name: token-meter
description: "SE-326 S3: medición determinista de la superficie de la sesión (tokens heurísticos, baseline provider, snapshot inmutable)"
argument-hint: "medir | --surface '<json>' | --usage <n>"
tier: core
---

# /token-meter — Medición de contexto determinista (SE-326)

Inspirado en deepseek-harness `packages/llm/token-meter`: snapshot inmutable de
presión de contexto de la sesión con heurística por rol, baseline provider
(cuando existe `usage` del último call) y surface en nodos posicionales.

## Uso

```
scripts/token-meter.py --session <id>                 # mide desde un surface vacío
scripts/token-meter.py --session <id> --surface '<json>'  # surface como lista {role,text}
scripts/token-meter.py --session <id> --surface-file <path>  # surface desde fichero
scripts/token-meter.py --session <id> --usage 4200    # con baseline provider
scripts/token-meter.py --session <id> --out output/token-meter/<session>.json
```

## Salida

```json
{
  "session": "abc123",
  "log_revision": 0,
  "baseline": {"kind": "estimated", "anchor_tokens": 0},
  "surface_delta_tokens": 1250,
  "total_tokens": 1250,
  "surface_tokens": 1250,
  "nodes": [{"seq": 0, "tokens": 180}]
}
```

## Integración

- `context-rot-strategy` puede consumir `total_tokens` real en vez del % manual.
- `loop-budget-check.sh` puede usar `surface_tokens` para presupuestar rondas.
- Emite telemetría `savia.token-meter` (savia.event/1.0, SE-313) con `--emit`.

Ref: `docs/propuestas/SE-326-harness-loop-hygiene.md`
