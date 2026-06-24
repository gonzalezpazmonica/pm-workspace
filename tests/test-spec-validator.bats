#!/usr/bin/env bats
# Tests for spec-validator.sh — SE-222 S0 resource: URI convention validator
# Ref: SPEC SE-222, docs/propuestas/SE-222-okf-adoptable-patterns.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/spec-validator.sh"
  TMPDIR_SV="$(mktemp -d)"
  export TMPDIR_SV
}

teardown() {
  rm -rf "$TMPDIR_SV"
}

# ── Usage / argument errors ────────────────────────────────────────────────

@test "no args shows usage and exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "script uses set -uo pipefail safety guard" {
  # Verify the script declares strict mode (set -uo pipefail)
  run grep -E 'set -uo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

@test "validate_file function exists in script" {
  run grep -E '^validate_file\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "is_valid_uri function exists in script" {
  run grep -E '^is_valid_uri\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "get_frontmatter_field function exists in script" {
  run grep -E '^get_frontmatter_field\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "usage function exists in script" {
  run grep -E '^usage\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "--help shows usage with exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"resource"* ]]
}

@test "unknown flag exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown flag"* ]]
}

@test "--batch with --file is mutually exclusive" {
  run bash "$SCRIPT" --batch "$TMPDIR_SV" "$TMPDIR_SV/file.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "--batch with nonexistent dir fails" {
  run bash "$SCRIPT" --batch "$TMPDIR_SV/doesnt-exist"
  [ "$status" -eq 2 ]
  [[ "$output" == *"directory not found"* ]]
}

# ── No frontmatter → skip ────────────────────────────────────────────────

@test "file without frontmatter produces no findings" {
  cat > "$TMPDIR_SV/no-fm.md" <<'EOF'
# Just a doc

No frontmatter at all.
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/no-fm.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "nonexistent file produces FILE_NOT_FOUND finding" {
  run bash "$SCRIPT" "$TMPDIR_SV/missing.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FILE_NOT_FOUND"* ]] || [[ "$output" == *"does not exist"* ]]
}

# ── MISSING_RESOURCE rule ─────────────────────────────────────────────────

@test "origin without resource → WARN MISSING_RESOURCE" {
  cat > "$TMPDIR_SV/missing-res.md" <<'EOF'
---
spec_id: TEST-001
title: Test spec
status: PROPOSED
origin: https://example.com/some-repo
---

# TEST-001

Body.
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/missing-res.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MISSING_RESOURCE"* ]]
  [[ "$output" == *"WARN"* ]]
}

@test "origin with valid resource → OK" {
  cat > "$TMPDIR_SV/both.md" <<'EOF'
---
spec_id: TEST-002
title: Test spec
status: PROPOSED
origin: External research
resource: "https://github.com/owner/repo"
---

# TEST-002
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/both.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "neither origin nor resource → OK (internal spec, both optional)" {
  cat > "$TMPDIR_SV/internal.md" <<'EOF'
---
spec_id: TEST-003
title: Internal decision
status: PROPOSED
---

# TEST-003
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/internal.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── INVALID_RESOURCE_URI rule ─────────────────────────────────────────────

@test "resource without scheme → WARN INVALID_RESOURCE_URI" {
  cat > "$TMPDIR_SV/bad-uri.md" <<'EOF'
---
spec_id: TEST-004
title: Bad URI
status: PROPOSED
origin: test
resource: just-a-string-no-scheme
---

# TEST-004
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/bad-uri.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INVALID_RESOURCE_URI"* ]]
}

@test "valid https URI passes" {
  cat > "$TMPDIR_SV/https.md" <<'EOF'
---
spec_id: TEST-005
title: HTTPS URI
status: PROPOSED
origin: test
resource: "https://example.com/path"
---

# TEST-005
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/https.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "valid mailto URI passes" {
  cat > "$TMPDIR_SV/mail.md" <<'EOF'
---
spec_id: TEST-006
title: Mailto
status: PROPOSED
origin: test
resource: "mailto:team@example.com"
---

# TEST-006
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/mail.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "valid urn URI passes" {
  cat > "$TMPDIR_SV/urn.md" <<'EOF'
---
spec_id: TEST-007
title: URN identifier
status: PROPOSED
origin: research paper
resource: "urn:doi:10.1234/example"
---

# TEST-007
EOF
  run bash "$SCRIPT" "$TMPDIR_SV/urn.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── --strict mode ─────────────────────────────────────────────────────────

@test "--strict exits 1 on findings" {
  cat > "$TMPDIR_SV/missing-strict.md" <<'EOF'
---
spec_id: TEST-008
title: Test
status: PROPOSED
origin: external
---

# TEST-008
EOF
  run bash "$SCRIPT" --strict "$TMPDIR_SV/missing-strict.md"
  [ "$status" -eq 1 ]
}

@test "--strict exits 0 when no findings" {
  cat > "$TMPDIR_SV/clean-strict.md" <<'EOF'
---
spec_id: TEST-009
title: Test
status: PROPOSED
origin: external
resource: "https://example.com"
---

# TEST-009
EOF
  run bash "$SCRIPT" --strict "$TMPDIR_SV/clean-strict.md"
  [ "$status" -eq 0 ]
}

# ── --json output ─────────────────────────────────────────────────────────

@test "--json output is valid JSON array" {
  cat > "$TMPDIR_SV/json-test.md" <<'EOF'
---
spec_id: TEST-010
title: Test
status: PROPOSED
origin: external
---

# TEST-010
EOF
  run bash "$SCRIPT" --json "$TMPDIR_SV/json-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"["* ]]
  [[ "$output" == *"]"* ]]
  [[ "$output" == *"MISSING_RESOURCE"* ]]
}

@test "--json empty findings is empty array" {
  cat > "$TMPDIR_SV/json-clean.md" <<'EOF'
---
spec_id: TEST-011
title: Test
status: PROPOSED
---

# TEST-011
EOF
  run bash "$SCRIPT" --json "$TMPDIR_SV/json-clean.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "[]" ]]
}

# ── --batch mode ──────────────────────────────────────────────────────────

@test "--batch processes multiple files" {
  cat > "$TMPDIR_SV/a.md" <<'EOF'
---
spec_id: BATCH-A
origin: external
---
EOF
  cat > "$TMPDIR_SV/b.md" <<'EOF'
---
spec_id: BATCH-B
origin: external
---
EOF
  run bash "$SCRIPT" --batch "$TMPDIR_SV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Findings: 2"* ]] || [[ "$output" == *"BATCH-A"* ]]
}

@test "--batch with --strict fails on findings" {
  cat > "$TMPDIR_SV/c.md" <<'EOF'
---
spec_id: BATCH-C
origin: external
---
EOF
  run bash "$SCRIPT" --strict --batch "$TMPDIR_SV"
  [ "$status" -eq 1 ]
}

# ── Real spec validation (smoke test against repo) ─────────────────────────

@test "SE-216 spec passes validation (back-filled)" {
  run bash "$SCRIPT" "$REPO_ROOT/docs/propuestas/SE-216-evo-patterns.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "spec-resource-uri.md rule itself passes validation" {
  run bash "$SCRIPT" "$REPO_ROOT/docs/rules/domain/spec-resource-uri.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}
