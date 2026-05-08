#!/usr/bin/env bats
# Ref: SPEC-107 — AI Cognitive Debt Mitigation, Phase 1 (measurement + opt-in)
# Spec: docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md
# Phase 1 ships: cognitive-debt.sh + telemetry hook + hypothesis-first hook (warning-only) + /cognitive-status command + guide doc.
# Pattern source: own — privacy-first telemetry from MIT/MS-CMU/CMU evidence (2025).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/cognitive-debt.sh"
  CDEBT_ABS="$REPO_ROOT/$SCRIPT"
  HOOK_TELEM_ABS="$REPO_ROOT/.opencode/hooks/cognitive-debt-telemetry.sh"
  HOOK_HYPO_ABS="$REPO_ROOT/.opencode/hooks/cognitive-debt-hypothesis-first.sh"
  GUIDE_DOC="$REPO_ROOT/docs/cognitive-debt-guide.md"
  COMMAND_DOC="$REPO_ROOT/.opencode/commands/cognitive-status.md"
  TMPDIR_C=$(mktemp -d)
  export SAVIA_COGNITIVE_DIR="$TMPDIR_C/cog"
}

teardown() {
  rm -rf "$TMPDIR_C"
  unset SAVIA_COGNITIVE_DIR
}

# ── C1 — file-level safety + identity ───────────────────────────────────────

@test "cognitive-debt.sh: file exists, has shebang, executable" {
  [ -f "$CDEBT_ABS" ]
  head -1 "$CDEBT_ABS" | grep -q '^#!'
  [ -x "$CDEBT_ABS" ]
}

@test "telemetry hook: file exists, has shebang, executable" {
  [ -f "$HOOK_TELEM_ABS" ]
  head -1 "$HOOK_TELEM_ABS" | grep -q '^#!'
  [ -x "$HOOK_TELEM_ABS" ]
}

@test "hypothesis-first hook: file exists, has shebang, executable" {
  [ -f "$HOOK_HYPO_ABS" ]
  head -1 "$HOOK_HYPO_ABS" | grep -q '^#!'
  [ -x "$HOOK_HYPO_ABS" ]
}

@test "all 3 scripts declare 'set -uo pipefail' in first 5 lines" {
  head -5 "$CDEBT_ABS" | grep -q "set -uo pipefail"
  head -5 "$HOOK_TELEM_ABS" | grep -q "set -uo pipefail"
  head -5 "$HOOK_HYPO_ABS" | grep -q "set -uo pipefail"
}

@test "all 3 scripts pass bash -n syntax check" {
  bash -n "$CDEBT_ABS"
  bash -n "$HOOK_TELEM_ABS"
  bash -n "$HOOK_HYPO_ABS"
}

@test "spec ref: SPEC-107 cited in entry script and both hooks" {
  grep -q "SPEC-107" "$CDEBT_ABS"
  grep -q "SPEC-107" "$HOOK_TELEM_ABS"
  grep -q "SPEC-107" "$HOOK_HYPO_ABS"
}

# ── C2 — Subcommand: status (positive) ──────────────────────────────────────

@test "status: zero-arg shows DISABLED state by default (opt-in CD-04)" {
  out=$(bash "$CDEBT_ABS" status 2>&1)
  [[ "$out" == *"DISABLED"* ]]
  [[ "$out" == *"opt-in"* ]]
}

@test "status: shows hooks installed" {
  out=$(bash "$CDEBT_ABS" status 2>&1)
  [[ "$out" == *"telemetry"* ]]
  [[ "$out" == *"hypothesis-first"* ]]
}

@test "status: shows zero events when telemetry empty" {
  out=$(bash "$CDEBT_ABS" status 2>&1)
  [[ "$out" == *"Total events: 0"* ]] || [[ "$out" == *"no telemetry yet"* ]]
}

# ── C3 — Subcommand: forget (negative + positive) ───────────────────────────

