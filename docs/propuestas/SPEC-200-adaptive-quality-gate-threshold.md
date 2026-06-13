---
status: PROPOSED
---

# SPEC-200 — Adaptive Quality Gate Threshold

> **Priority:** P3 · **Estimate (human):** 2-3d · **Estimate (agent):** 2-3h · **Category:** standard · **Type:** calibration

> **Dual estimate**: 2-3 dias humano (telemetria + calibrador + tests). 2-3h agente.

## Objective

SPEC-055 quality gate hoy usa **threshold fijo**: tests con score < 80/100 fallan el CI. Esto produce dos efectos no deseados:

1. **Falsos negativos**: un test bien escrito en un dominio sutil puntua 78 (estructura impecable, edge cases dificiles) y bloquea CI mientras que tests triviales con score 82 pasan sin problema.
2. **Falsos positivos**: tests escritos para passar el auditor (mucho boilerplate de seguridad sin substancia) puntuan 95 pero realmente cubren poco.

DiffusionGemma usa `SampleFromPredictions` con `entropy_bound`: ordena tokens por entropia y **acepta los k tokens cuya entropia acumulada esta bajo el bound**. Es decision **proporcional a la confianza del set**, no a un threshold absoluto.

Aplicacion a Savia: si el set de tests de un modulo tiene scores promedio 85, el outlier al 78 destaca y debe rechazarse. Si todos rondan 75-85 (modulo nuevo, nadie ha optimizado tests aun), el threshold se baja al p25 con warning.

Trade-off honesto: el threshold absoluto 80 es **simple, predecible, gameable**. El adaptativo es **mas justo, complejo, dificil de explicar**. Si los falsos positivos/negativos del actual son bajos (telemetria), no merece la pena cambiar. Si son altos, si.

## Principles affected

- **#5 Truth as common good** — Threshold proporcional refleja la realidad del modulo mejor que un numero magico.
- **#3 Reversible** — `SAVIA_QUALITY_GATE_ADAPTIVE=off` revierte al threshold fijo SPEC-055.
- **#7 Resource efficiency** — Reduce CI fails por outliers irrelevantes.

## Design

### Overview

```
[CI Test Quality Gate]
    |
    v
[Audit todos los tests del PR]
    |
    v
[Calcular distribucion de scores en el PR]
    |   mean=85, stddev=8
    |
    v
[Threshold adaptativo:]
    |   if mean >= 85: threshold = max(80, mean - 1.5*stddev)
    |   if mean < 85:  threshold = mean - 0.5*stddev
    |   floor: 60 (nunca menos)
    |   ceil: 90 (nunca mas)
    |
    v
[Tests bajo threshold -> FAIL, otros -> PASS]
[Banner: "threshold adaptativo: 78 (mean=85, stddev=8)"]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/quality-gate-adaptive.py` | py script | Calcula threshold adaptativo |
| 2 | Modificar `ci-test-quality-gate.sh` | extension | Llama al adaptativo si SAVIA_QUALITY_GATE_ADAPTIVE=on |
| 3 | `output/quality-gate-history.jsonl` | telemetria | Logea threshold elegido + razones cada PR |
| 4 | Tests pytest `tests/scripts/test_quality_gate_adaptive.py` | tests | Casos boundary + comparacion fijo vs adaptativo |
| 5 | `docs/rules/domain/quality-gate-adaptive.md` | rule | Cuando aplica el adaptativo, floor/ceil, override manual |

### Contracts

#### Adaptive threshold formula

```python
def adaptive_threshold(scores: list[int],
                       fixed_min: int = 80,
                       floor: int = 60,
                       ceil: int = 90) -> tuple[int, dict]:
    """Returns (threshold, debug_info).

    Strategy:
    - If high mean (>=85): use mean - 1.5*stddev, but never below fixed_min.
      Outliers in good sets fail.
    - If low mean (<85): use mean - 0.5*stddev. Tolerate weaker tests in
      modules being onboarded; emit WARN.
    - Always clamp to [floor, ceil].
    """
    if not scores:
        return fixed_min, {"reason": "no_scores"}
    n = len(scores)
    mean = sum(scores) / n
    if n > 1:
        var = sum((s - mean) ** 2 for s in scores) / (n - 1)
        stddev = var ** 0.5
    else:
        stddev = 0.0

    if mean >= 85:
        t = max(fixed_min, int(mean - 1.5 * stddev))
        strategy = "high_mean_strict"
    else:
        t = int(mean - 0.5 * stddev)
        strategy = "low_mean_tolerant"

    t = max(floor, min(ceil, t))
    return t, {
        "strategy": strategy, "mean": round(mean, 1),
        "stddev": round(stddev, 1), "n_scores": n
    }
```

#### CLI

```bash
python3 scripts/quality-gate-adaptive.py --scores 85 92 78 88 95 81     --fixed-min 80 --floor 60 --ceil 90
# Output:
# {"threshold": 80, "strategy": "high_mean_strict", "mean": 86.5, "stddev": 6.5, "n_scores": 6}
```

#### Override manual

Para casos donde el adaptativo no es apropiado (modulo critico que SIEMPRE debe pasar 80), permitir override:

```yaml
# .quality-gate-overrides.yaml
- file: tests/security/test-pii-leak.bats
  strategy: fixed
  threshold: 90
- file: tests/scripts/test_critical_path.py
  strategy: fixed
  threshold: 85
```

