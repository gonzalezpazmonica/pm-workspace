# Batch 35 — SE-070 Opus 4.7 eval scorecard proposal + compliance check infra

**Date:** 2026-04-23
**Version:** 5.79.0 (batch combinado 31-35)

## Summary

37 de los 65 agents de Savia corren en `claude-sonnet-4-6`. Algunos beneficiarian de upgrade a opus-4-7 xhigh, otros son legitimos cheap-tier. Sin eval empirica A/B, no se puede discriminar. Batch 35 crea scorecard infrastructure + el script compliance check transversal que valida los 5 batches (SE-066..SE-070).

## Cambios

### A. Propuesta SE-070 publicada
`docs/propuestas/SE-070-opus47-eval-scorecard.md` — priority Baja, effort L 12h deferred. 4 slices definidos:
1. Scorecard scaffolding (script que lista 37 agents con cost delta estimates)
2. Eval matrix template (tests/golden/opus47-calibration/)
3. Playbook (docs/rules/domain/opus47-calibration-playbook.md)
4. Initial eval of 3 candidate agents (business-analyst, drift-auditor, tech-writer)

Deferred execution hasta que batch budget lo permita. Framework reutilizable para Opus 4.8/5.0.

### B. Transversal compliance check
`scripts/opus47-compliance-check.sh` — valida SE-066..SE-070 en un comando. Flags:
- `--finding-vs-filtering` (SE-066)
- `--fan-out` (SE-067 orchestrators)
- `--adaptive-thinking` (SE-067 feasibility-probe)
- `--xml-tags` (SE-068)
- `--context-rot-skill` (SE-069)
- `--json` structured output

### C. BATS tests
`tests/test-opus47-compliance.bats` — 24 tests cubriendo los 5 batches. Isolation test confirma que el script no modifica agents.

## Validacion

- `bash scripts/opus47-compliance-check.sh`: VERDICT PASS, 0 failures
- `bats tests/test-opus47-compliance.bats`: 24/24 PASS
- Readiness check post-cambios: PASS

## Pendiente

- SE-070 slice 4 (initial eval de 3 candidates): deferred, on-demand
- Futuros agents que se creen en opus-4-7 deberian seguir doc canonico `docs/rules/domain/agent-prompt-xml-structure.md`
