---
version_bump: minor
section: Added
---

## [6.x.0] — 2026-06-24 — SPEC-151 Evals CI Gate MVP

Implements the evaluation regression framework without external DeepEval/Promptfoo
runtime dependencies. Framework structure, paired-delta logic, datasets, baseline,
runner, and GitHub Actions workflow are all present and tested.

### Added

- `.github/workflows/evals-ci.yaml`:
  - Trigger on PRs to `main` touching `.opencode/skills/`, `.opencode/agents/`, `.opencode/hooks/`
  - Jobs: `deepeval-skills` (pytest + graceful skip if DeepEval absent), `regenerate-baseline` (push to main), `promptfoo-redteam` (nightly only)
  - Paired-delta gate: calls `evals-runner.sh --mock` + delta check, fails PR if any dataset >5% degradation
  - PR comment with delta table; nightly failure opens GitHub issue
  - `SAVIA_EVAL_JUDGE_MODEL` env var for judge model pinning

- `scripts/evals-runner.sh`:
  - Reads `tests/evals/datasets/**/*.jsonl`
  - `--mock` mode: deterministic heuristic scorer (no LLM)
  - Compares against `tests/evals/baselines/*.json` via `evals-paired-delta.py`
  - Output: JSON array `[{dataset, baseline_score, current_score, delta, threshold_pass}]`
  - `--dataset NAME` for single-dataset runs; `--output FILE` for file output

- `scripts/evals-paired-delta.py`:
  - Input: `--baseline` + `--current` (JSON files with `[{id, score}]`)
  - Computes: `mean_delta, std_delta, degradation_count, improvement_count, threshold_pass`
  - Threshold: `SAVIA_EVAL_DELTA_THRESHOLD` env or `--threshold` CLI (default 0.05 = 5%)
  - Exit 0 = pass, exit 1 = degradation detected

- `tests/evals/datasets/skills/pbi-decomposition.jsonl`: 5 real-domain cases (anonimized)
- `tests/evals/datasets/hooks/privacy-shield.jsonl`: 10 pattern-only strings (no real PII)
- `tests/evals/baselines/pbi-decomposition-baseline.json`: 5 baseline scores for tests

### Tests

- `tests/scripts/test_evals_gate.py`: 14 tests covering all paired-delta edge cases,
  runner mock output, dataset/baseline parsing. **14/14 passed**.
- `tests/bats/test-evals-ci-gate.bats`: 6 tests covering runner executable, mock JSON,
  workflow yaml, delta script, datasets dir, delta pass case. **6/6 passed**.

### Acceptance Criteria

- ✅ AC-01: GitHub Action `evals-ci.yaml` triggers on PR changes to skills/agents/hooks
- ✅ AC-02: Runtime <15 min (mock mode — LLM evals skipped gracefully if not installed)
- ⚠  AC-03: 2 datasets present (MVP scope: 5 cases min, not 20; full datasets deferred)
- ✅ AC-04: Baseline regenerated on push to main (job `regenerate-baseline`)
- ✅ AC-05: PR comment with delta table
- ✅ AC-06: Judge model pinned via `SAVIA_EVAL_JUDGE_MODEL` var
- ✅ AC-07: Paired-delta rationale in runner + this changelog (policy doc deferred to Phase 2)
- ✅ AC-08: BATS test validates workflow yaml exists

### Spec ref

SPEC-151 → MVP IMPLEMENTED 2026-06-24.
Status: APPROVED → IMPLEMENTED.
Note: Full dataset sizes (30/20/100/15 cases per spec) and DeepEval/Promptfoo runtime
integration deferred to Phase 2 as documented in `evals-ci-policy.md` (to be written).
