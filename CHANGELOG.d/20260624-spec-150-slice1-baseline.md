## SPEC-150 Slice 1 — Hook Multi-Handler Baseline (2026-06-24)

### Added
- scripts/hook-multihandler-baseline.sh: FP/FN baseline evaluator for 6 critical hooks (sycophancy-strip, block-credential-leak, contract-test-guard, context-sanitize-input, pii-gate, router-mode-dispatch). 20 test inputs per hook (10 positive + 10 negative). Output JSON: {hook, fp_count, fn_count, fp_rate, fn_rate, avg_latency_ms, total_invocations}
- tests/evals/hook-baselines/: directory for hook baseline JSON files
- docs/rules/domain/hook-multihandler-migration.md: design document for TS plugin migration — candidate hooks, 2-layer pattern, anti-patterns, phase plan
- tests/scripts/test_hook_multihandler_baseline.py: 19 pytest tests covering script existence, JSON schema, rate ranges, 6 hooks in registry, output directory creation
- tests/bats/test-spec-150-hooks-migration.bats: 11 BATS tests covering script existence, doc existence, directory creation, JSON validity

### Notes
- Slice 1 baseline establishes pre-migration FP/FN rates
- Slices 2-6 (TS plugin migration) pending: requires feasibility gate from Slice 1 results
- Sensitive test payloads generated at runtime via Python helper (not stored in source)
