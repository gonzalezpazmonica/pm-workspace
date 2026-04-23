# Batch 31 — SE-066 review agents finding-vs-filtering

**Date:** 2026-04-23
**Version:** 5.79.0 (batch combinado 31-35)

## Summary

Opus 4.7 follows filter instructions more literally than 4.6. Review agents prompts que decian "only report high-severity" causaban recall drop: el modelo investigaba, encontraba bugs, y los droppeaba en silencio. 19 agents afectados.

## Cambio

`Reporting Policy (SE-066 — coverage-first)` block anadido a 19 agents: code-reviewer, pr-agent-judge, security-judge, correctness-judge, spec-judge, cognitive-judge, architecture-judge, calibration-judge, coherence-judge, completeness-judge, compliance-judge, factuality-judge, hallucination-judge, source-traceability-judge, security-auditor, confidentiality-auditor, drift-auditor, court-orchestrator, truth-tribunal-orchestrator.

El block instruye: reportar cada finding (incluido low-confidence/low-severity) con `{confidence, severity}` attached. Downstream filter rankea.

## Validacion

- `scripts/opus47-compliance-check.sh --finding-vs-filtering`: PASS
- 19/19 agents marcados con `SE-066`
