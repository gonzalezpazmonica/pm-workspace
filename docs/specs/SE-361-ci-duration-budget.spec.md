# SE-361 — Presupuesto de tiempo de CI: hardening orientado a velocidad

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** CI/CD / Rendimiento
**Fuente de inspiración:** Anthropic AI-Native SDLC Playbook (cronometrar el pipeline; tratar como prioridad si supera ~5 min)
**Criterio humano aplicable:** CRIT-001

---

## Objetivo

Establecer un **presupuesto de tiempo de CI** explícito y orientado a velocidad:
medir la duración del pipeline por job, alertar cuando un job supere el umbral
(~5 min como default), y publicar un informe de cuellos de botella de CI. El
objetivo es que el CI no sea el bottleneck del "costo por cambio aceptado"
(SE-360).

## Contexto

El playbook de Anthropic recomienda cronometrar el pipeline y tratar como
prioridad cualquier etapa que supere ~5 minutos. Verificado en Savia:
`SE-260` (blast-radius / gentle-patterns) es **hardening de seguridad**, no de
velocidad. `hook-latency-budget.sh` existe pero mide hooks, no jobs de CI. El
gap: no hay medición sistemática del tiempo de CI por job ni alerta por umbral.
Sin esta métrica, SE-360 no puede atribuir el coste de aceptación a la etapa CI.

**Rechazo explícito (CRIT-001):** medición local vía `gh run view` y logs locales;
sin dashboard cloud.

## Diseño

### 1. Medidor `scripts/ci-duration.sh`

- Lee runs de CI recientes (via `gh run list` con el PAT local, o desde logs)
- Calcula por job: duration, p50/p95 sobre ventana rodante (14 días)
- Compara contra presupuesto (`CI_TIME_BUDGET_MIN=5` default)

### 2. Alerta y reporte

- Job > presupuesto → entry en `data/ci-duration/alerts.jsonl` (metadata-only)
- Informe: `output/research/ci-duration-{date}.md` con los top-10 jobs lentos
- Estado semanal: media de CI, % de runs bajo presupuesto, tendencia

### 3. Integración con SE-360

- SE-360 consume `ci-duration` para descomponer la etapa `ci` del acceptance-cost

## Criterios de aceptación

- **AC-0** Medidor calcula duration por job (test con dataset sintético de gh run)
- **AC-1** Detecta job > presupuesto y lo loggea en alerts.jsonl
- **AC-2** Reporte markdown con top-10 jobs lentos
- **AC-3** p50/p95 sobre ventana rodante correctos
- **AC-4** Config inválida → fail-closed (no alerta falsa)
- **AC-5** Sin red obligatoria: si `gh` no disponible, lee cache local

## OpenCode Implementation Plan

### Bindings touched
- `scripts/ci-duration.sh` (nuevo), `scripts/ci-duration-agg.py` (nuevo)
- `data/ci-duration/` (nuevo, gitignored runtime)
- Alimenta SE-360

### Verification protocol
```bash
bats tests/bats/test-ci-duration.bats
bash scripts/ci-duration.sh --days 7 --format json
```

### Portability classification
- Bash + python3 stdlib; `gh` opcional con cache local; portable

## Validación (ejecutada en esta sesión)

- `scripts/ci-duration-agg.py`: duración por job, p50/p95, detección de over-budget (5min default); 5 pytest + 4 bats verdes
- `scripts/ci-duration.sh`: wrapper (markdown/json, --offline con cache local)
- Consumido por SE-360 (etapa `ci` del acceptance-cost)

## Referencias
- Anthropic: claude.com/blog/the-ai-native-sdlc-playbook (CI como bottleneck)
- Savia: SE-260 (hardening seguridad, no velocidad), SE-360, CRIT-001
