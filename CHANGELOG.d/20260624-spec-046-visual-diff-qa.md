## SPEC-046 — Visual Diff QA at Merge Time (2026-06-24)

### Added
- `scripts/visual-diff-merge-check.sh`: PR-scoped before/after visual diff orchestrator
- Gap analysis confirmed: visual-qa-agent handles single-screenshot analysis only;
  no PR-scoped before/after pipeline, storage management, or gate decision existed
- 4-phase pipeline: baseline capture → candidate capture → pixel diff → report + gate
- Pixel diff uses `compare` (imagemagick) when available; falls back to file-size proxy
- Semantic analysis via visual-qa-agent for borderline 2-10% diffs; auto-pass/fail outside
- Score formula: `(pixel * 0.6) + (semantic * 0.4)`; gate: PASS>=90 / REVIEW 60-89 / FAIL<60
- Report output: `output/visual-qa/merge-diff/{pr-id}/report.json` + `report.md`
- `--dry-run` flag skips agent invocation for safe testing
- `tests/bats/test-spec-046-visual-diff.bats`: 7 tests covering validation, pass/fail, reports
