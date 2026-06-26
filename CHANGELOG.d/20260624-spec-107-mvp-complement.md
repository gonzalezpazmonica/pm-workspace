---
version_bump: patch
section: Added
---

## [PATCH] — 2026-06-24 — SPEC-107 MVP complement

Adds three artefacts missing from the Phase 1 batch:
- `scripts/cognitive-debt-monitor.py` — CLI scorer (0-100) with JSON output.
- `.opencode/hooks/cognitive-debt-check.sh` — PostTurn session-timer banner.
- `docs/rules/domain/cognitive-debt-protocol.md` — canonical protocol doc citing MIT/MS-CMU.
- `tests/scripts/test_cognitive_debt.py` — 14 pytest tests (all passing).
- `tests/bats/test-cognitive-debt.bats` — 5 BATS tests (all passing).

### Added

- `scripts/cognitive-debt-monitor.py`:
  - Inputs: `--session-hours`, `--tasks-completed`, `--verification-rate`, `--hour-of-day`
  - Scoring: session>4h (+30), verif<0.5 (+25), tasks>15/h+low-verif (+20), hour>20 (+15)
  - Outputs `--json` `{cognitive_load_score, risk_level, recommendations, breakdown}`
  - risk_level thresholds: low/medium/high/critical at 0/26/51/76

- `.opencode/hooks/cognitive-debt-check.sh`:
  - Master switch `SAVIA_COGNITIVE_MONITOR=on|off` (default off — CD-04 opt-in)
  - Session timer via `/tmp/savia-session-start`
  - Threshold `COGNITIVE_DEBT_SESSION_LIMIT` (default 4h)
  - Banner emitted to stderr; always exit 0 (CD-02)

- `docs/rules/domain/cognitive-debt-protocol.md`:
  - Evidence section: MIT Media Lab arXiv 2506.08872, MS/CMU CHI 2025, CMU ICER 2025, Karpicke 2006
  - Alert signals table with thresholds
  - Recommended controls: structured breaks, double-checking, hypothesis-first, weekly retrieval
  - Anti-patterns section
  - Privacy block (CD-03)

### Tests

- `tests/scripts/test_cognitive_debt.py`: 14 tests — score low/high, all risk levels, recommendations,
  CLI --json, required fields, zero-session, critical threshold. **14/14 passed**.
- `tests/bats/test-cognitive-debt.bats`: 5 tests — hook executable, master switch off, protocol doc,
  script JSON output, hook short-session exit 0. **5/5 passed**.

### Spec ref

SPEC-107 → MVP complement IMPLEMENTED 2026-06-24.
Status: APPROVED → IMPLEMENTED (Phase 1 MVP complete).
