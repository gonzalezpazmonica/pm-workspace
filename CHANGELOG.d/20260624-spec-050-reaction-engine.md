## SPEC-050 — Reaction Engine SDD (2026-06-24)

### Added
- `scripts/sdd-reaction-engine.py`: declarative SDD pipeline reaction engine
- Handles 9 events: spec-approved, pr-created, tests-failed, review-done, ci-failed,
  changes-requested, approved-and-green, agent-stuck, merge-conflicts
- Output JSON: `{event, action, auto, retries_allowed, escalate_after, message, source}`
- `approved-and-green` is always `auto: false` (autonomous-safety.md Rule #5)
- `.opencode/reaction-rules.yaml`: default declarative rules file (YAML override support)
- Minimal YAML parser built-in (works without PyYAML installed)
- `tests/scripts/test_sdd_reaction_engine.py`: 10 pytest tests covering all events, safety rules, overrides
