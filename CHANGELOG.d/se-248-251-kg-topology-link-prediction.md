# SE-248..251 — KG Topology + Link Prediction + Agent Rotation + Pre-Tribunal Gates

**Date:** 2026-06-30
**Spec:** SE-248, SE-249, SE-250, SE-251
**PR:** #891

## Added

- `scripts/kg-topology-analysis.py` + `.sh` — Forman-Ricci curvature, Leiden community detection, spectral health analysis for the Savia knowledge graph
- `scripts/kg-link-prediction.py` + `.sh` (SE-249) — RotatE-inspired link prediction using numpy only; no external ML deps
- `scripts/detect-token-exhaustion.sh` (SE-250) — detects token exhaustion vs logic errors in agent iteration logs; drives tier escalation
- `scripts/pre-tribunal-gates.sh` (SE-251) — cheap pre-flight gates before expensive tribunal runs (syntax, size, confidence threshold)
- `overnight-sprint/SKILL.md` — Token Exhaustion Recovery table (SE-250): fast→mid→heavy tier escalation on token limit hits
- `tests/test-se248-kg-topology.bats`, `test-se249-link-prediction.bats`, `test-se250-agent-rotation.bats`, `test-se251-pre-tribunal-gates.bats` — 4 test suites
