---
spec_id: SPEC-151
title: Evals CI Gate — DeepEval + Promptfoo con paired-delta sobre baseline frozen
status: APPROVED
origin: Investigación 2026-05-23 (P7 + bloque "Evaluation frameworks"). DeepEval + Promptfoo son el combo estándar 2026. Savia tiene `evaluations-framework` skill y `eval-registry.json` pero sin CI gate. Patrón crítico señalado: **paired-delta**, no pass-rate agregado.
severity: Alta — eleva calidad de skills/agents/hooks de "manual smoke" a "regresión automática".
effort: ~24h (M-L) — pipeline + datasets + tests.
priority: P7 — calidad y trustworthiness.
confidence: alta (mecanismo) — media en absorción.
bucket: Q3 2026
related_specs:
  - SPEC-150 (Hooks multi-handler — los hooks `prompt` necesitan evals)
  - SPEC-143 (SKILL.md conformance — habilita evals cross-tool)
---

# SPEC-151 — Evals CI Gate

## Why

Skills, agentes y hooks de Savia cambian regularmente. Hoy:

- BATS valida ESTRUCTURA (frontmatter, paths, file existence).
- Smoke tests manuales validan COMPORTAMIENTO en momentos puntuales.
- Nada valida REGRESIÓN entre versiones — un cambio "aparentemente inocuo" en una skill puede degradar precisión 20% sin disparar señal.

DeepEval + Promptfoo es el combo de facto 2026 para llenar este hueco:

- **DeepEval** (pytest-style, 14+ métricas G-Eval/RAGAS/hallucination/tool-correctness). Integra como `pytest tests/evals/`.
- **Promptfoo** (YAML, 500+ red-team vectores, `--compare baseline.json`, `fail-on-threshold`). Integra como nightly GitHub Action.

**Patrón crítico de 2026 (DeepEval CI docs + Future AGI 2026)**: NO usar pass-rate agregado como gate. Usar **paired-delta** sobre baseline regenerada en cada merge a `main`, pinneando el judge model (claude-opus-4-7) para evitar judge-noise contaminando regresiones.

## Scope

### Funcional

1. **Pipeline `evals-ci.yaml`** (GitHub Action):
   - Trigger: PRs a `main` con cambios en `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, `.opencode/`.
   - Jobs:
     - `deepeval-skills` — pytest sobre skills críticas, métricas tool-correctness + G-Eval custom.
     - `promptfoo-redteam` — red-team contra agentes high-risk (privacy-shield, autonomous-safety) en nightly.
   - Failure mode: paired-delta vs baseline > 5% degradación → fail.

2. **Datasets evaluación**:
   - `tests/evals/datasets/skills/pbi-decomposition.jsonl` — 30 inputs reales (anonimizados).
   - `tests/evals/datasets/skills/voice-inbox.jsonl` — 20 audio inputs.
   - `tests/evals/datasets/hooks/privacy-shield.jsonl` — 100 strings (PII real, look-alikes, edge cases).
   - `tests/evals/datasets/agents/court.jsonl` — 15 PRs históricos.

3. **Baseline storage**:
   - `tests/evals/baselines/{date}/results.json` — resultados de evals sobre `main` HEAD del último merge.
   - Frozen baseline regenerada en `push` a main, NO en PRs. PRs comparan contra el último frozen.
   - Judge model pinneado: `JUDGE_MODEL=claude-opus-4-7@20260501` (snapshot mensual).

4. **DeepEval suite** (`tests/evals/test_skills.py`):
   ```python
   from deepeval import assert_test
   from deepeval.metrics import GEval, ToolCorrectnessMetric

   @pytest.mark.evals
   def test_pbi_decomposition_quality():
       for case in load_dataset("pbi-decomposition"):
           output = invoke_skill("pbi-decomposition", case.input)
           assert_test([
               GEval(name="completeness", criteria="...", threshold=0.8),
               ToolCorrectnessMetric(expected=case.expected_tools, threshold=0.9),
           ])
   ```

5. **Promptfoo config** (`tests/evals/promptfoo.yaml`):
   - 500+ red-team vectores cubriendo prompt injection, secret extraction, PII leak.
   - Targets: skills críticas + agentes.
   - `outputPath: tests/evals/results/promptfoo-{date}.json`.
   - `--compare tests/evals/baselines/{prev}/promptfoo.json --fail-on-threshold=0.95`.

6. **Reporting**:
   - PR comment con tabla "delta vs baseline".
   - Issue auto-abierto si nightly red-team encuentra regresión.

### No funcional

- Coste evals CI <$5/PR (Haiku como judge para tool-correctness, Opus solo para G-Eval cualitativo).
- Tiempo total <15 min por PR.
- Falsos rojo <2% (mediante judge pinned + paired delta).

## Design

### Estructura

```
.github/workflows/
└── evals-ci.yaml