### Configuration

```bash
SAVIA_QUALITY_GATE_ADAPTIVE=on|off              # default off durante pilot
SAVIA_QUALITY_GATE_FIXED_MIN=80                 # nunca menos en modo strict
SAVIA_QUALITY_GATE_FLOOR=60                     # nunca menos absoluto
SAVIA_QUALITY_GATE_CEIL=90                      # nunca mas
SAVIA_QUALITY_GATE_OVERRIDES_FILE=.quality-gate-overrides.yaml
```

## Acceptance criteria

1. Adaptive off: threshold = 80 (comportamiento actual SPEC-055).
2. Adaptive on, scores `[85,92,78,88,95,81]` (mean 86.5): threshold = 80 (fixed_min wins; mean-1.5*sd ~ 76 < 80).
3. Adaptive on, scores `[88,90,92,89,87,91,85,93,89,88]` (mean 89.2, stddev 2.4): threshold = 85 (mean - 1.5*sd ~ 85.6, clamped). Outliers fall.
4. Adaptive on, scores `[72,68,75,70,73]` (mean 71.6): threshold = 71 (mean - 0.5*sd, low_mean_tolerant).
5. Floor: scores `[40,45,42]` -> threshold = 60 (floor).
6. Ceil: scores `[95,98,99,97]` -> threshold = 90 (ceil).
7. n=1: threshold = fixed_min (no stddev posible).
8. Empty: threshold = fixed_min.
9. Overrides: file en YAML override list aplica threshold fijo, ignora adaptativo.
10. Telemetria: cada decision logea strategy + mean + stddev + threshold to JSONL.
11. Tests: 12+ casos boundary.
12. CI integration: `ci-test-quality-gate.sh` con adaptive on, tests aleatorios pasan o fallan segun threshold computado correctamente.

## Out of scope

- Aplicar adaptativo a otros gates (security, coverage). Solo SPEC-055 test quality.
- Aprender thresholds optimos via ML. Heuristica simple suficiente.
- Threshold por dominio (auth tests vs UI tests). Si surge necesidad, otra spec.

## Dependencies

- Related: SPEC-055 (extiende su gate).

## Migration path

| Semana | Cambio |
|---|---|
| 1 | Componentes 1-5. Modo off. |
| 2 | Activar en 1-2 PRs piloto. Comparar con threshold fijo. |
| 4 | Telemetria 4 semanas: cuantos PRs cambian veredicto, falsos positivos. |
| 8 | Si datos respaldan, promover a default. Si neutral, mantener off como opt-in. |

## Reference code

Patron Gemma `SampleFromPredictions`:

```python
def __call__(self, denoiser_logits, ...):
    log_probs = jax.nn.log_softmax(denoiser_logits)
    probs = jnp.exp(log_probs)
    token_entropy = -jnp.sum(log_probs * probs, axis=-1)

    sorted_index = jnp.argsort(token_entropy, axis=-1)
    sorted_entropy = jnp.take_along_axis(token_entropy, sorted_index, axis=-1)
    accumulated_entropy = jnp.cumsum(sorted_entropy, axis=-1)

    # Accept k tokens where accumulated stays under entropy_bound
    sorted_selection_mask = (accumulated_entropy - sorted_entropy) <= self.entropy_bound
```

Adaptado: en lugar de threshold absoluto, **decision proporcional a la confianza del set entero**.

## Impact statement

Calibracion. Beneficio modesto pero real: PRs con tests buenos en promedio + 1 outlier fallan correctamente; PRs con tests todos mediocres no se sancionan injustamente. Implementacion conservadora con floor/ceil para evitar surprises.

Riesgo principal: gameable distinto. Si un dev sabe que el threshold es adaptativo, podria escribir 1 test super bueno + 5 mediocres y promediar. Mitigacion: el adaptativo NO sustituye al threshold fixed_min en modo strict; outliers en good sets siguen fallando.

Origen: patron `entropy_bound` proporcional en `SampleFromPredictions` de DiffusionGemma.

## OpenCode Implementation Plan

**Classification**: Tier 1 (calibracion).

### Phase 1 — Helper + tests (semana 1)

1. `scripts/quality-gate-adaptive.py` con CLI y formula.
2. Tests pytest 12+ casos.

### Phase 2 — Integracion CI (semana 2)

3. Modificar `ci-test-quality-gate.sh` para llamar al adaptativo si flag.
4. Soporte de overrides YAML.

### Phase 3 — Telemetria + pilot (semana 3-4)

5. Logear cada decision en JSONL.
6. Activar en piloto.
7. Medir delta entre fixed y adaptativo en PRs reales.

### Phase 4 — Decision (semana 8)

8. Si datos respaldan, promover a default.
9. Si neutral, mantener opt-in.

### Risks

- **Threshold adaptativo confunde dev**: "por que ayer paso y hoy no?". Mitigacion: banner explicativo en CI output con strategy + mean + stddev. Devs entienden la formula.
- **Game el promedio**: como en SPEC-055 actual, el auditor sigue verificando criterios per-test. El adaptativo solo decide threshold, no scores individuales.
- **Floor 60 demasiado laxo**: tests con score 60 son malos. Mitigacion: el WARN logea como `low_mean_tolerant`; revisar cada N en backlog.
