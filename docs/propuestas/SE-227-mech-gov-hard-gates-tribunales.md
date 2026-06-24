---
id: SE-227
title: Mech-gov hard gates pre-LLM + E3 entropy para tribunales Savia
status: PARTIALLY_IMPLEMENTED
priority: P2
effort: M (6h)
origin: Research 2026-06-24 — github.com/SantanderAI/mech-gov-framework
author: Savia
related: truth-tribunal-orchestrator, recommendation-tribunal-orchestrator, SPEC-192
proposed_at: "2026-06-24"
implemented_at: "2026-06-24"
era: 235
slice_done: 1
slice_pending: 2
---

# SE-227 — Mech-gov: hard gates pre-LLM + E3 entropy para tribunales

## Estado de implementación

| Slice | Estado | Notas |
|---|---|---|
| Slice 1 — Hard gates + E3 nonce scripts | IMPLEMENTED | `scripts/tribunal-hard-gates.sh`, `scripts/tribunal-nonce-gen.sh` |
| Slice 2 — Integración en agentes orquestadores | PENDING | Bloqueado por PR #863 (SE-106 — truth/recommendation/court orchestrators en cola) |
| Slice 3 — Truth Tribunal + I6Q | DEFERRED | Planificado post-Slice 2 |

> **Slice 2 bloqueada**: Los agentes `recommendation-tribunal-orchestrator.md`,
> `truth-tribunal-orchestrator.md` y `court-orchestrator.md` están en PR #863
> (SE-106). La integración de hard gates en esos agentes debe hacerse tras el
> merge de ese PR para evitar conflictos de merge.

## Problema

Los tribunales de Savia son pipelines 100% LLM. Tres problemas:

1. **Coste innecesario**: preguntas trivialmente rechazables (formato incorrecto, datos faltantes) consumen tokens de jueces LLM cuando un gate determinístico las filtraría en O(1).
2. **Pre-cooking invisible**: el modelo puede llegar a los jueces con la decisión ya tomada (positivity bias). El patrón E3 entropy commit-reveal detecta esto.
3. **I6Q gap**: si los argumentos de los jueces no superan un umbral de calidad mínimo, el tribunal debería emitir ESCALATE obligando a mejorar la pregunta.

## Tesis

Añadir una capa mecánica antes de los jueces LLM:

```
Input → hard_gates → E3_entropy_commit → CEFL → I6Q → ambiguity_gate → E3_reveal + output
```

Si un gate mecánico activa, el LLM no se llama. Reducción de coste + detección de pre-cooking.

## Diseño implementado (Slice 1)

### scripts/tribunal-hard-gates.sh

5 gates determinísticos, zero LLM:

| Gate | Descripción | Tribunal por defecto |
|---|---|---|
| `no_empty_output` | Fichero de input existe y es legible | Todos (siempre) |
| `format_check` | Input >50 chars | `recommendation` (automático) |
| `length_range` | 50 < input < 50000 chars | `truth`, `court` (automático) |
| `spec_syntax` | Si hay referencia a spec, el path existe en repo | Todos (siempre) |
| `source_check` | Al menos un @ref o URL presente | `truth` (automático), `--source-check` |
| `e3_nonce_check` | Si --nonce, el nonce aparece en el output del juez | Cuando se pasa --nonce |

```bash
# Usage:
tribunal-hard-gates.sh --tribunal recommendation|truth|court \
                        --input-file <json_or_text> \
                        [--format-check] [--source-check] [--length-check] \
                        [--nonce <string>]

# Output (siempre JSON a stdout):
# {"passed": true, "gates_run": 3, "failures": []}
# {"passed": false, "gates_run": 2, "gate": "format_check",
#  "reason": "input too short (10 chars, minimum 50)", "failures": [...]}
```

### scripts/tribunal-nonce-gen.sh

Generador E3 — stdlib-only (openssl preferido, python3 hashlib fallback):

```bash
tribunal-nonce-gen.sh                           # genera nonce (sha256, 64 hex chars)
tribunal-nonce-gen.sh --verify <nonce> <file>   # verifica presencia (exit 0/1)
tribunal-nonce-gen.sh --self-test               # 5 tests internos
```

**Algoritmo**: `sha256(timestamp_millis + ":" + 16 random bytes hex)`

### Flujo de uso (Slice 2 — pendiente integración orquestadores)

```bash
# En el orquestador (post-PR #863):
NONCE="$(bash scripts/tribunal-nonce-gen.sh)"

# Gate pre-LLM:
GATE_RESULT="$(bash scripts/tribunal-hard-gates.sh \
  --tribunal recommendation \
  --input-file "$draft_file" \
  --nonce "$NONCE")"

if echo "$GATE_RESULT" | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if d["passed"] else 1)'; then
  # Llamar jueces LLM con NONCE en el prompt
  # Los jueces deben incluir el nonce en la primera línea
  ...
else
  # Short-circuit: HARD_GATE_FAIL sin llamar jueces
  GATE=$(echo "$GATE_RESULT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["gate"])')
  echo "HARD_GATE_FAIL: $GATE"
fi

# Post-juicio: verificar nonce (anti pre-cooking)
bash scripts/tribunal-nonce-gen.sh --verify "$NONCE" "$judge_output_file" \
  || echo "E3_NONCE_MISMATCH" >> output/anti-adulation-telemetry.jsonl
```

## Tests

`tests/test-tribunal-hard-gates.bats` — 14 tests, todos PASS:

1. Script existe
2. Script es ejecutable
3. `no_empty_output` falla con fichero inexistente
4. `format_check` falla con fichero vacío
5. `format_check` pasa con >50 chars
6. `length_range` falla con 10 chars
7. `length_range` falla con >50000 chars
8. `spec_syntax` pasa sin referencia a spec
9. `e3_nonce_check` falla si nonce ausente
10. `e3_nonce_check` pasa si nonce presente
11. `nonce-gen --self-test` pasa
12. `nonce-gen` genera hex de 64 chars
13. `nonce-gen --verify` detecta presencia
14. JSON `gates_run` es correcto

## Restricciones de implementación

- `PURE_BASH` + python3 stdlib si necesario
- `ZERO LLM calls`
- No modificados: `recommendation-tribunal-orchestrator.md`, `truth-tribunal-orchestrator.md`, `court-orchestrator.md` — en cola PR #863

## Risks

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Hard gates demasiado estrictos | Media | Modo warn antes de block; gates configurables via flags |
| E3 nonce añade fricción | Baja | 1 línea en prompt de cada juez |
| I6Q umbrales subjetivos | Media | Diferido a Slice 3 con calibración en 50 casos reales |