tests/evals/
├── promptfoo.yaml
├── conftest.py                    # pytest fixtures
├── test_skills.py
├── test_hooks.py
├── test_agents.py
├── datasets/
│   ├── skills/
│   │   ├── pbi-decomposition.jsonl
│   │   └── voice-inbox.jsonl
│   ├── hooks/
│   │   └── privacy-shield.jsonl
│   └── agents/
│       └── court.jsonl
├── baselines/
│   └── {YYYY-MM-DD-sha}/
│       ├── deepeval.json
│       └── promptfoo.json
└── results/
    └── {YYYY-MM-DD-sha}/
        └── ...

docs/rules/domain/
└── evals-ci-policy.md             # paired-delta, judge pinning, dataset curation
```

### Política paired-delta

```yaml
gate:
  metric: per-test-delta
  baseline: tests/evals/baselines/latest/
  judge_model: claude-opus-4-7@20260501   # pinned, refresh manual mensual
  thresholds:
    max_per_metric_degradation: 0.05   # 5% peor en cualquier métrica → fail
    max_new_failures: 2                # ≥2 tests que estaban green ahora red → fail
  red_team:
    success_rate_floor: 0.95           # promptfoo debe seguir bloqueando 95%+ vectores
```

## Acceptance Criteria

- [ ] AC-01: GitHub Action `evals-ci.yaml` corre en cada PR a `main` que toca skills/agents/hooks.
- [ ] AC-02: Tiempo total <15 min en runner estándar (Ubuntu latest).
- [ ] AC-03: 4 datasets mínimo (2 skills, 1 hook, 1 agent) con ≥20 cases cada uno.
- [ ] AC-04: Baseline regenerado automáticamente en push a `main` y persistido en `tests/evals/baselines/`.
- [ ] AC-05: PR comment con tabla delta y enlace al artifact de resultados.
- [ ] AC-06: Judge model pinneado en config; refresh mensual documentado.
- [ ] AC-07: Política `docs/rules/domain/evals-ci-policy.md` explica paired-delta y por qué NO pass-rate.
- [ ] AC-08: BATS test `tests/test-evals-ci-config.bats` valida sintaxis de workflow.

## Agent Assignment

- **Capa**: Quality / Infrastructure
- **Agente principal**: `test-runner` + `architect`
- **Skills**: `evaluations-framework` (gestión datasets), `consensus-validation`, `verification-lattice`

## Slicing

- **Slice 1** (5h) — DeepEval suite con 1 skill piloto (pbi-decomposition) + baseline + workflow.
- **Slice 2** (4h) — Resto de datasets (skills + hooks + agent).
- **Slice 3** (5h) — Promptfoo red-team nightly + baseline storage.
- **Slice 4** (4h) — Paired-delta logic + PR comment bot.
- **Slice 5** (3h) — Judge pinning policy + docs + tests.
- **Slice 6** (3h) — Issue auto-abrir en nightly fail + integración con SaviaHub si aplica.

## Feasibility Probe

Slice 1 con `pbi-decomposition`: medir baseline en HEAD actual, introducir un cambio cosmético en la skill, validar que el delta detecta o no detecta degradación esperada. Si el judge-noise es >2% en 5 runs idénticos → escoger otra métrica o ajustar threshold.

## Riesgos

- **Coste API**: 100+ evals × Opus-as-judge sería caro. Mitigación — Haiku judge para tool-correctness (barato), Opus solo para G-Eval cualitativo (~10 tests).
- **Baseline stale**: si nadie mergea a main por semanas, baseline envejece y el judge model puede haber drifted. Mitigación — refresh trimestral forzado del baseline cuando se actualiza judge model.
- **Dataset drift**: inputs realistas para una skill cambian. Mitigación — proceso documentado en `evals-ci-policy.md` para renovar 20% del dataset cada quarter.
- **Promptfoo OpenAI-owned**: aunque MIT, posible cambio de licencia. Mitigación — los datasets son nuestros; si Promptfoo cambia, migrar a deepeval-only o llms-judge propio.
