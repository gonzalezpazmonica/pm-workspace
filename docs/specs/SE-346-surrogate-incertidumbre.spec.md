# Spec: SE-346 — Modelo Sustituto con Incertidumbre (SmartSim): decidir cuándo confiar en lo barato vs ejecutar lo caro

**Task ID:**        SE-346
**PBI padre:**      SE-346 — Aprender de `rainvare/modelo-del-mundo` (SmartSim Active Learner)
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-25
**Creado por:**     Savia (ciclo nocturno; estudio de repo externo por petición de la operadora)
**Estado:**         PROPOSED

**Developer Type:** agent-single
**Asignado a:**     python-developer (surrogate + adquisición) + typescript-developer (integración OpenCode)
**Estimacion:**     S 3h (agente)

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 3 h |
| Human effort | 1 h (revisión) |
| Review effort | 30 min |
| Context risk | low |
| Agent-capable | yes |

---

## 1. Contexto y Objetivo

**Fuente del aprendizaje**: `https://github.com/rainvare/modelo-del-mundo`
(SmartSim Active Learner, prototipo Python, ~560 LOC, MIT).

El repo implementa un **modelo sustituto (Proceso Gaussiano)** que aprende de
las simulaciones ya ejecutadas y estima **su propia incertidumbre** en cada
predicción. Un **bucle de aprendizaje activo** usa esa incertidumbre para
decidir en cada iteración si conviene confiar en la predicción **barata** del
modelo o si hace falta ejecutar el **simulador real (caro)**.

Resultados del prototipo sobre Branin:
- **~65% menos simulaciones reales** para el mismo error que muestreo aleatorio.
- **94.7% de las predicciones dentro de μ ± 2σ** (incertidumbre calibrada).
- Funciones de adquisición: UCB, EI, PI, varianza pura (`smartsim/acquisition.py`).
- Orquestador: muestreo inicial LHS → fit GP → adquisición → decisión
  (`smartsim/orchestrator.py`), con parada por `uncertainty_stop_threshold`.

### Aplicabilidad a Savia (pm-workspace)

Savia tiene **múltiples pares "caro/barato"** donde hoy se decide por
heurística fija o por coste explícito, sin incertidumbre calibrada:

| Par caro/barato | Decisión actual | Con SE-346 |
|---|---|---|
| Modelo LLM caro (heavy/opus) vs barato (flash/haiku) | escalado por fallo (`CLAUDE_MODEL_FAST→MID→AGENT`) | elegir por incertidumbre de la tarea, no por fallo |
| Suite de tests completa vs subset | `test-runner` corre todo | predictor de riesgo por fichero decide subset |
| Descomposición de PBI (cara) vs estimación directa | `pbi-decomposition` siempre | estimador con incertidumbre: si GP está seguro, no descomponer |
| `feasibility-probe` (caro) vs análisis estático | probe siempre | confiar en análisis si el surrogate está calibrado |
| Digestión de documento completa vs preview | digest siempre | decidir si el documento merece pipeline completo |

**Objetivo**: implementar el **núcleo del patrón SmartSim** (surrogate GP +
adquisición + orquestador) como librería local y determinista
(CRIT-001: sin red, sin datos a proveedor cloud), y conectarlo a **un** primer
caso de uso piloto — el **routing de modelo LLM por incertidumbre**
(profundamente alineado con SE-089 provider-agnostic, savia-dual y la
escalación de modelo existente).

**Principio rector**: el simulador caro nunca se sustituye por la aproximación;
solo se evita ejecutarlo cuando el modelo sustituto ya está **suficientemente
seguro** (incertidumbre por debajo de umbral). La incertidumbre es parte del
output, no un adorno (radical-honesty: si no estamos seguros, se dice).

## 2. Contrato Técnico

### 2.1 Librería `scripts/surrogate/` (núcleo)

- **`gp_surrogate.py`** — envoltura de `GaussianProcessRegressor` (scikit-learn):
  - `fit(history: list[(features, outcome)])` — normaliza features a [0,1]^d y
    outcome a media 0 / varianza 1.
  - `predict(points) -> (mean, std)` — media + desvío estándar por punto.
  - Kernel: `ConstantKernel × Matern(nu=2.5) + WhiteKernel` (mismo diseño que
    SmartSim; probado calibrado en el repo fuente).
  - Determinista: `random_state=0`.
- **`acquisition.py`** — UCB (`kappa=2.0`), EI (`xi=0.01`), PI (`xi=0.01`),
  `variance` pura. Firmas idénticas a `smartsim/acquisition.py`.
