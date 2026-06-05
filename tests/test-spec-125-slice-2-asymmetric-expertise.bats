#!/usr/bin/env bats
# Ref: SPEC-125 — Recommendation Tribunal Slice 2 (Asymmetric expertise + audit trail).
# Spec: docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md sections 5 + 8.
# Targets:
#   scripts/recommendation-tribunal/expertise-rewrite.sh
#   scripts/recommendation-tribunal-search.sh
#   .claude/profiles/users/template/expertise.md

setup() {
  set -uo pipefail
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="scripts/recommendation-tribunal/expertise-rewrite.sh"
  REWRITE_ABS="$ROOT_DIR/scripts/recommendation-tribunal/expertise-rewrite.sh"
  SEARCH_ABS="$ROOT_DIR/scripts/recommendation-tribunal-search.sh"
  TEMPLATE_ABS="$ROOT_DIR/.claude/profiles/users/template/expertise.md"
  TMPDIR_T=$(mktemp -d)
  AUDIT_FIXT="$TMPDIR_T/audit"
  mkdir -p "$AUDIT_FIXT/2026-06-04" "$AUDIT_FIXT/2026-06-05"
}

teardown() {
  [ -n "${TMPDIR_T:-}" ] && [ -d "$TMPDIR_T" ] && rm -rf "$TMPDIR_T"
}

# ── Existence + safety identity ─────────────────────────────────────────────

@test "expertise-rewrite: file exists, has shebang, executable" {
  [ -f "$REWRITE_ABS" ]
  head -1 "$REWRITE_ABS" | grep -q '^#!'
  [ -x "$REWRITE_ABS" ]
}

@test "tribunal-search: file exists, has shebang, executable" {
  [ -f "$SEARCH_ABS" ]
  head -1 "$SEARCH_ABS" | grep -q '^#!'
  [ -x "$SEARCH_ABS" ]
}

@test "expertise template: file exists with valid frontmatter" {
  [ -f "$TEMPLATE_ABS" ]
  grep -q '^schema_version:' "$TEMPLATE_ABS"
  grep -q '^audit_level_default:' "$TEMPLATE_ABS"
}

@test "both scripts declare 'set -uo pipefail'" {
  grep -q "set -uo pipefail" "$REWRITE_ABS"
  grep -q "set -uo pipefail" "$SEARCH_ABS"
}

@test "both scripts pass bash -n syntax check" {
  bash -n "$REWRITE_ABS"
  bash -n "$SEARCH_ABS"
}

# ── expertise-rewrite: positive cases ───────────────────────────────────────

@test "rewrite: blind audit_level produces calibration banner" {
  run bash -c "echo 'Recomendacion X' | bash '$REWRITE_ABS' --audit-level blind --domain demo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CALIBRATION"* ]]
  [[ "$output" == *"blind-area"* ]]
  [[ "$output" == *"demo"* ]]
}

@test "rewrite: blind output includes three obligatory sections" {
  run bash -c "echo 'Recomendacion X' | bash '$REWRITE_ABS' --audit-level blind --reasoning 'because A' --verification 'cmd1|cmd2'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"creo esto"* ]]
  [[ "$output" == *"Alternativas"* ]]
  [[ "$output" == *"verificar"* ]]
}

@test "rewrite: high audit_level passes draft through unchanged" {
  run bash -c "echo 'Plain draft' | bash '$REWRITE_ABS' --audit-level high"
  [ "$status" -eq 0 ]
  [[ "$output" == "Plain draft" ]]
}

@test "rewrite: medium audit_level passes draft through unchanged" {
  run bash -c "echo 'Plain draft' | bash '$REWRITE_ABS' --audit-level medium"
  [ "$status" -eq 0 ]
  [[ "$output" == "Plain draft" ]]
}

@test "rewrite: low audit_level passes draft through unchanged" {
  run bash -c "echo 'Plain draft' | bash '$REWRITE_ABS' --audit-level low"
  [ "$status" -eq 0 ]
  [[ "$output" == "Plain draft" ]]
}

@test "rewrite: verification array becomes bullet list" {
  run bash -c "echo 'Z' | bash '$REWRITE_ABS' --audit-level blind --verification 'EXPLAIN ANALYZE|pg_stat_database'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- EXPLAIN ANALYZE"* ]]
  [[ "$output" == *"- pg_stat_database"* ]]
}

@test "rewrite: alternatives array as JSON dicts becomes bullet list" {
  run bash -c "echo 'Z' | bash '$REWRITE_ABS' --audit-level blind --alternatives '{\"option\":\"A\",\"rejected_because\":\"slow\"}|{\"option\":\"B\",\"rejected_because\":\"unsafe\"}'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"A: slow"* ]]
  [[ "$output" == *"B: unsafe"* ]]
}

# ── expertise-rewrite: negative cases ───────────────────────────────────────

@test "negative: rewrite fails with usage when no args provided" {
  run bash "$REWRITE_ABS"
  [ "$status" -eq 2 ]
}

@test "negative: rewrite rejects unknown argument" {
  run bash -c "echo 'X' | bash '$REWRITE_ABS' --bogus"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown"* || "$output" == *"ERROR"* ]]
}

@test "negative: rewrite reports error for missing judge JSON file" {
  run bash -c "echo 'X' | bash '$REWRITE_ABS' --judge-json '$TMPDIR_T/does-not-exist.json'"
  [ "$status" -eq 3 ]
  [[ "$output" == *"not readable"* || "$output" == *"missing"* || "$output" == *"ERROR"* ]]
}