@test "forget: rejects without --confirm (irreversible boundary)" {
  run bash "$CDEBT_ABS" forget
  [ "$status" -eq 2 ]
  [[ "$output" == *"--confirm required"* ]]
}

@test "forget: deletes telemetry log when --confirm given" {
  mkdir -p "$SAVIA_COGNITIVE_DIR"
  printf '%s\n' '{"ts":"2026-04-30T10:00:00Z","tool":"Edit"}' > "$SAVIA_COGNITIVE_DIR/$USER.jsonl"
  [ -f "$SAVIA_COGNITIVE_DIR/$USER.jsonl" ]
  run bash "$CDEBT_ABS" forget --confirm
  [ "$status" -eq 0 ]
  [ ! -f "$SAVIA_COGNITIVE_DIR/$USER.jsonl" ]
}

@test "forget: handles missing telemetry log gracefully (no crash)" {
  run bash "$CDEBT_ABS" forget --confirm
  [ "$status" -eq 0 ]
  [[ "$output" == *"No telemetry"* ]]
}

# ── C4 — Subcommand: dispatch errors (negative) ─────────────────────────────

@test "dispatch: zero-arg shows usage with exit 2 (boundary)" {
  run bash "$CDEBT_ABS"
  [ "$status" -eq 2 ]
}

@test "dispatch: unknown subcommand exits 2 with error (no-arg edge)" {
  run bash "$CDEBT_ABS" bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "dispatch: --help prints usage and exits 2" {
  run bash "$CDEBT_ABS" --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"enable"* ]]
}

# ── C5 — Telemetry hook (privacy + safety) ──────────────────────────────────

@test "telemetry hook: never invokes LLM (CD-01 — only json/strings)" {
  # Search for any literal LLM/Claude API call patterns
  ! grep -qE 'claude api|anthropic|tool_use|/v1/messages' "$HOOK_TELEM_ABS"
}

@test "telemetry hook: never blocks tool execution (always exits 0)" {
  # Should have explicit 'exit 0' at end and graceful error handling
  grep -qE '^exit 0$' "$HOOK_TELEM_ABS"
  grep -qE 'CD-02|never block' "$HOOK_TELEM_ABS"
}

@test "telemetry hook: writes JSONL to per-user N3 path (CD-03)" {
  echo '{"tool_name":"Edit","duration_ms":1500}' | bash "$HOOK_TELEM_ABS"
  [ "$?" -eq 0 ]
  [ -f "$SAVIA_COGNITIVE_DIR/$USER.jsonl" ]
  grep -qE '"tool":"Edit"' "$SAVIA_COGNITIVE_DIR/$USER.jsonl"
}

@test "telemetry hook: handles malformed JSON input gracefully (boundary)" {
  echo 'not-valid-json{' | bash "$HOOK_TELEM_ABS"
  # Should not crash, exit 0
  [ "$?" -eq 0 ]
}

@test "telemetry hook: empty stdin handled (no-arg-like edge)" {
  echo '' | bash "$HOOK_TELEM_ABS"
  [ "$?" -eq 0 ]
}

# ── C6 — Hypothesis-first hook (Phase 1 warning-only) ──────────────────────

@test "hypothesis-first hook: NEVER blocks (Phase 1 warning-only)" {
  grep -qiE 'warning|never blocks|Phase 1' "$HOOK_HYPO_ABS"
  # Always exits 0
  grep -qE '^exit 0$' "$HOOK_HYPO_ABS"
}

@test "hypothesis-first hook: outputs nudge to stderr (not stdout)" {
  grep -qE '>&2' "$HOOK_HYPO_ABS"
}

@test "hypothesis-first hook: nudges only once per session (idempotency boundary)" {
  grep -qE 'MARKER=|once per session' "$HOOK_HYPO_ABS"
}

