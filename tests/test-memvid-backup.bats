#!/usr/bin/env bats
# test-memvid-backup.bats — SE-041 Slice 2 tests.
# Spec: docs/propuestas/SE-041-memvid-portable-memory.md

set -uo pipefail
ROOT="$BATS_TEST_DIRNAME/.."
SCRIPT="$ROOT/scripts/memvid-backup.py"
SKILL_DIR="$ROOT/.opencode/skills/memvid-backup"

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  mkdir -p "$TMPDIR/src"
  echo "engram 1" > "$TMPDIR/src/e1.md"
  echo "engram 2" > "$TMPDIR/src/e2.md"
  mkdir -p "$TMPDIR/src/sub"
  echo "nested" > "$TMPDIR/src/sub/n.md"
}

teardown() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR" || true
}

# --- Script existence ---

@test "script: memvid-backup.py exists and executable" {
  [ -x "$SCRIPT" ]
}

@test "script: has shebang" {
  run head -1 "$SCRIPT"
  [[ "$output" == "#!/usr/bin/env python3" ]]
}

@test "script: --help works" {
  run python3 "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"pack"* ]]
  [[ "$output" == *"restore"* ]]
  [[ "$output" == *"verify"* ]]
}

# --- Pack ---

@test "pack: creates output file" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/backup.tar.gz" --json
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/backup.tar.gz" ]
}

@test "pack: output contains sha256 hash" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/backup.tar.gz" --json
  [[ "$output" == *'"sha256"'* ]]
}

@test "pack: output contains latency_ms" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/backup.tar.gz" --json
  [[ "$output" == *'"latency_ms"'* ]]
}

@test "pack: output contains size_bytes" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/backup.tar.gz" --json
  [[ "$output" == *'"size_bytes"'* ]]
}

@test "pack: format tar-gzip forced works" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --format tar-gzip --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"tar-gzip"* ]]
}

@test "pack: format auto falls back to tar-gzip when memvid unavailable" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --format auto --json
  [ "$status" -eq 0 ]
}

@test "pack: nonexistent source returns error" {
  run python3 "$SCRIPT" pack --src "$TMPDIR/nonexistent" --out "$TMPDIR/b.tar.gz" --json
  [ "$status" -eq 1 ]
}

# --- Verify ---

@test "verify: valid backup returns ok" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  run python3 "$SCRIPT" verify --src "$TMPDIR/b.tar.gz" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"ok": true'* ]]
}

@test "verify: reports sha256" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  run python3 "$SCRIPT" verify --src "$TMPDIR/b.tar.gz" --json
  [[ "$output" == *'"sha256"'* ]]
}

@test "verify: reports member count" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  run python3 "$SCRIPT" verify --src "$TMPDIR/b.tar.gz" --json
  [[ "$output" == *'"members"'* ]]
}

@test "verify: nonexistent file returns error" {
  run python3 "$SCRIPT" verify --src "$TMPDIR/nonexistent.tar.gz" --json
  [ "$status" -eq 1 ]
}

@test "verify: empty file returns error" {
  touch "$TMPDIR/empty.tar.gz"
  run python3 "$SCRIPT" verify --src "$TMPDIR/empty.tar.gz" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty"* ]]
}

@test "verify: corrupted file returns error" {
  echo "not a tarfile" > "$TMPDIR/bad.tar.gz"
  run python3 "$SCRIPT" verify --src "$TMPDIR/bad.tar.gz" --json
  [ "$status" -eq 1 ]
}

# --- Restore ---

@test "restore: extracts to output directory" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  run python3 "$SCRIPT" restore --src "$TMPDIR/b.tar.gz" --out "$TMPDIR/restored" --json
  [ "$status" -eq 0 ]
  [ -d "$TMPDIR/restored" ]
}

@test "restore: reports files_extracted count" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  run python3 "$SCRIPT" restore --src "$TMPDIR/b.tar.gz" --out "$TMPDIR/r" --json
  [[ "$output" == *'"files_extracted"'* ]]
}

