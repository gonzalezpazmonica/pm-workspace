# Enterprise Batch 4 — Project Lifecycle (SE-014..SE-022)

**Date:** 2026-06-24

## Specs implemented

| Spec | Title | Tests |
|------|-------|-------|
| SE-014 | Release Orchestration | 12 |
| SE-015 | Project Prospect (Pipeline-as-Code) | 12 |
| SE-016 | Project Valuation (Business-Case-as-Code) | 6 |
| SE-017 | Project Definition (SOW-as-Code) | 12 |
| SE-018 | Project Billing (IFRS 15) | 9 |
| SE-019 | Project Evaluation (Lessons-as-Code) | 7 |
| SE-020 | Cross-Project Dependencies | 7 |
| SE-022 | Resource Bench Management | 11 |

**Total: 76 tests, 76 passing (100%)**

## Scripts created (13 files)

- `scripts/enterprise/release-create.sh` — Release-as-Code: crea release con compliance profile
- `scripts/enterprise/release-gate-check.sh` — Verifica gates de release, output JSON
- `scripts/enterprise/prospect-create.sh` — Crea prospect/oportunidad de venta
- `scripts/enterprise/prospect-pipeline.sh` — Vista pipeline de prospects con filtro por stage
- `scripts/enterprise/project-valuation.sh` — NPV/IRR/payback/risk-adjusted con WACC configurable
- `scripts/enterprise/sow-create.sh` — Statement of Work con templates basic|agile|fixed-price
- `scripts/enterprise/sow-validate.sh` — Valida secciones requeridas del SOW, JSON output
- `scripts/enterprise/billing-milestone.sh` — Registra milestone IFRS-15 en billing.jsonl
- `scripts/enterprise/billing-report.sh` — Informe de facturación por proyecto/tenant
- `scripts/enterprise/project-evaluation.sh` — Post-mortem: lee billing.jsonl + sow.md, genera evaluation.md
- `scripts/enterprise/dep-graph.sh` — Grafo de dependencias cross-proyecto en JSON
- `scripts/enterprise/bench-register.sh` — Registra recurso en bench con skills y disponibilidad
- `scripts/enterprise/bench-match.sh` — Matching de skills con skills_match_pct y threshold

## Test files created (8 files)

- `tests/enterprise/test-se-014-release.bats`
- `tests/enterprise/test-se-015-prospect.bats`
- `tests/enterprise/test-se-016-valuation.bats`
- `tests/enterprise/test-se-017-sow.bats`
- `tests/enterprise/test-se-018-billing.bats`
- `tests/enterprise/test-se-019-evaluation.bats`
- `tests/enterprise/test-se-020-crossdeps.bats`
- `tests/enterprise/test-se-022-bench.bats`

## Status changes

8 specs flipped PROPOSED → IMPLEMENTED.

## Design decisions

- Todos los scripts respetan `REPO_ROOT` env var para permitir tests en tmpdir
- Scripts son air-gap ready: zero dependencias externas, solo bash + awk
- release.yaml checklist adapta items según compliance_profile (basic/eu-ai-act/dora)
- NPV calculado con suma de flujos descontados a WACC; IRR por búsqueda binaria
- billing.jsonl es append-only (IFRS-15 audit trail por construcción)
- dep-graph.sh produce JSON en output/enterprise/ compatible con SE-020 contract
- bench-match.sh respeta equality principles: matching solo por skills, sin atributos personales
