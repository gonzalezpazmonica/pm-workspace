---
status: IMPLEMENTED
---

# SPEC-196 — Freeze-Done Elements in Tribunal Orchestrator

> **Priority:** P1 · **Estimate (human):** 1-2d · **Estimate (agent):** 2-3h · **Category:** trivial · **Type:** optimization

> **Dual estimate**: 1-2 dias humano (modificacion del orchestrator + tests). 2-3h agente.

## Objective

El Recommendation Tribunal (SPEC-125 + SPEC-192) hoy lanza los 7 jueces en paralelo y espera a TODOS antes de agregar verdict. Si el primer juez retorna en 1.2s con `veto: true, confidence: 0.95`, el orchestrator sigue esperando hasta los 5s wall-clock de los demas. **Coste evitable.**

DiffusionGemma usa `_WhileLoopCarry.done: Bool['B']` — una mascara per-batch que congela elementos terminados. La iteracion siguiente salta los elementos `done=True`. Mismo concepto aplica al tribunal: cuando un juez emite veto con confianza alta, los demas jueces para ese mismo draft pueden cancelarse — su veredicto es informativo pero no cambiara el outcome (VETO ya esta determinado por el primer juez).

Esta spec implementa cancelacion temprana **per-draft** (no per-juez). Si juez 1 emite VETO definitivo:
1. Marcar draft como `done=true` con `done_reason=early_veto`.
2. Cancelar los demas jueces que aun corren para ese draft via `kill -TERM` del PID.
3. Telemetria registra cuantos tokens y segundos se ahorraron.

Trade-off honesto: si los demas jueces aportan **evidencia complementaria** util al humano (ej. juez B detectaria un harm distinto que juez A no vio), la cancelacion temprana lo pierde. Mitigacion: mantener `EARLY_CANCEL_THRESHOLD` alto (0.95) para que solo aplique en VETOs muy claros.

## Principles affected

- **#5 Truth as common good** — La cancelacion no oculta veto; al contrario, lo entrega antes.
- **#3 Reversible** — `SAVIA_TRIBUNAL_EARLY_CANCEL=off` desactiva.
- **#7 Resource efficiency** — Ahorra tokens y latencia sin perder informacion critica.

## Design

### Overview

```
[draft entra a tribunal]
    |
    v
[lanzar 7 jueces en paralelo (background PIDs)]
    |
    | poll cada 200ms:
    |   any judge.veto=true AND judge.confidence>=0.95?
    |   si -> kill demas PIDs, registrar cancelaciones
    |
    v
[agregar verdict con jueces completados + nota "early_cancel: N judges"]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | Modificar `recommendation-tribunal-orchestrator.md` | agent prompt | Anadir logica de poll-and-cancel |
| 2 | `scripts/recommendation-tribunal/early-cancel.sh` | bash script | Cancela PIDs de jueces aun corriendo cuando se cumple threshold |
| 3 | Modificar `aggregate.sh` | extension | Anadir campo `cancelled_judges: [...]` al JSON output |
| 4 | Tests bats `tests/test-tribunal-early-cancel.bats` | tests | Verificar cancelacion + agregacion correcta |

### Contracts

#### Polling logic (orchestrator)

```python
launch_all_judges_async()  # 7 PIDs
while not all_done:
    sleep(0.2)
    completed = collect_completed_judges()
    for judge_result in completed:
        if judge_result.veto and judge_result.confidence >= 0.95:
            cancel_remaining_judges()
            return aggregate(completed_only, early_cancel=True)
    if elapsed > 5.0:
        cancel_remaining_judges()
        return aggregate(completed_only, timeout=True)