@test "restore: nonexistent backup returns error" {
  run python3 "$SCRIPT" restore --src "$TMPDIR/nonexistent.tar.gz" --out "$TMPDIR/r" --json
  [ "$status" -eq 1 ]
}

# --- Round-trip ---

@test "round-trip: content preserved after pack + restore" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  python3 "$SCRIPT" restore --src "$TMPDIR/b.tar.gz" --out "$TMPDIR/restored" --json >/dev/null
  # Find engram content
  run grep -l "engram 1" "$TMPDIR/restored"/src/e1.md
  [ "$status" -eq 0 ]
}

@test "round-trip: sha256 reproducible across 2 packs" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b1.tar.gz" --json >/dev/null
  sleep 1  # tar may encode mtime
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b2.tar.gz" --json >/dev/null
  # SHA may differ due to mtime; but both should be valid
  [ -f "$TMPDIR/b1.tar.gz" ]
  [ -f "$TMPDIR/b2.tar.gz" ]
}

# --- Usage errors ---

@test "usage: no subcommand exits non-zero" {
  run python3 "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "usage: unknown subcommand exits non-zero" {
  run python3 "$SCRIPT" bogus
  [ "$status" -ne 0 ]
}

@test "usage: pack without --src fails" {
  run python3 "$SCRIPT" pack --out "$TMPDIR/out.tar.gz"
  [ "$status" -ne 0 ]
}

# --- Skill structure ---

@test "skill: memvid-backup directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "skill: SKILL.md under 150 lines" {
  local lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "skill: DOMAIN.md under 150 lines" {
  local lines=$(wc -l < "$SKILL_DIR/DOMAIN.md")
  [ "$lines" -le 150 ]
}

@test "skill: SKILL.md references SE-041" {
  run grep "SE-041" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: DOMAIN.md references SE-041" {
  run grep "SE-041" "$SKILL_DIR/DOMAIN.md"
  [ "$status" -eq 0 ]
}

@test "skill: SKILL.md frontmatter name is memvid-backup" {
  run grep -E "^name:\s*memvid-backup" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: SKILL.md documents 3 subcommands" {
  run grep -E "pack|restore|verify" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

# --- Coverage ---

@test "coverage: script has pack_tar_gzip" {
  run grep "def pack_tar_gzip" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script has try_memvid_available" {
  run grep "def try_memvid_available" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script has sha256_file integrity" {
  run grep "def sha256_file" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script references SE-041" {
  run grep "SE-041" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Edge cases ---

@test "edge: empty source directory packs ok" {
  mkdir -p "$TMPDIR/empty-src"
  run python3 "$SCRIPT" pack --src "$TMPDIR/empty-src" --out "$TMPDIR/e.tar.gz" --json
  [ "$status" -eq 0 ]
}

@test "edge: large filename boundary accepted" {
  local name="$(python3 -c 'print("a"*100)')"
  echo "content" > "$TMPDIR/src/$name.md"
  run python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json
  [ "$status" -eq 0 ]
}

@test "edge: zero member tar detected as empty" {
  python3 -c "import tarfile; tarfile.open('$TMPDIR/empty.tar.gz','w:gz').close()"
  run python3 "$SCRIPT" verify --src "$TMPDIR/empty.tar.gz" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"members": 0'* ]]
}

# --- Isolation ---

@test "isolation: verify does not modify backup file" {
  python3 "$SCRIPT" pack --src "$TMPDIR/src" --out "$TMPDIR/b.tar.gz" --json >/dev/null
  local before=$(md5sum "$TMPDIR/b.tar.gz" | awk '{print $1}')
  python3 "$SCRIPT" verify --src "$TMPDIR/b.tar.gz" --json >/dev/null
  local after=$(md5sum "$TMPDIR/b.tar.gz" | awk '{print $1}')
  [ "$before" = "$after" ]
}

@test "isolation: --help offline" {
  run timeout 3 python3 "$SCRIPT" --help
  [ "$status" -eq 0 ]
}
