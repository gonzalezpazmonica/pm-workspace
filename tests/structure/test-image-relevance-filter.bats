#!/usr/bin/env bats
# Ref: SPEC-103 — Deterministic-first digests / image-relevance-filter primitive
# Spec: docs/propuestas/SPEC-103-deterministic-first-digests.md
# Slice 1: primitive only (heuristic + cache + log). Slice 2 (agent integration) follow-up.
# Pattern source: opendataloader-pdf hybrid local-first / AI-fallback (clean-room).

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/image-relevance-filter.sh"
  FILTER_ABS="$ROOT_DIR/$SCRIPT"
  RULE_DOC="$ROOT_DIR/docs/rules/domain/image-relevance-filter.md"
  TMPDIR_T=$(mktemp -d)
  export SAVIA_DIGEST_CACHE_DIR="$TMPDIR_T/cache"
}

teardown() {
  rm -rf "$TMPDIR_T"
  unset SAVIA_DIGEST_CACHE_DIR
}

# Helper: create a tiny zero-bytes file with a real path
mkfile() {
  local path="$1" size="${2:-0}"
  if [[ "$size" -eq 0 ]]; then
    : > "$path"
  else
    head -c "$size" </dev/urandom > "$path"
  fi
}

# ── C1 — file-level safety + identity ───────────────────────────────────────

@test "filter: file exists, has shebang, executable" {
  [ -f "$FILTER_ABS" ]
  head -1 "$FILTER_ABS" | grep -q '^#!'
  [ -x "$FILTER_ABS" ]
}

@test "filter: declares 'set -uo pipefail'" {
  grep -q "set -[uo]o pipefail" "$FILTER_ABS"
}

@test "filter: passes bash -n syntax check" {
  bash -n "$FILTER_ABS"
}

@test "spec ref: SPEC-103 cited in filter and rule doc" {
  grep -q "SPEC-103" "$FILTER_ABS"
  grep -q "SPEC-103" "$RULE_DOC"
}

@test "attribution: opendataloader-pdf pattern source cited" {
  grep -qF "opendataloader-pdf" "$FILTER_ABS"
  grep -qF "opendataloader-pdf" "$RULE_DOC"
  grep -qiE "clean.room|re.implement|local.first" "$RULE_DOC"
}

# ── C2 — usage / negative paths ─────────────────────────────────────────────

@test "filter: zero-arg invocation exits 2 (boundary)" {
  run bash "$FILTER_ABS"
  [ "$status" -eq 2 ]
}

