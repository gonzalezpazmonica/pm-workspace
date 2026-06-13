---
status: PROPOSED
---

# SPEC-197 — Annealing Schedule for Meta-Reflective Judges

> **Priority:** P2 · **Estimate (human):** 2-3d · **Estimate (agent):** 2-3h · **Category:** standard · **Type:** governance-extension

> **Dual estimate**: 2-3 dias humano (aplicar schedule a SPEC-194 + tests). 2-3h agente.

## Objective

DiffusionGemma usa `AnnealingTemperatureShaper`: temperatura empieza alta (T=0.8, exploracion) y termina baja (T=0.4, decision). Formula:

```
factor = 1 - (1 - noise_proportion)^exponent
T = factor * (max - min) + min
```

El proceso de denoising progresa de **estado ruidoso (incertidumbre)** a **estado limpio (decision)**. Temperatura alta al principio explora alternativas; baja al final compromete.

Las 4 meta-preguntas de SPEC-194 (Criterion Simulation Layer) tienen una **estructura analoga**:

| Q | Naturaleza | Temperatura ideal |
|---|---|---|
| Q1 frame challenge | exploracion (existen alternativas?) | alta (T=0.8) |
| Q2 historical priors | recall + relevance ranking | media (T=0.6) |
| Q3 operator state | clasificacion factual (signals) | media-baja (T=0.5) |
| Q4 alternative reframing | decision comprometida | baja (T=0.4) |

Hoy SPEC-194 deja la temperatura por defecto del modelo (~0.7) en las 4 preguntas. **No es bug, es subutilizacion**: la primera pregunta deberia explorar mas; la ultima deberia comprometerse mas.

Esta spec aplica annealing schedule a las 4 meta-preguntas. Aplica el mismo principio a futuros agentes que tengan fases conceptualmente "exploracion -> decision" (ej. tech-research-agent, sdd-spec-writer, dev-orchestrator).

Trade-off honesto: el modelo subyacente (Anthropic Claude) acepta `temperature` 0-1 pero el efecto observable en outputs cortos (~500 tokens del judge) es modesto. La diferencia entre T=0.4 y T=0.8 cambia la creatividad del 5-10%, no del 50%. Es ajuste fino, no cambio drastico.

## Principles affected

- **#5 Truth as common good** — Calibracion explicita es mas honesto que default opaco.
- **#3 Reversible** — Cada agente conserva su default; el schedule es opt-in.

## Design

### Overview

```
Spec invoca SPEC-194 (4 meta-questions)
    |
    v
[Q1 frame challenge]   <- T=0.8 (exploration)
[Q2 historical priors] <- T=0.6 (ranking)
[Q3 operator state]    <- T=0.5 (classification)
[Q4 alternative reframe] <- T=0.4 (decision)
```

Schedule formula configurable:

```python
def schedule(question_index: int, total: int = 4,
             max_t: float = 0.8, min_t: float = 0.4,
             exponent: float = 1.0) -> float:
    progress = question_index / (total - 1)  # 0..1
    factor = 1 - (1 - progress)**exponent
    return max_t + factor * (min_t - max_t)
```

`exponent=1` -> linear. `exponent>1` -> drops slow then fast. `exponent<1` -> drops fast then slow.

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/annealing-schedule.py` | py script (stdlib) | Calcula T para (index, total, max, min, exponent) |
| 2 | Modificar `criterion-simulation-judge.md` (SPEC-194) | agent extension | Aplicar schedule a las 4 preguntas |
| 3 | `scripts/agent-temperature-config.json` | data | Config per-agent: cuales aplican schedule, cuales no |
| 4 | `docs/rules/domain/annealing-schedule.md` | rule | Documentar el patron y cuando usarlo |
| 5 | Tests pytest `tests/scripts/test_annealing_schedule.py` | tests | Verificar formula + casos boundary |

### Contracts

#### Schedule helper

```python
# annealing-schedule.py
import argparse, json, sys

def schedule(idx, total, max_t=0.8, min_t=0.4, exponent=1.0):
    if total <= 1: return min_t
    progress = idx / (total - 1)
    factor = 1 - (1 - progress) ** exponent
    return max_t + factor * (min_t - max_t)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", type=int, required=True)
    ap.add_argument("--total", type=int, default=4)
    ap.add_argument("--max-t", type=float, default=0.8)
    ap.add_argument("--min-t", type=float, default=0.4)
    ap.add_argument("--exponent", type=float, default=1.0)
    args = ap.parse_args()
    print(json.dumps({"temperature": schedule(args.index, args.total, args.max_t, args.min_t, args.exponent)}))
