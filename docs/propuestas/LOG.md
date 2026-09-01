<!-- @generated/managed by scripts/spec-lifecycle.sh — append-only -->
<!-- Most recent entries at the top. Format: ## YYYY-MM-DD SPEC-ID STATUS -->
# Specs Lifecycle Log

> Conceptual history of specs in docs/propuestas/. Append-only.
> Each entry: date, spec ID, status transition, optional rationale.
> Ref: SE-222 S1 OKF Adoptable Patterns (log.md convention).

## 2026-08-31 SE-362 APPROVED→IMPLEMENTED
Risk Tiering (origen Anthropic playbook gobernanza ejecutable + modelo Amplitude):
risk-tier.py clasifica cambios T1-T4, push-pr --merge consulta el tier (T3/T4
bloqueado sin review humana aun con grant), doc risk-tiering.md. 7 pytest + 5 bats.

## 2026-08-31 SE-358 APPROVED→IMPLEMENTED
plan.md verificado (origen Anthropic playbook Stage 3/5): plan-validate.py +
plan-diff-check.sh (sync plan↔diff, warn/block). 11 bats verdes.

## 2026-08-31 SE-357 APPROVED→IMPLEMENTED
Control Bands autónomas (origen Anthropic AI-Native SDLC Playbook Stage 6):
detección determinista sin LLM + tiers σ (1σ log, 2σ diagnose, 3σ propose),
control-bands.yaml, historial local, intent/ como re-entrada al pipeline.
12 bats verdes.

## 2026-08-31 SE-356 APPROVED→IMPLEMENTED
Skills Two-Layers (origen OpenClaw VISION): layer core/peripheral en 132 SKILL.md
(peripheral por defecto), skills-registry/INDEX.json + REVIEW.md (criterios de
promoción), skill-layer-check.sh. 8 bats verdes.

## 2026-08-31 SE-352 APPROVED→IMPLEMENTED
Trust-Gated Memory (origen OpenClaw 2.0): origin class owner/agent/untrusted/system
en memory-store, taint de turno vía hook memory-origin-gate.sh, consolidación que
excluye untrusted/system, filtro search --min-origin, audit-origins. 15 bats verdes.

## 2026-08-31 SE-220 IMPLEMENTED
Speculative Tool Execution — S0 feasibility (PROCEED, acceptance_rate=1.00) + Slices 1-4.
Implementado en PR #874 (2026-06-26): predictor heurístico (`speculative-tool-predictor.py`),
orquestador (`speculative-tool-execution.py`), cache con flock+TTL 30s (`speculative-cache-manager.py`),
telemetría JSONL + dashboard (`speculative-telemetry-report.sh`), hooks pre-execute (S2) y
skill-preload (S3) registrados. 39 pytest + 35 bats verdes.

## 2026-06-24 SPEC-182 IMPLEMENTED
Bi-temporal timeline frontmatter on specs and decisions
SPEC-182 implementado: spec-timeline-append.py + spec-timeline-query.py + lifecycle --no-timeline + 10 back-fills + 21 tests

## 2026-06-23 SE-222 PROPOSED (S0 IMPLEMENTED)
OKF Adoptable Patterns — resource: URI + log.md + index.md.
S0 (resource: URI validator + 5 specs back-filled) implementado en PR #850.

## 2026-06-23 SE-220 PROPOSED
Speculative Tool Execution — draft+verify pattern (S0 feasibility BLOQUEANTE).

## 2026-06-23 LOG.md created (SE-222 S1)
Bootstrap entry — fichero creado a partir de este punto.
Nuevas transiciones se añaden al top.