```

#### Aggregator

`aggregate.sh` emite ahora:

```json
{
  "verdict": "VETO",
  "veto_judges": ["sycophancy"],
  "cancelled_judges": ["concession", "repetition-truth", "memory-conflict"],
  "early_cancel": true,
  "tokens_saved_estimate": 4500,
  "wall_clock_seconds": 1.4
}
```

### Configuration

```bash
SAVIA_TRIBUNAL_EARLY_CANCEL=on|off            # default on (low-risk optimization)
SAVIA_TRIBUNAL_EARLY_CANCEL_THRESHOLD=0.95    # confidence minima para cancelar
SAVIA_TRIBUNAL_EARLY_CANCEL_POLL_MS=200
```

## Acceptance criteria

1. Modo off: comportamiento actual sin cambios.
2. Modo on + un juez devuelve veto+conf>=0.95 a 1s -> demas jueces cancelados antes de los 5s.
3. Cancelacion por confidence baja: veto+conf=0.7 -> NO cancela, espera a todos.
4. Output JSON incluye `cancelled_judges` array y `tokens_saved_estimate`.
5. Cancelacion respeta jueces shadow (SPEC-192 concession/repetition): no afectan veto, no causan cancelacion.
6. Tests: 4 escenarios (early-veto, no-veto, low-conf-veto, timeout-fallback). 4/4 pass.
7. Latencia mejora medible: en 10 drafts sinteticos con early-veto, p95 wall-clock < 2s (vs 5s sin cancelacion).
8. Token saving estimate >= 50% en escenarios early-veto.

## Out of scope

- Cancelacion mid-juez (interrumpir un juez ya escribiendo): demasiado complejo, no rentable.
- Cancelacion por consensus PASS: si los 4 primeros jueces dicen PASS con confianza alta, podriamos cancelar; mas riesgoso (los ultimos pueden detectar issue) - dejar para spec sucesora si los datos lo justifican.

## Dependencies

- Related: SPEC-125, SPEC-192. Compatible con SPEC-195 (iterative): la primera iteracion puede early-cancel; las siguientes tambien.

## Migration path

| Semana | Estado |
|---|---|
| 1 | Implementar + tests. Modo off. |
| 2 | Activar default. Telemetria 30d. |
| 8 | Revisar: tokens saved totales, falsos positivos (cancelaciones que perdieron evidencia util). |

## Reference code

Patron Gemma (`_sampler.py`):

```python
flax struct dataclass decorator
class _WhileLoopCarry:
    step: Int['']
    canvas: Tokens
    done: Bool['B']  # mascara per-batch

# En el body_fn:
canvas = jnp.where(carry.done[:, None], carry.canvas, out.sampled_tokens)
# Done elements NO se actualizan, sus outputs se descartan.
```

Adaptacion bash:

```bash
# Lanzar jueces como PIDs
declare -A JUDGE_PIDS
for judge in "${JUDGES[@]}"; do
  invoke_judge "$judge" "$draft" > "$tmp/$judge.json" &
  JUDGE_PIDS[$judge]=$!
done

# Poll
while [[ ${#completed[@]} -lt ${#JUDGE_PIDS[@]} ]]; do
  for judge in "${!JUDGE_PIDS[@]}"; do
    if [[ -f "$tmp/$judge.json" ]] && ! is_completed "$judge"; then
      mark_completed "$judge"
      verdict=$(jq -r '.veto' "$tmp/$judge.json")
      conf=$(jq -r '.confidence' "$tmp/$judge.json")
      if [[ "$verdict" == "true" ]] && awk -v c="$conf" 'BEGIN{exit !(c>=0.95)}'; then
        # Cancel remaining
        for other in "${!JUDGE_PIDS[@]}"; do
          if ! is_completed "$other"; then
            kill -TERM "${JUDGE_PIDS[$other]}" 2>/dev/null || true
            CANCELLED+=("$other")
          fi
        done
        break 2
      fi
    fi
  done
  sleep 0.2
done
```

## Impact statement

Optimizacion sin riesgo. Los VETOs claros se entregan ~3-4 segundos antes. ~50% reduccion de tokens en escenarios donde un juez detecta harm rapido. No cambia logica de decision; solo evita trabajo redundante.

Origen: patron `done: Bool['B']` en DiffusionGemma `_sampler.py`.

## OpenCode Implementation Plan

**Classification**: Tier 1 (optimizacion, no nueva funcionalidad).

### Phase 1 — Implementation (semana 1)

1. Crear `scripts/recommendation-tribunal/early-cancel.sh`.
2. Modificar orchestrator agent prompt para usar polling.
3. Extender `aggregate.sh` con campo `cancelled_judges`.
4. Tests bats: 4 escenarios.

### Phase 2 — Pilot + activacion (semana 2)

5. Default ON tras tests verdes.
6. Telemetria a `output/tribunal-early-cancel.jsonl`.
7. Documentar en CHANGELOG.

### Acceptance criteria mapping

| AC | Phase | Verifier |
|---|---|---|
| 1-7 | 1 | bats |
| 8 | 2 | telemetria + manual |

### Risks

- **PID killing en macOS vs Linux**: signal handling consistente. Mitigacion: `kill -TERM` con fallback `kill -9` tras 1s.
- **Race condition entre poll y juez completando**: el `[[ -f file ]]` puede fallar si juez aun escribiendo. Mitigacion: usar `flock` o lockfile temporal.
- **Falsos positivos cancelados**: juez correcto cancela uno que detectaria issue distinto. Mitigacion: telemetria mide ratio; si > 5%, threshold sube a 0.98.