- **`orchestrator.py`** — bucle de aprendizaje activo:
  - Muestreo inicial (Latin Hypercube, `n_initial = max(4, 4*d)`).
  - `max_iterations`, `acquisition`, `minimize`, `n_candidates`, `seed`.
  - `uncertainty_stop_threshold`: corta cuando `max_std < umbral`.
  - Registro por iteración + `summary()` con `{n_real_calls, best, calibración}`.
- **`sampling.py`** — Latin Hypercube (scipy `qmc`) + uniforme para candidatos.
- **`storage.py`** — historial `list[(features, outcome)]` en memoria +
  volcado CSV local (`output/surrogate-*.csv`) si se pide.

Dependencias: `numpy`, `scipy`, `scikit-learn` (ya presentes o en
`requirements-memory.txt`/venv del workspace — verificar antes de instalar;
NO instalar nada nuevo sin confirmación).

### 2.2 Caso piloto — routing de modelo LLM por incertidumbre

- **`scripts/surrogate/llm-router.py`** — decide por tarea si usar modelo
  barato o caro:
  - Features (por tarea): tipo (routing/code/audit/report), nº de ficheros a
    tocar, nº de specs implicadas, tokens estimados del contexto, historial de
    éxito del tipo de tarea.
  - Outcome: coste normalizado de la tarea (tokens consumidos / presupuesto).
  - En runtime: `predict(features_nueva_tarea)` → si `std < threshold_barato`
    → usar `CLAUDE_MODEL_FAST`; si `std ≥ threshold_caro` → escalar a
    `CLAUDE_MODEL_AGENT`; en medio → `CLAUDE_MODEL_MID`. El **fallo sigue
    escalando** (no se sustituye la escalación por fallo, se antecede con
    incertidumbre).
  - Los umbrales se calibran con la **telemetría de éxito** que ya existe
    (`output/turn-sdlc/`, `competence-tracker`).
- **`scripts/surrogate/router-check.sh`** — modo `--check`: reporta para cada
  tipo de tarea qué modelo elegiría el GP y con qué incertidumbre, sin cambiar
  nada (read-only; CRIT-001).

### 2.3 Fuera de alcance (esta S)

- Multi-fidelidad (combinar 2 modelos LLM como "simulador barato + caro").
- Batch acquisition (selección de lotes en paralelo).
- Optimización multi-objetivo.
- Conectar el router al dispatch real (`savia-env.sh` model_alias): solo
  `--check`/report + telemetría en esta S; el switch de modelo activo es otro
  slice (requiere tocar la cadena de arranque de sesión).

## 3. Requisitos Funcionales

- **REQ-01** `scripts/surrogate/gp_surrogate.py` implementa `fit/predict`
  devolviendo `(mean, std)`; determinista con `random_state=0`.
- **REQ-02** `scripts/surrogate/acquisition.py` expone `ucb`, `ei`, `pi`,
  `variance` con registro `REGISTRY` y `get(name)`.
- **REQ-03** `scripts/surrogate/orchestrator.py` ejecuta el bucle completo
  (inicial → fit → adquisición → decisión → parada por umbral) y devuelve
  `(store, surrogate)`.
- **REQ-04** `scripts/surrogate/llm-router.py --check` es read-only y emite
  JSON: para cada tipo de tarea, `{model, std, verdict}`.
- **REQ-05** El piloto se valida contra un **benchmark sintético** (Branin o
  equivalente 2D/6D): el GP debe alcanzar el error del muestreo aleatorio con
  **≥ 40% menos evaluaciones reales** (réplica de la claim del repo, que mide
  65% — exigimos 40% como margen conservador en CI).
- **REQ-06** Calibración: sobre el benchmark, **≥ 85% de las predicciones
  dentro de μ ± 2σ** (el repo mide 94.7%).
- **REQ-07** Telemetría local: `output/surrogate-telemetry.jsonl` con las
  decisiones del router `--check` (nunca fuera del workspace — CRIT-001).
- **REQ-08** Documentación `docs/rules/domain/surrogate-router.md` con el
  patrón, los umbrales, y cómo calibrarlos con telemetría real.

## 4. Criterios de Aceptacion

- **AC-01** Librería `scripts/surrogate/` existe con `gp_surrogate.py`,
  `acquisition.py`, `orchestrator.py`, `sampling.py`, `storage.py`.
- **AC-02** Benchmark sintético: con semilla fija, el GP consigue error del
  muestreo aleatorio con **≥ 40% menos evaluaciones** (AC del REQ-05).