```

#### Per-agent config

```json
{
  "criterion-simulation-judge": {
    "use_annealing": true, "phases": 4,
    "max_t": 0.8, "min_t": 0.4, "exponent": 1.0
  },
  "tech-research-agent": {
    "use_annealing": true, "phases": 5,
    "max_t": 0.9, "min_t": 0.3, "exponent": 1.5
  },
  "sdd-spec-writer": {
    "use_annealing": false
  }
}
```

### Configuration

```bash
SAVIA_ANNEALING=on|off                       # default off durante pilot
SAVIA_ANNEALING_CONFIG=scripts/agent-temperature-config.json
```

## Acceptance criteria

1. `schedule(0, 4)` retorna `max_t` (0.8 default).
2. `schedule(3, 4)` retorna `min_t` (0.4 default).
3. `schedule(idx, total)` es monotonicamente decreciente para `exponent>=1`.
4. `total=1` retorna `min_t` (caso degenerado).
5. `exponent=2` produce caida no lineal: `schedule(1, 4) > schedule(1, 4, exponent=1)`.
6. CLI funcional: `python3 scripts/annealing-schedule.py --index 0 --total 4` retorna JSON con T=0.8.
7. SPEC-194 criterion-simulation-judge acepta y aplica la T calculada en cada Q.
8. Config off: el agente usa T por defecto del modelo.
9. Telemetria: cada invocacion del judge logea T usada por Q.
10. Tests pytest: 10 casos cubriendo formula + boundaries + agent integration.

## Out of scope

- Cambiar temperatura de TODOS los agentes (intrusivo). Solo opt-in via config.
- Aprender automatic los exponents optimos (requiere infra de eval grande).
- Schedules no-monotonicos (T sube y baja): no hay caso de uso identificado.

## Dependencies

- Blocks: opcional, mejora SPEC-194.
- Related: SPEC-194 (consumidor primario), SPEC-167 critic-rag (potencial consumidor futuro).

## Migration path

| Semana | Estado |
|---|---|
| 1 | Componentes 1-3 + tests. Modo off. |
| 2 | Aplicar a SPEC-194 en pilot. |
| 4 | Telemetria: comparar quality de SPEC-194 outputs con/sin schedule. |
| 8 | Si mejora medible (decision strength en Q4 mas alta segun jueces externos), promover a default. |

## Reference code

Patron Gemma:

```python
class AnnealingTemperatureShaper:
    config: AnnealingTemperatureShaperConfig

    def __call__(self, logits, noise_proportion):
        temperature_fraction = (
            1.0 - (1.0 - noise_proportion) ** self.config.exponent
        )
        temperature = (
            temperature_fraction * (self.config.max_temperature - self.config.min_temperature)
        ) + self.config.min_temperature
        return logits / temperature[:, None, None]
```

## Impact statement

Calibracion fina. Beneficio modesto pero documentado: las 4 meta-preguntas tienen claramente fases de exploracion (Q1) y compromiso (Q4); usar la misma T para ambas es subutilizar el modelo. Aplicable conceptualmente a otros agentes con fases similares.

Coste: cero en runtime (la formula es trivial). El unico coste es disciplina de configurar bien los `phases` por agente.

Origen: `AnnealingTemperatureShaper` en DiffusionGemma `_sampler.py`.

## OpenCode Implementation Plan

**Classification**: Tier 1.

### Phase 1 — Helper + tests (semana 1)

1. `scripts/annealing-schedule.py` con CLI y unit tests.
2. `tests/scripts/test_annealing_schedule.py` (10 casos).

### Phase 2 — Integracion SPEC-194 (semana 2)

3. Modificar criterion-simulation-judge para invocar schedule entre Qs.
4. `agent-temperature-config.json` con SPEC-194 entry.
5. Tests bats verificando que cada Q usa T distinta.

### Phase 3 — Documentacion (semana 3)

6. Regla `annealing-schedule.md`.
7. Telemetria en `output/annealing-events.jsonl`.

### Risks

- **El modelo no respeta T fina**: en outputs cortos (<500 tok) el efecto puede ser invisible. Mitigacion: telemetria comparara quality scores con/sin schedule en N=50 casos antes de promover.
- **Config fragmentation**: cada agente con su exponent. Mitigacion: empezar con 1-2 agentes; ampliar solo cuando datos respalden.
