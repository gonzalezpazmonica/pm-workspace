## SE-040 — Agent Degradation Canary (2026-06-24)

### Added
- `scripts/agent-degradation-canary.sh`: 3-canary behavioral regression detector:
  1. `router-mode-classifier.py` "ver sprint" → must return `mode1`
  2. `semantic-fault-handlers.py` "timeout after 30s" → must return `TRANSIENT`
  3. `glm-validate.sh` → must exit with code 0 or 1 (never 2/crash)
  - Output: `{total: 3, passed: N, failed: [...], degraded: bool}`
  - Flags: `--json`, `--quiet`
  - Exit 0 (all pass), exit 1 (any fail / degraded)
- `tests/bats/test-se-040-canary.bats`: 8 tests covering script syntax, all-pass scenario, JSON structure, total/passed/degraded fields, quiet mode, text output canary names

### Design
- Zero new instrumentation: probes existing deterministic scripts
- Canary 1 uses stdin pipe (router-mode-classifier reads from stdin)
- Canary 3 uses exit-code heuristic (PASS=0, WARN=1, FAIL=2)
- Extendable: add canaries by appending to CANARY_* arrays
