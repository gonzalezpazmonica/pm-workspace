## SPEC-163 — Router Modo 1 / Modo 2 (System 1/2 dispatch) (2026-06-24)

### Added
- `scripts/router-mode-classifier.py`: heuristic classifier for System 1/2 dispatch.
  Input: `{intent, command, has_code_change, estimated_tokens}`.
  Output: `{mode, confidence, reason, complexity_tier}`.
  Rules: has_code_change=true → mode2 (confidence 1.0); tokens > 5000 → mode2;
  frontmatter complexity_tier lookup; query pattern matching → mode1;
  action pattern matching → mode2; conservative default → mode2.

- `scripts/_router_extract_helper.py`: internal helper that extracts {intent, command,
  has_code_change, estimated_tokens} from OpenCode hook stdin payload.

- `scripts/_router_telemetry_helper.py`: internal helper that assembles JSONL telemetry
  entries with all required fields for `output/router-decisions.jsonl`.

- `.opencode/hooks/router-mode-dispatch.sh`: PreToolUse hook. Reads SAVIA_ROUTER_MODE
  (off | shadow | enforce, default: shadow). In shadow: classifies + logs, exits 0.
  In enforce: additionally writes hint file for mode1 turns. Always exit 0.

- `complexity_tier: mode1` added to frontmatter of 8 commands:
  sprint-status, my-sprint, my-focus, board-flow, daily-routine,
  savia-live, help, index-compact.

- `complexity_tier: mode2` added to frontmatter of 1 command: savia-shield.

- `output/router-decisions.jsonl`: telemetry log (created at first shadow/enforce invocation).
  Fields: ts, turn_id, session_id, intent_hash, detected_mode, command, confidence,
  tokens_estimate, reason, complexity_tier, mode_enforced.

### Tests
- `tests/scripts/test_router_classifier.py`: 43 pytest tests — all pass.
  Coverage: query/action/code_change/token threshold/confidence/fields/subprocess/
  workspace intents/known commands/conservative default.

- `tests/bats/test-router-mode-dispatch.bats`: 17 BATS tests — all pass.
  Coverage: existence/executable/mode=off/shadow/enforce/set-uo-pipefail/
  fail-soft invalid JSON/telemetry validity/classifier standalone.

### Notes
- Default SAVIA_ROUTER_MODE=shadow (classifies but does not enforce).
  Run `SAVIA_ROUTER_MODE=enforce` to activate mode1 routing.
- Classifier uses stdlib only — no external dependencies.
- 2 weeks shadow period recommended before flipping to enforce (AC from spec).