- **AC-03** Calibración: **≥ 85% de predicciones en μ ± 2σ** (REQ-06).
- **AC-04** `llm-router.py --check` emite JSON válido con
  `{model, std, verdict}` por tipo de tarea; sin efectos laterales.
- **AC-05** El código del workspace no hace llamadas de red (CRIT-001) y no
  instala dependencias nuevas sin confirmación (verificado en BATS).
- **AC-06** BATS verdes: `tests/test-surrogate.bats` (mínimo 8 tests):
  - acquisition: UCB prefiere mayor std a media igual; EI=0 sin incertidumbre;
    PI ∈ [0,1]; variance = std.
  - orchestrator: n_initial correcto; parada por umbral; summary shape.
  - benchmark: REQ-05 y REQ-06 numéricos.
  - router `--check`: JSON válido + read-only (no modifica nada).
- **AC-07** Documentación `surrogate-router.md` con umbrales y procedimiento de
  calibración.
- **AC-08** Regresión: `test-opencode-savia-gates-plugin.bats`,
  `test-mind-virus.bats`, `test-opencode-cross-audit.bats` siguen verdes.

## 5. Ficheros a Crear/Modificar

| Fichero | Accion |
|---|---|
| `scripts/surrogate/gp_surrogate.py` | CREAR |
| `scripts/surrogate/acquisition.py` | CREAR |
| `scripts/surrogate/orchestrator.py` | CREAR |
| `scripts/surrogate/sampling.py` | CREAR |
| `scripts/surrogate/storage.py` | CREAR |
| `scripts/surrogate/llm-router.py` | CREAR (piloto, `--check` read-only) |
| `scripts/surrogate/router-check.sh` | CREAR (wrapper bash) |
| `tests/test-surrogate.bats` | CREAR |
| `tests/eval-surrogate-benchmark.py` | CREAR (benchmark numérico) |
| `docs/rules/domain/surrogate-router.md` | CREAR |
| `docs/ROADMAP.md` | MODIFICAR: entrada en Pipeline |
| `output/surrogate-telemetry.jsonl` | CREAR (runtime, local) |

## 6. Test Scenarios

1. **Acquisition unit**: UCB elige el punto de mayor std a media igual.
2. **Acquisition unit**: EI devuelve 0 cuando std=0 (sin incertidumbre → sin mejora esperada).
3. **Orchestrator**: `n_initial` por defecto = `max(4, 4*d)`; el histórico tras
   `run()` tiene `n_initial + iteraciones_activas` entradas.
4. **Parada por umbral**: con `uncertainty_stop_threshold` alto, el bucle corta
   antes de `max_iterations`.
5. **Benchmark**: Branin 2D, seed fija → ≥ 40% menos evaluaciones que aleatorio
   y ≥ 85% en μ±2σ.
6. **Router --check**: JSON con `{model, std, verdict}` por tipo; `git status`
   limpio después (read-only).
7. **CRIT-001**: grep del código → sin `http://`, `requests.`, `urllib`,
   `boto3`, `openai`, `anthropic` en `scripts/surrogate/`.

## 7. Riesgos y limitaciones (honestidad)

- El GP con scikit-learn es una envoltura; la **calidad real depende de los
  datos de telemetría** de cada caso. El benchmark sintético prueba el patrón,
  no la precisión sobre tareas reales.
- El piloto `llm-router` es **solo --check/report** en esta S; no cambia el
  modelo activo en runtime. El cambio de dispatch real requiere otro slice
  (arranque de sesión / `savia-env.sh` model_alias).
- La incertidumbre del GP asume normalidad; los costes de tokens reales pueden
  ser no-gaussianos (colas largas). Mitigación: normalizar outcome y usar
  cuantiles en vez de σ absoluto en el siguiente slice.
- CRIT-001: todo el cómputo es local; la telemetría de calibración vive en el
  workspace. No se envían features de tareas a ningún proveedor.

## 8. Decisiones pospuestas

- Switch real de modelo en runtime (slice 2).
- Multi-fidelidad y batch acquisition (slice 3).
- Integración con `pbi-decomposition`/`feasibility-probe` (slice 4).
- Reemplazar la escalación por fallo con la anticipación por incertidumbre de
  forma completa (coexistirán: fallo como red de seguridad, incertidumbre como
  primera decisión).

## 9. Referencias

- Repo fuente: https://github.com/rainvare/modelo-del-mundo (SmartSim, MIT)
- Patrón: surrogate model + active learning (BO/GP) — Branin benchmark
- Alineación: SE-089 (provider-agnostic), savia-dual, `autonomous-safety.md`
  (escalación de modelo), CRIT-001