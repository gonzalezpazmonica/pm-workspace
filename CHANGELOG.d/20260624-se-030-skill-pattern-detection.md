## SE-030 — Skill Self-Improvement: Phase 1 (Pattern Detection)

### Added

- `scripts/skill-usage-tracker.py` — Registers each skill invocation in
  `data/skill-invocations.jsonl`. CLI: `--skill NAME --command CMD --session ID`.
  Rolling window: max 1000 entries (oldest trimmed automatically). Reads
  `output/router-decisions.jsonl` for supplemental signals.

- `scripts/skill-pattern-detector.sh` — Analyzes `data/skill-invocations.jsonl` to
  detect repeated command sequences (same sequence of ≥3 commands, ≥3 times across
  last 20 sessions). CLI: `--min-count N --json`. Returns
  `{patterns_found: N, patterns: [{sequence, count, suggestion}]}`.
  Returns `{patterns_found: 0, note: "insufficient data (need >=20 sessions)"}` when
  data is insufficient.

- `tests/scripts/test_skill_detection.py` — 15 pytest tests: tracker appends entry,
  multiple entries, rolling window at 1000, trim over 1000, parent dir creation, required
  fields, detector no-data returns 0, json valid, detects repeated sequence, pattern
  fields present, count >= min, suggestion non-empty, sequence length >= 3, JSON structure.

- `tests/bats/test-spec-se-030-skill-detection.bats` — 10 BATS tests: detector exists,
  JSON output has patterns_found, tracker exists, no-crash with empty data, patterns_found=0
  when no data, tracker appends, entry has required fields, pattern detected with 25 sessions,
  pattern has sequence/count/suggestion, suggestion not empty.

### Scope

Fase 1 (detection) only. Fases 2 (auto-proposal) and 3 (refinement) are
enterprise-only and require explicit human approval before any skill is created
or modified. The existing `scripts/skill-detect.sh` (propose/refine/scan/status
subcommands) remains as the proposal scaffolding layer.

### Status

`SPEC-SE-030`: PROPOSED → IMPLEMENTED (Fase 1 done, Fases 2-3 enterprise-only)
