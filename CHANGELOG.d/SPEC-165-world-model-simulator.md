# SPEC-165 — World-Model Simulation (pre-action)

**Date:** 2026-06-24

## Implementado

- `scripts/world-model-simulator.py`: pre-action simulator generating 3 outcomes
  - `--action TEXT --context TEXT`: describe proposed action
  - Action type classification: edit / create / delete / deploy / read via keyword matching
  - Risk amplifiers: prod, database, credentials, migration, force, etc.
  - Rule violation prediction: Rule #11 (line limit), Rule #20 (PII/credentials), Rule #22 (size)
  - Output JSON: `{action, action_type, risk_score, outcomes: [{scenario, probability, description, reversible}], simulation_confidence, latency_ms}`
  - Telemetry to `output/world-model-predictions.jsonl`
- `tests/scripts/test_world_model_simulator.py`: 8 pytest covering schema, 3 scenarios, probabilities, risk ordering, rule detection, CLI

## Tests: 8 passed
