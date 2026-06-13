---
status: IMPLEMENTED
---

# SPEC-195 — Iterative Tribunal with Multi-Criteria Early Stop

> **Priority:** P1 · **Estimate (human):** 3-4d · **Estimate (agent):** 4-5h · **Category:** standard · **Type:** governance-extension

> **Dual estimate**: 3-4 dias humano (extender orchestrator + scripts de aggregator + early-stop helpers + tests). 4-5h agente con pipeline supervisado.

## Objective

Hoy el Recommendation Tribunal (SPEC-125 + SPEC-192) es **single-pass**: corre los 7 jueces en paralelo, agrega, devuelve verdict. Si el verdict es WARN, el draft llega al humano con banner pero sin auto-refinar.

DiffusionGemma (Google DeepMind, 2026) usa un patron iterativo equivalente para denoising: corre N pasos hasta que `TokenStabilityEarlyStop AND EntropyEarlyStop` convergen, con cap absoluto `max_denoising_steps=48`. Cada paso refina el output usando los hints del paso anterior.

Esta spec adapta ese patron: convertir el tribunal de **evaluador** a **refinador iterativo**. Si verdict WARN, regenerar draft con hints de jueces, volver a juzgar. Para cuando:
- **Token stability**: draft regenerado identico al anterior (`hash(draft_n) == hash(draft_n-1)`).
- **Entropy threshold**: incertidumbre semantica de jueces (variabilidad de scores) cae bajo umbral.
- **Max iterations**: `MAX_TRIBUNAL_ITERATIONS=3` (cap absoluto, evitar costo galopante).

Trade-off honesto: cada iteracion suma ~10-15K tokens (re-genera draft + 7 jueces). 3 iteraciones max = ~45K tokens worst case. Beneficio: drafts WARN auto-resueltos sin intervencion humana cuando convergen rapido. Si no convergen, el banner final muestra que fueron N iteraciones — senal de problema estructural.

## Principles affected

- **#3 Reversible** — `SAVIA_TRIBUNAL_ITERATIVE=off` desactiva. Modo single-pass es el default actual.
- **#5 Humans decide** — En max-iter sin convergencia, el draft llega al humano con todos los intentos visibles, no se oculta el fallo.
- **#9 Transparency** — Cada iteracion deja log auditable.
- **Genesis B9 GOAL STEWARD** — Refinamiento es servicio al proposito, no autonomia.

NO contradice SPEC-125: extiende. NO contradice SPEC-192 (anti-adulation): el iterative loop tambien itera los 3 jueces SPEC-192.

## Design

### Overview

```
[draft inicial]
    |
    v
[Tribunal pass N=0]
    | verdict = PASS  -> entrega
    | verdict = VETO  -> entrega con banner (sin iterar; veto significa harm)
    | verdict = WARN  -> iterar
    v
[regenerate_draft_with_hints(draft, judges_evidence)]
    |
    v
[Tribunal pass N+1]
    | early_stop check: token_stability AND entropy_threshold
    | si stop -> entrega
    | si N >= MAX_ITER -> entrega con banner "no converged"
    v
[continua]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/recommendation-tribunal/iterate.sh` | bash script | Loop controller; invoca tribunal, evalua early-stop, regenera draft |
| 2 | `scripts/recommendation-tribunal/early-stop.py` | py script | Implementa TokenStability + EntropyThreshold + MaxIterations |
| 3 | `scripts/recommendation-tribunal/regenerate-with-hints.sh` | bash script | Construye prompt de re-generacion con evidencia de los jueces |
| 4 | Modificacion `aggregate.sh` | extension | Anade campo `iteration_count` al output JSON |
| 5 | `docs/rules/domain/tribunal-iteration-policy.md` | rule | Cuando iterar, cuando no, cap absoluto |
| 6 | Tests bats `tests/test-tribunal-iterate.bats` | tests | Convergencia, max-iter, no-iter en VETO |

### Contracts

#### Loop controller

```bash
iterate.sh --draft <file> --max-iter 3 --entropy-threshold 0.05
# Outputs JSON:
# { "final_draft": str, "iterations": int, "stop_reason": "stability|entropy|max_iter|veto",
#   "history": [{verdict_n, draft_hash_n, scores_n, ...}] }
```

#### Early-stop heuristics

- **Token stability**: `sha256(draft_n) == sha256(draft_n-1)`. Si, stop.
- **Entropy threshold**: stddev de scores entre los 7 jueces < 0.05 (acuerdo). Si, stop.
- **Max iter**: contador. Hard cap 3.

#### Regeneration

`regenerate-with-hints.sh` toma:
- Draft anterior.
- Output JSON de cada juez (con evidence + reason).

Construye prompt: "Original draft: ... | Judges flagged: J1 said X (evidence: Y), J2 said Z. Regenerate addressing concerns. Do NOT add adulation phrases. Do NOT change frame, only address evidence."

LLM regenera. El nuevo draft entra en la siguiente iteracion.

### Configuration

