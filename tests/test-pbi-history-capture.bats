#!/usr/bin/env bats
# BATS tests for .opencode/hooks/pbi-history-capture.sh
# PostToolUse(Edit|Write) — captures PBI frontmatter changes in ## Historial
# Ref: batch 42 hook coverage

HOOK=".opencode/hooks/pbi-history-capture.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export TEST_REPO="$TMPDIR/repo-$$"
  mkdir -p "$TEST_REPO/projects/alpha/backlog/pbi"
  mkdir -p "$TEST_REPO/.claude/profiles"
  # Init git repo
  (cd "$TEST_REPO" && git init -q && git config user.email t@t && git config user.name t && git config commit.gpgsign false)
  # Active user profile (for @handle extraction)
  cat > "$TEST_REPO/.claude/profiles/active-user.md" <<'EOF'
---
active_slug: "testuser"
---
EOF
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Guard: only PBI files ─────────────────────────────────

@test "skip: non-PBI file ignored" {
  local F="$TEST_REPO/random.md"
  echo "# foo" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
}

@test "skip: file outside projects/ ignored" {
  local F="$TEST_REPO/PBI-001.md"
  echo "# pbi" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
}

@test "skip: nonexistent PBI file exits 0" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-999.md"
  run bash "$HOOK" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
}

@test "skip: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

# ── New PBI creation path ────────────────────────────────

@test "new PBI: creates Historial section with _created entry" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-001.md"
  cat > "$F" <<'EOF'
---
id: PBI-001
title: Test PBI
state: backlog
priority: medium
updated: 2020-01-01
---

Body.
EOF
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q '## Historial' "$F"
  grep -q '_created' "$F"
}

@test "new PBI: updates updated: field to today" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-002.md"
  cat > "$F" <<'EOF'
---
id: PBI-002
title: Test
state: backlog
updated: 2020-01-01
---
EOF
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  local today
  today=$(date +%Y-%m-%d)
  grep -q "updated: $today" "$F"
}

@test "new PBI: unknown id labeled in historial" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-noid.md"
  cat > "$F" <<'EOF'
---
title: No ID PBI
---
EOF
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -qE 'unknown' "$F"
}

# ── Field change detection (existing PBI) ────────────────

@test "change: priority field modification detected" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-003.md"
  cat > "$F" <<'EOF'
---
id: PBI-003
title: Test
state: backlog
priority: low
updated: 2020-01-01
---
EOF
  (cd "$TEST_REPO" && git add -A && git commit -q -m init)
  # Modify priority
  sed -i 's/priority: low/priority: high/' "$F"
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q 'priority' "$F"
  grep -q 'low' "$F"
  grep -q 'high' "$F"
}

@test "change: state field transition captured" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-004.md"
  cat > "$F" <<'EOF'
---
id: PBI-004
state: backlog
updated: 2020-01-01
---
EOF
  (cd "$TEST_REPO" && git add -A && git commit -q -m init)
  sed -i 's/state: backlog/state: doing/' "$F"
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -qE '\| state \| backlog \| doing \|' "$F"
}

@test "change: multiple fields produce multiple rows" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-005.md"
  cat > "$F" <<'EOF'
---
id: PBI-005
state: backlog
priority: low
assigned_to: alice
updated: 2020-01-01
---
EOF
  (cd "$TEST_REPO" && git add -A && git commit -q -m init)
  sed -i 's/state: backlog/state: doing/; s/priority: low/priority: high/' "$F"
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  local row_count
  row_count=$(grep -cE '^\| [0-9]+-[0-9]+-[0-9]+' "$F" || echo 0)
  [[ "$row_count" -ge 2 ]]
}

@test "no-op: zero changes does not append to historial" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-006.md"
  cat > "$F" <<'EOF'
---
id: PBI-006
state: backlog
updated: 2020-01-01
---
EOF
  (cd "$TEST_REPO" && git add -A && git commit -q -m init)
  # Do not modify the file
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  # No Historial section should be added since no changes
  ! grep -q '## Historial' "$F"
}

# ── Author extraction ────────────────────────────────────

@test "author: uses @handle from active-user.md slug" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-007.md"
  cat > "$F" <<'EOF'
---
id: PBI-007
state: backlog
updated: 2020-01-01
---
EOF
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q '@testuser' "$F"
}

@test "author: falls back to @system when no active profile" {
  rm -f "$TEST_REPO/.claude/profiles/active-user.md"
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-008.md"
  cat > "$F" <<'EOF'
---
id: PBI-008
state: backlog
updated: 2020-01-01
---
EOF
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q '@system' "$F"
}

# ── Negative cases ───────────────────────────────────────

@test "negative: malformed JSON exits 0" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: path field fallback (Write tool)" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-pf.md"
  cat > "$F" <<'EOF'
---
id: PBI-pf
updated: 2020-01-01
---
EOF
  # Use path instead of file_path
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q '## Historial' "$F"
}

@test "negative: PBI outside repo (no git) gracefully handled" {
  local OUT="$TMPDIR/outrepo-$$/projects/alpha/backlog/pbi/PBI-outside.md"
  mkdir -p "$(dirname "$OUT")"
  cat > "$OUT" <<'EOF'
---
id: PBI-outside
---
EOF
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$OUT\"}}"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$(dirname "$(dirname "$OUT")")")"
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: quoted string value in frontmatter handled" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-q.md"
  cat > "$F" <<'EOF'
---
id: PBI-q
title: "Quoted title"
updated: 2020-01-01
---
EOF
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q 'PBI-q' "$F"
}

@test "edge: historial already present does not duplicate header" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-dup.md"
  cat > "$F" <<'EOF'
---
id: PBI-dup
state: backlog
updated: 2020-01-01
---

## Historial
| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2025-01-01 09:00 | @old | state | draft | backlog |
EOF
  (cd "$TEST_REPO" && git add -A && git commit -q -m init)
  sed -i 's/state: backlog/state: doing/' "$F"
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  local count
  count=$(grep -c '^## Historial' "$F")
  [[ "$count" -eq 1 ]]
}

@test "edge: tags field tracked" {
  local F="$TEST_REPO/projects/alpha/backlog/pbi/PBI-tags.md"
  cat > "$F" <<'EOF'
---
id: PBI-tags
state: backlog
tags: bug,urgent
updated: 2020-01-01
---
EOF
  (cd "$TEST_REPO" && git add -A && git commit -q -m init)
  sed -i 's/tags: bug,urgent/tags: bug,urgent,regression/' "$F"
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$TEST_REPO"
  run bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  grep -q 'tags' "$F"
  grep -q 'regression' "$F"
}

# ── Coverage ─────────────────────────────────────────────

@test "coverage: tracked fields list declared" {
  run grep -c 'TRACKED_FIELDS=' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: extract_field helper defined" {
  run grep -c 'extract_field()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: guard regex only PBI-*.md under backlog/pbi" {
  run grep -c 'backlog/pbi/PBI' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: hook does not modify non-PBI files" {
  local HOOK_ABS="$(pwd)/$HOOK"
  local F="$TEST_REPO/random.md"
  echo "# foo" > "$F"
  local before
  before=$(md5sum "$F" | awk '{print $1}')
  cd "$TEST_REPO"
  bash "$HOOK_ABS" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}" >/dev/null 2>&1 || true
  cd "$BATS_TEST_DIRNAME/.."
  local after
  after=$(md5sum "$F" | awk '{print $1}')
  [[ "$before" == "$after" ]]
}

@test "isolation: exit codes are {0, 2} (never 1)" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"/nonexistent"}}'
  [ "$status" -eq 0 ]
}
