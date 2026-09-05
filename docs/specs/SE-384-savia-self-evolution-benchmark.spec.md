# SE-384 — Savia Self-Evolution Benchmark

**Estado:** APPROVED — Mónica (operadora), 2026-09-05: "Apruebo todas, implementa, pr y merge"
**Prioridad:** P1 strategic · **Developer Type:** agent-team · **Context Risk:** high
**Origen:** auditoría externa §15 (CONFIRMED — gap real)

## 1. Motivación

Los benchmarks existentes miden otra cosa: `gaia-benchmark-harness.sh` (SPEC-100, asistente genérico), `benchmark-context-pipeline.py` (contexto), `eval-surrogate-benchmark.py` (surrogados). Nada responde la pregunta estratégica del audit (F10): **¿Savia N+1 mejora realmente respecto a Savia N evolucionando Savia?**

## 2. Alcance

Ciclo medido completo: problema → discovery → research → spec → **human approval** → implementation → verification → PR → **human review**. La autoridad humana no se benchmarka: es invariante (cero auto-merge, cero aprobación autónoma).

### Dataset

≥20 tareas históricas reales, versionadas y redactadas de cualquier contenido N3+ (CRIT-001: todo local, jamás a proveedor cloud). Familias: bug de hook · drift documental · agent refactor · skill refactor · nueva rule · eval improvement · cross-frontend change · CI regression · routing issue · memory bug.

### Task schema

```yaml
id:
baseline_commit:
problem:
allowed_evidence:
forbidden_actions:
expected_behavior:
expected_files:
invariants:
risk_level:
evaluation:
```

### Métricas (JSON machine-readable + markdown summary)

- **Outcome**: success rate, first-pass acceptance, regression count.
- **Human dependency**: correcciones humanas, findings de review, intervenciones.
- **Scope**: files changed, out-of-scope, scope violations.
- **Reliability**: CI retries, intentos fallidos, handbacks.
- **Cost**: input/output/cached tokens, tool calls, turns.
- **Safety**: unsafe actions, bloqueos, bypass attempts.
- **SDD quality**: ambigüedad detectada, revisiones de spec, cobertura de aceptación.

### Comparación

Primero **Savia versión A vs B con el mismo modelo**; la dimensión modelo A vs B es separada y posterior. Una modificación arquitectónica solo se declara mejora si gana ≥1 métrica sin degradar significativamente las demás (§15.7).

## 3. Reglas

- Ejecución local; subset económico en PR, suite completa nightly/manual.
- Cero auto-merge; revisión humana como autoridad final.
- Dataset y resultados en el repo (plain-text versionado); datos N3+ redactados antes de versionar.

## 4. Criterios de aceptación

- ≥20 tareas con schema completo y fixtures reproducibles.
- Runner ejecuta el ciclo completo respetando gates (double opt-in, PR draft, grants).
- Baseline inicial versionado + primer informe Savia-N como referencia.
- Feasibility probe previo: runner sobre 3 tareas piloto.

## 5. OpenCode Implementation Plan

### Clasificación
- **Tier:** 2 · **Agent-capable:** yes (feasibility probe = 3 tareas piloto incluidas)
- **Slices:** S1 schema + dataset/ 3 pilotos · S2 run-benchmark.sh (ciclo con gates, local) · S3 métricas JSON+md; dataset ≥20 tareas queda como hito siguiente

## Referencias

- Auditoría externa §15, §22-§24 · SPEC-100 (GAIA, distinto propósito) · SE-374 (auditoría de guardrails como fuente de tareas)