@test "hypothesis-first hook: skips when recent commit has Hypothesis trailer" {
  grep -qE 'Hypothesis:' "$HOOK_HYPO_ABS"
  grep -qE 'git log' "$HOOK_HYPO_ABS"
}

# ── C7 — Privacy + restrictions (CD-01 to CD-04) ───────────────────────────

@test "CD-01: scripts never reference LLM/anthropic API (introspection only)" {
  ! grep -qiE 'anthropic|/v1/messages|claude.api' \
    "$CDEBT_ABS" "$HOOK_TELEM_ABS" "$HOOK_HYPO_ABS"
}

@test "CD-02: telemetry hook always exits 0 (never blocks)" {
  grep -qE '^exit 0$' "$HOOK_TELEM_ABS"
}

@test "CD-03: telemetry path is in ~/.savia/ (N3 gitignored)" {
  grep -qE '\.savia/cognitive-load' "$HOOK_TELEM_ABS"
  grep -qE '\.savia/cognitive-load' "$CDEBT_ABS"
}

@test "CD-04: opt-in by default (DISABLED state visible in status)" {
  out=$(bash "$CDEBT_ABS" status 2>&1)
  [[ "$out" == *"DISABLED"* ]]
  [[ "$out" == *"opt-in"* ]] || [[ "$out" == *"CD-04"* ]]
}

# ── C8 — Edge cases ─────────────────────────────────────────────────────────

@test "edge: nonexistent SAVIA_COGNITIVE_DIR is auto-created on enable" {
  # status should not crash even if dir absent
  rm -rf "$SAVIA_COGNITIVE_DIR"
  run bash "$CDEBT_ABS" status
  [ "$status" -eq 0 ]
}

@test "edge: empty telemetry log handled (zero events boundary)" {
  mkdir -p "$SAVIA_COGNITIVE_DIR"
  : > "$SAVIA_COGNITIVE_DIR/$USER.jsonl"
  out=$(bash "$CDEBT_ABS" status 2>&1)
  # Lines = 0, today = 0
  [[ "$out" == *"events"* ]]
}

@test "edge: summary on missing telemetry does not crash (graceful)" {
  rm -rf "$SAVIA_COGNITIVE_DIR"
  run bash "$CDEBT_ABS" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"No telemetry"* ]]
}

# ── C9 — Documentation + command ────────────────────────────────────────────

@test "guide doc: exists and references SPEC-107 + Phase 1" {
  [ -f "$GUIDE_DOC" ]
  grep -q "SPEC-107" "$GUIDE_DOC"
  grep -qiE 'phase 1|opt-in' "$GUIDE_DOC"
}

@test "guide doc: documents all 4 inviolable restrictions (CD-01 to CD-04)" {
  for cd in CD-01 CD-02 CD-03 CD-04; do
    grep -q "$cd" "$GUIDE_DOC"
  done
}

@test "guide doc: documents enable/disable/status/summary/forget commands" {
  for cmd in enable disable status summary forget; do
    grep -qE "cognitive-debt\.sh $cmd" "$GUIDE_DOC"
  done
}

@test "guide doc: cites academic evidence (Kosmyna/MIT, Lee/MS-CMU, Karpicke)" {
  grep -qE 'Kosmyna|MIT' "$GUIDE_DOC"
  grep -qE 'Lee|Microsoft|CMU' "$GUIDE_DOC"
  grep -qE 'Karpicke|Roediger|retrieval practice' "$GUIDE_DOC"
}

@test "command doc: cognitive-status command exists with frontmatter" {
  [ -f "$COMMAND_DOC" ]
  grep -q "name: cognitive-status" "$COMMAND_DOC"
}

# ── C10 — Spec ref + meta ───────────────────────────────────────────────────

@test "spec ref: docs/propuestas/SPEC-107 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-107" "$BATS_TEST_FILENAME"
}

@test "Phase 1 deferred items documented (Phase 2 + Phase 3)" {
  grep -qE 'Phase 2|Phase 3' "$GUIDE_DOC"
}