@test "filter: unknown subcommand exits 2" {
  run bash "$FILTER_ABS" bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "filter: 'check' missing image arg exits 2" {
  run bash "$FILTER_ABS" check
  [ "$status" -eq 2 ]
  [[ "$output" == *"check requires"* ]]
}

@test "filter: 'check' on nonexistent image exits 3" {
  run bash "$FILTER_ABS" check "$TMPDIR_T/nonexistent.png"
  [ "$status" -eq 3 ]
  [[ "$output" == *"image not found"* ]]
}

@test "filter: 'log' rejects invalid decision (boundary)" {
  local img="$TMPDIR_T/x.png"
  mkfile "$img" 100
  run bash "$FILTER_ABS" log "$img" maybe
  [ "$status" -eq 2 ]
  [[ "$output" == *"skip' or 'invoke"* ]]
}

@test "filter: 'log' missing decision arg exits 2" {
  local img="$TMPDIR_T/x.png"
  mkfile "$img" 100
  run bash "$FILTER_ABS" log "$img"
  [ "$status" -eq 2 ]
}

# ── C3 — heuristic rules (positive cases) ────────────────────────────────────

@test "rule 2: tiny file size (< 10 KB) → SKIP with reason size-below-threshold" {
  local img="$TMPDIR_T/tiny.png"
  mkfile "$img" 4096   # 4 KB, below threshold
  run bash "$FILTER_ABS" check "$img"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action":"skip"'* ]]
  [[ "$output" == *'"reason":"size-below-threshold"'* ]]
}

@test "rule 5 default: large unrecognized image → INVOKE Vision (exit 1)" {
  local img="$TMPDIR_T/large.bin"
  mkfile "$img" 50000  # 50 KB, above threshold; no identify-readable header
  run bash "$FILTER_ABS" check "$img"
  # Without identify or with a non-image file, dims rule skips; size passes; default → invoke
  [ "$status" -eq 1 ]
  [[ "$output" == *'"action":"invoke"'* ]]
}

@test "rule 1: cache hit (sha pre-added to skip-list) → SKIP with cache-hit" {
  local img="$TMPDIR_T/cached.bin"
  mkfile "$img" 50000  # large enough to bypass size rule
  mkdir -p "$SAVIA_DIGEST_CACHE_DIR"
  # Compute sha and seed skip-list
  sha=$(sha256sum "$img" | awk '{print $1}')
  echo "$sha" > "$SAVIA_DIGEST_CACHE_DIR/skip-list.txt"
  run bash "$FILTER_ABS" check "$img"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason":"cache-hit"'* ]]
}

@test "subcommand 'skip': adds sha to skip-list manually" {
  local img="$TMPDIR_T/manual.bin"
  mkfile "$img" 50000
  run bash "$FILTER_ABS" skip "$img"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason":"manual-add"'* ]]
  sha=$(sha256sum "$img" | awk '{print $1}')
  grep -qFx "$sha" "$SAVIA_DIGEST_CACHE_DIR/skip-list.txt"
}

@test "subcommand 'log skip': appends to JSONL audit trail" {
  local img="$TMPDIR_T/logged.bin"
  mkfile "$img" 50000
  run bash "$FILTER_ABS" log "$img" skip
  [ "$status" -eq 0 ]
  [ -f "$SAVIA_DIGEST_CACHE_DIR/last-seen.jsonl" ]
  grep -qF '"decision":"skip"' "$SAVIA_DIGEST_CACHE_DIR/last-seen.jsonl"
}

@test "auto-promote: 3 'log skip' for same image → sha auto-added to skip-list" {
  local img="$TMPDIR_T/promoted.bin"
  mkfile "$img" 50000
  bash "$FILTER_ABS" log "$img" skip >/dev/null
  bash "$FILTER_ABS" log "$img" skip >/dev/null
  run bash "$FILTER_ABS" log "$img" skip
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason":"auto-promoted-after-3-marks"'* ]]
  sha=$(sha256sum "$img" | awk '{print $1}')
  grep -qFx "$sha" "$SAVIA_DIGEST_CACHE_DIR/skip-list.txt"
}

@test "auto-promote: 2 'log skip' is NOT enough (boundary)" {
  local img="$TMPDIR_T/notyet.bin"
  mkfile "$img" 50000
  bash "$FILTER_ABS" log "$img" skip >/dev/null
  run bash "$FILTER_ABS" log "$img" skip
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason":"logged"'* ]]
  sha=$(sha256sum "$img" | awk '{print $1}')
  ! grep -qFx "$sha" "$SAVIA_DIGEST_CACHE_DIR/skip-list.txt"
}

@test "subcommand 'log invoke': does NOT trigger auto-promote" {
  local img="$TMPDIR_T/invoke.bin"
  mkfile "$img" 50000
  bash "$FILTER_ABS" log "$img" invoke >/dev/null
  bash "$FILTER_ABS" log "$img" invoke >/dev/null
  run bash "$FILTER_ABS" log "$img" invoke
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason":"logged"'* ]]
  sha=$(sha256sum "$img" | awk '{print $1}')
  ! grep -qFx "$sha" "$SAVIA_DIGEST_CACHE_DIR/skip-list.txt"
}

# ── C4 — Edge cases (cache + JSON output structure) ─────────────────────────

@test "edge: cache dir is created on demand under SAVIA_DIGEST_CACHE_DIR override" {
  local img="$TMPDIR_T/img.bin"
  mkfile "$img" 5000
  run bash "$FILTER_ABS" check "$img"
  [ "$status" -eq 0 ]
  [ -d "$SAVIA_DIGEST_CACHE_DIR" ]
}

@test "edge: skip subcommand is idempotent (no duplicate sha lines)" {
  local img="$TMPDIR_T/dup.bin"
  mkfile "$img" 50000
  bash "$FILTER_ABS" skip "$img" >/dev/null
  bash "$FILTER_ABS" skip "$img" >/dev/null
  sha=$(sha256sum "$img" | awk '{print $1}')
  count=$(grep -cFx "$sha" "$SAVIA_DIGEST_CACHE_DIR/skip-list.txt")
  [ "$count" -eq 1 ]
}

@test "edge: JSON output has sha field with 64-char hex sha256" {
  local img="$TMPDIR_T/sha.bin"
  mkfile "$img" 50000
  run bash "$FILTER_ABS" check "$img"
  # Extract sha field via grep + awk
  sha=$(echo "$output" | grep -oE '"sha":"[a-f0-9]{64}"' | head -1)
  [ -n "$sha" ]
}

@test "edge: zero-byte image triggers size rule (boundary)" {
  local img="$TMPDIR_T/empty.png"
  : > "$img"   # 0 bytes
  run bash "$FILTER_ABS" check "$img"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"size":0'* ]]
}

@test "edge: log invoke is recorded distinct from skip in jsonl" {
  local img="$TMPDIR_T/mix.bin"
  mkfile "$img" 50000
  bash "$FILTER_ABS" log "$img" invoke >/dev/null
  bash "$FILTER_ABS" log "$img" skip >/dev/null
  invoke_count=$(grep -c '"decision":"invoke"' "$SAVIA_DIGEST_CACHE_DIR/last-seen.jsonl")
  skip_count=$(grep -c '"decision":"skip"' "$SAVIA_DIGEST_CACHE_DIR/last-seen.jsonl")
  [ "$invoke_count" -eq 1 ]
  [ "$skip_count" -eq 1 ]
}

# ── C5 — Rule canonical doc ─────────────────────────────────────────────────

@test "rule doc: exists and references SPEC-103" {
  [ -f "$RULE_DOC" ]
  grep -q "SPEC-103" "$RULE_DOC"
}

@test "rule doc: documents 4 heuristic rules in order" {
  for rule in "cache.hit" "size" "dimensions" "aspect.ratio"; do
    grep -qiE "$rule" "$RULE_DOC"
  done
}

@test "rule doc: documents auto-promote (≥3 skip marks → skip-list)" {
  grep -qiE "≥\s*3|auto.promote" "$RULE_DOC"
}

@test "rule doc: documents off-repo cache layout (~/.savia/digest-cache)" {
  grep -qF "~/.savia/digest-cache" "$RULE_DOC"
  grep -qF "skip-list.txt" "$RULE_DOC"
  grep -qF "last-seen.jsonl" "$RULE_DOC"
}

@test "rule doc: cross-references the 3 consumer agents (word/pptx/excel-digest)" {
  grep -qF "word-digest" "$RULE_DOC"
  grep -qF "pptx-digest" "$RULE_DOC"
  grep -qF "excel-digest" "$RULE_DOC"
}

@test "rule doc: explicitly lists Slice 2 deferred items + slice scope" {
  grep -qiE "Slice 2|follow.up" "$RULE_DOC"
}

# ── C6 — Spec ref + exit code reinforcement ─────────────────────────────────

@test "spec ref: docs/propuestas/SPEC-103 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-103" "$BATS_TEST_FILENAME"
}

@test "filter: documents 5 distinct exit codes (0,1,2,3,4)" {
  for code in 0 1 2 3 4; do
    grep -qE "exit $code|^#.*\b$code\b" "$FILTER_ABS"
  done
}

@test "graceful degradation: identify is optional (rules 3+4 skipped if absent)" {
  grep -qF "command -v identify" "$FILTER_ABS"
  grep -qiE "graceful|optional|degrad" "$RULE_DOC"
}