```bash
SAVIA_TRIBUNAL_ITERATIVE=on|off               # default off durante pilot
SAVIA_TRIBUNAL_MAX_ITERATIONS=3               # hard cap
SAVIA_TRIBUNAL_ENTROPY_THRESHOLD=0.05
SAVIA_TRIBUNAL_TOKEN_STABILITY_HASH=sha256
SAVIA_TRIBUNAL_ITER_LOG=output/tribunal-iterations/<session>.jsonl
```

## Acceptance criteria

1. Single-pass behavior preserved when `SAVIA_TRIBUNAL_ITERATIVE=off`.
2. Iterative mode triggers only on WARN (not PASS, not VETO). Verificado por bats.
3. Token stability stop: dado dos drafts identicos consecutivos, stop_reason=stability. Verificado por pytest.
4. Entropy threshold stop: 7 jueces con scores muy similares (stddev<0.05) -> stop. Verificado por pytest.
5. Max iter stop: 3 iteraciones sin convergencia -> stop_reason=max_iter, banner "no converged". Verificado por bats.
6. VETO no itera: confidence>=0.85 + veto=true -> entrega inmediata.
7. Cada iteracion deja JSONL line con verdict + draft_hash + scores. Verificado por bats.
8. Cost cap: max iter * 7 jueces = 21 invocaciones max por draft. Verificado por counter.
9. Test: 5 drafts sinteticos que requieren 1, 2, 3 iteraciones; convergencia esperada en >=3/5.

## Out of scope

- Iterative tribunal sobre Truth Tribunal (SPEC-106) — solo Recommendation por ahora.
- Auto-merge de drafts diferentes — siempre el ultimo gana.
- Iteracion en VETO — veto significa harm, no se intenta refinar.

## Dependencies

- Blocked by: ninguno.
- Related: SPEC-125, SPEC-192, SPEC-194 (criterion simulation puede beneficiarse del mismo patron).

## Migration path

| Semana | Estado |
|---|---|
| 1 | Componentes 1-6 en modo `off` global. Solo invocable manual. |
| 2 | Activar en `warn` mode para 1-2 specs piloto. |
| 3-4 | Telemetria: medir convergencia rate, coste medio. |
| 5+ | Si convergence_rate > 60%, promover a default ON. |

## Reference code

Patron de Gemma (`_early_stopping.py`):

```python
class ChainedEarlyStop:
    early_stop_fns: Sequence[EarlyStopFn]
    def should_stop(self, **kwargs) -> bool:
        results = [fn.should_stop(**kwargs) for fn in self.early_stop_fns]
        return all(results)  # AND logico
```

Adaptado a Savia:

```python
class TribunalIteration:
    max_iter: int = 3
    entropy_threshold: float = 0.05

    def should_stop(self, history):
        if len(history) >= self.max_iter: return ("max_iter", True)
        if len(history) >= 2 and history[-1].draft_hash == history[-2].draft_hash:
            return ("stability", True)
        if history[-1].score_stddev < self.entropy_threshold:
            return ("entropy", True)
        return (None, False)
```

## Impact statement

Convierte tribunales de evaluadores a refinadores. Drafts WARN que solo necesitan ajuste menor se resuelven sin humano. Drafts WARN estructurales (no convergen) llegan al humano con evidencia visible de los intentos — senal mas rica que un solo banner.

Coste real: 3x tokens por draft WARN. Beneficio esperado: 50-70% de WARNs auto-resueltos en convergencia <=2 iteraciones (estimacion conservadora basada en como evolucionan drafts simples vs estructurales en mi historial).

Origen del patron: DiffusionGemma `_early_stopping.py` (Google DeepMind, 2026).

## OpenCode Implementation Plan

**Classification**: Tier 2.

### Phase 1 — Core (semana 1)

1. Crear `scripts/recommendation-tribunal/early-stop.py` con 3 criterios.
2. Crear `scripts/recommendation-tribunal/iterate.sh` loop controller.
3. Tests pytest del early-stop con 5+ casos por criterio.

### Phase 2 — Regeneracion (semana 2)

4. Crear `scripts/recommendation-tribunal/regenerate-with-hints.sh`.
5. Test con 3 drafts sinteticos que iteran.

### Phase 3 — Integracion + regla (semana 3)

6. Modificar `aggregate.sh` para emitir `iteration_count`.
7. Crear regla `tribunal-iteration-policy.md`.
8. Tests bats end-to-end.

### Phase 4 — Pilot + telemetria (semana 4+)

9. Activar en 1-2 flujos piloto.
10. Recopilar 30d telemetria.
11. Decidir promocion a default.

### Risks

- **Iteraciones costosas sin convergencia**: hard cap 3 evita explosion. Telemetria detectara si ratio max-iter/total > 30% (problema).
- **Regeneracion introduce nuevos issues**: jueces detectan, iteracion siguiente. Si oscila (issue A en iter 1, issue B en iter 2, A otra vez en iter 3) -> max_iter stop, banner muestra historia.
- **Latencia perceived alta**: cada iteracion ~15s. 3 iter = 45s. Aceptable solo en flujos no-conversacionales (PR review, spec validation). Excluir de chat real-time.