@test "negative: rewrite handles malformed judge JSON (invalid syntax)" {
  bad="$TMPDIR_T/bad.json"
  printf 'not-json{' > "$bad"
  run bash -c "echo 'X' | bash '$REWRITE_ABS' --judge-json '$bad'"
  [ "$status" -eq 4 ]
  [[ "$output" == *"malformed"* || "$output" == *"ERROR"* ]]
}

@test "negative: rewrite blind without reasoning still emits placeholder (graceful)" {
  run bash -c "echo 'X' | bash '$REWRITE_ABS' --audit-level blind"
  [ "$status" -eq 0 ]
  [[ "$output" == *"razonamiento no proporcionado"* || "$output" == *"pedir explicacion"* ]]
}

# ── expertise-rewrite: edge cases ───────────────────────────────────────────

@test "edge: rewrite handles empty stdin draft (no output, no crash)" {
  run bash -c "echo -n '' | bash '$REWRITE_ABS' --audit-level blind"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "edge: rewrite reads judge JSON with zero alternatives (boundary)" {
  judge="$TMPDIR_T/judge.json"
  printf '%s\n' '{"audit_level":"blind","reasoning":"r","domain":"d","alternatives_considered":[],"verification_steps":[]}' > "$judge"
  run bash -c "echo 'Z' | bash '$REWRITE_ABS' --judge-json '$judge'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ninguna alternativa"* ]]
  [[ "$output" == *"no se han propuesto"* ]]
}

@test "edge: rewrite preserves original draft as first content line" {
  run bash -c "echo 'ORIGINAL_LINE_42' | bash '$REWRITE_ABS' --audit-level blind"
  [ "$status" -eq 0 ]
  first_line=$(printf '%s\n' "$output" | head -1)
  [ "$first_line" = "ORIGINAL_LINE_42" ]
}

# ── tribunal-search: positive + negative + edge ─────────────────────────────

@test "search: --summary on empty audit dir reports zero records" {
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-05 --summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"records=0"* ]]
}

@test "search: filters by verdict correctly" {
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"a1b2c3d4","draft_preview":"x","classification":{"risk_class":"medium"},"verdict":"VETO"}' > "$AUDIT_FIXT/2026-06-04/a1b2c3d4.json"
  printf '%s\n' '{"ts":"2026-06-04T10:01:00Z","draft_hash":"e5f6","draft_preview":"y","classification":{"risk_class":"high"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/e5f6.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --verdict VETO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VETO"* ]]
  [[ "$output" != *"PASS"* ]]
}

@test "search: filters by risk correctly" {
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"a1b2c3d4","draft_preview":"x","classification":{"risk_class":"high"},"verdict":"VETO"}' > "$AUDIT_FIXT/2026-06-04/a1b2c3d4.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --risk high --summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"records=1"* ]]
  [[ "$output" == *"high=1"* ]]
}

@test "search: filters by hash prefix correctly" {
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"prefix12345xyz","draft_preview":"a","classification":{"risk_class":"medium"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/prefix.json"
  printf '%s\n' '{"ts":"2026-06-04T10:01:00Z","draft_hash":"otherhash99","draft_preview":"b","classification":{"risk_class":"medium"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/other.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --hash prefix12 --summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"records=1"* ]]
}

@test "search: --json mode emits one record per line" {
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"h1","draft_preview":"x","classification":{"risk_class":"medium"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/h1.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; [json.loads(l) for l in sys.stdin if l.strip()]"
}

@test "negative: search rejects unknown argument" {
  run bash "$SEARCH_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown"* || "$output" == *"ERROR"* ]]
}

@test "negative: search fails when audit-trail directory is missing" {
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMPDIR_T/does-not-exist" run bash "$SEARCH_ABS"
  [ "$status" -eq 3 ]
  [[ "$output" == *"missing"* || "$output" == *"ERROR"* ]]
}

@test "edge: search skips non-date directories under audit base (boundary)" {
  mkdir -p "$AUDIT_FIXT/not-a-date"
  printf '%s\n' '{"ts":"x","draft_hash":"x","verdict":"x"}' > "$AUDIT_FIXT/not-a-date/x.json"
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"valid","draft_preview":"v","classification":{"risk_class":"medium"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/valid.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"records=1"* ]]
}

@test "edge: search ignores empty JSONL lines (zero-length records)" {
  printf '\n\n' > "$AUDIT_FIXT/2026-06-04/empty.json"
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"v","draft_preview":"v","classification":{"risk_class":"low"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/valid.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"records=1"* ]]
}

@test "edge: search caps results when no matches (graceful empty)" {
  printf '%s\n' '{"ts":"2026-06-04T10:00:00Z","draft_hash":"v","draft_preview":"v","classification":{"risk_class":"low"},"verdict":"PASS"}' > "$AUDIT_FIXT/2026-06-04/v.json"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$AUDIT_FIXT" run bash -c "bash '$SEARCH_ABS' --from 2026-06-04 --to 2026-06-04 --verdict NOPE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── Template invariants ─────────────────────────────────────────────────────

@test "template: documents the four audit_level values blind low medium high" {
  grep -q '^| `blind` |' "$TEMPLATE_ABS"
  grep -q '^| `low` |' "$TEMPLATE_ABS"
  grep -q '^| `medium` |' "$TEMPLATE_ABS"
  grep -q '^| `high` |' "$TEMPLATE_ABS"
}

@test "template: references SPEC-125 section 5" {
  grep -q "SPEC-125" "$TEMPLATE_ABS"
  grep -q -i "Asymmetric" "$TEMPLATE_ABS"
}
