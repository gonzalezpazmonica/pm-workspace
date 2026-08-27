---
context_tier: L2
token_budget: 1200
---

# Regla: Surrogate Router — decidir cuándo confiar en lo barato vs ejecutar lo caro

> SE-346 · patrón SmartSim/`rainvare/modelo-del-mundo` (GP + active learning).
> CRIT-001: todo el cómputo es local; la telemetría vive en `output/`.

## Principio

El **simulador caro nunca se sustituye por la aproximación**: solo se evita
ejecutarlo cuando el **modelo sustituto** (Proceso Gaussiano) ya está
**suficientemente seguro** (incertidumbre por debajo de umbral). La
incertidumbre es parte del output, no un adorno (radical-honesty: si no
estamos seguros, se dice).

## Componentes

| Componente | Rol |
|---|---|
| `scripts/surrogate/gp_surrogate.py` | `fit(history)` / `predict(points)->(mean,std)`. Kernel `ConstantKernel×Matern(2.5)+WhiteKernel`, `random_state=0` (determinista). |
| `scripts/surrogate/acquisition.py` | `ucb` (kappa=2.0), `ei` (xi=0.01), `pi`, `variance`; `REGISTRY`+`get(name)`. |
| `scripts/surrogate/orchestrator.py` | Bucle: LHS inicial → fit → adquisición → evaluación real → refit → parada por `uncertainty_stop_threshold`. |
| `scripts/surrogate/sampling.py` | LHS (scipy qmc) + candidatos uniformes. |
| `scripts/surrogate/storage.py` | Historial en memoria + CSV en `output/`. |
| `scripts/surrogate/llm-router.py --check` | Routing de modelo LLM por incertidumbre (read-only). |
| `scripts/surrogate/router-check.sh` | Wrapper (venv python). |

## Decisión del router (piloto)

Para cada tipo de tarea (`routing|code|audit|report`), con features
`[onehot tipo, n_files, n_specs, tokens, success_rate]`:

```
std < threshold_barato (0.10)  -> CLAUDE_MODEL_FAST   (confiar-bajo)
std >= threshold_caro  (0.30)  -> CLAUDE_MODEL_AGENT  (necesita-caro)
resto                           -> CLAUDE_MODEL_MID    (dudoso-mid)
```

- El **fallo sigue escalando** (FAST→MID→AGENT por error). La incertidumbre
  ANTECEDE la escalación, no la sustituye.
- En esta fase el router es **solo `--check`/report**; no cambia el modelo en
  runtime (el switch real es otro slice).

## Calibración (procedimiento)

1. Ejecuta `bash scripts/surrogate/router-check.sh` → JSON por tipo
   (`{model, std, verdict, predicted_cost}`) + telemetría en
   `output/surrogate-telemetry.jsonl`.
2. Acumula historial real: cada tarea completada añade su
   `(features, coste_normalizado)` a `output/surrogate-history.csv`
   (`scripts/surrogate/storage.py` History.to_csv).
3. Re-ajusta umbrales con datos reales si la telemetría muestra que el GP
   sobre/subestima: `SURROGATE_THRESHOLD_BARATO` / `SURROGATE_THRESHOLD_CARO`.
4. Métrica de calibración: fracción de predicciones en μ±2σ sobre el histórico
   (≥85% deseado). El benchmark sintético (Branin) verifica el patrón:
   ≥40% menos evaluaciones reales y ≥85% calibrado (`tests/eval-surrogate-benchmark.py`).

## Uso

```bash
bash scripts/surrogate/router-check.sh                  # report read-only
~/.savia/venv/bin/python tests/eval-surrogate-benchmark.py  # PASS/FAIL numérico
bats tests/test-surrogate.bats                          # 10 tests
```

## Límites (honestidad)

- El GP asume normalidad; los costes de tokens reales pueden ser
  no-gaussianos (colas largas) → mitigar con cuantiles en el siguiente slice.
- El benchmark prueba el patrón, no la precisión sobre tareas reales: calibra
  con telemetría real antes de confiar.
- No sustituye `pbi-decomposition`/`feasibility-probe`; esos pares caro/barato
  son slices posteriores.

## Referencias

- Spec: `docs/specs/SE-346-surrogate-incertidumbre.spec.md`
- Fuente: `rainvare/modelo-del-mundo` (SmartSim, MIT) · Branin benchmark
- Alineación: SE-089 provider-agnostic · savia-dual · CRIT-001
