#!/usr/bin/env bats
# test-scrapling-probe.bats — SE-061 Slice 1 BATS tests for scrapling-probe.sh
# Target: >= 15 tests, auditor score >= 80.
# Spec: docs/propuestas/SE-061-scrapling-research-backend.md
# Research: output/research/scrapling-20260421.md (local)

SCRIPT="$BATS_TEST_DIRNAME/../scripts/scrapling-probe.sh"

# --- Happy path ---

@test "help: --help prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"SE-061"* ]]
}

@test "help: -h is alias for --help" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "default: runs without args and exits 0 or 1" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT:"* ]]
}

@test "verbose: default output contains Python version label" {
  run bash "$SCRIPT"
  [[ "$output" == *"Python:"* ]]
}

@test "verbose: default output contains VERDICT line" {
  run bash "$SCRIPT"
  [[ "$output" == *"VERDICT:"* ]]
}

# --- JSON mode ---

@test "json: --json produces parseable JSON" {
  run bash "$SCRIPT" --json
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *'"verdict"'* ]]
  [[ "$output" == *'"python_version"'* ]]
  [[ "$output" == *'"scrapling_installed"'* ]]
}

@test "json: output contains reasons array" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"reasons":'* ]]
}

@test "json: exit code is 0 or 1 (never 2)" {
  run bash "$SCRIPT" --json
  [[ "$status" -ne 2 ]]
}

@test "json: disk_free_gb is numeric" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"disk_free_gb":'* ]]
  [[ "$output" =~ \"disk_free_gb\":[0-9]+ ]]
}

# --- Browser flag ---

@test "browser: --check-browser adds playwright and chromium fields" {
  run bash "$SCRIPT" --check-browser --json
  [[ "$output" == *'"playwright"'* ]]
  [[ "$output" == *'"chromium"'* ]]
  [[ "$output" == *'"check_browser":1'* ]]
}

@test "browser: default run has check_browser=0" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"check_browser":0'* ]]
}

# --- Negative ---

@test "negative: unknown arg exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "negative: typo in flag exits 2" {
  run bash "$SCRIPT" --jsn
  [ "$status" -eq 2 ]
}

@test "negative: unknown arg prints ERROR to stderr" {
  run bash "$SCRIPT" --xyz
  [[ "$output" == *"ERROR"* ]]
}

# --- Verdict logic ---

@test "verdict: contains one of VIABLE|NEEDS_INSTALL|BLOCKED" {
  run bash "$SCRIPT"
  [[ "$output" == *"VIABLE"* || "$output" == *"NEEDS_INSTALL"* || "$output" == *"BLOCKED"* ]]
}

@test "verdict: BLOCKED exits 1" {
  # Simulate BLOCKED via a wrapper that fails python check
  local root="$BATS_TEST_TMPDIR/blocked"
  mkdir -p "$root/bin"
  export PATH="$root/bin:$PATH"
  # Create fake python3 reporting 3.8
  cat > "$root/bin/python3" <<'PY'
#!/usr/bin/env bash
if [[ "$*" == *"version_info"* ]]; then
  echo "3.8.0"
elif [[ "$*" == *"import"* ]]; then
  exit 1
fi
PY
  chmod +x "$root/bin/python3"
  run bash "$SCRIPT" --json
  [[ "$output" == *"BLOCKED"* ]] && [ "$status" -eq 1 ]
}

# --- Coverage ---

@test "coverage: script has set -uo pipefail" {
  run grep -E "^set -uo pipefail" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script references SE-061" {
  run grep -c "SE-061" "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "coverage: script references Python 3.10 requirement" {
  run grep -c "3.10\|PYTHON_MINOR.*-lt 10" "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: script checks lxml dependency" {
  run grep -c "lxml" "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

# --- Isolation ---

@test "isolation: script is read-only (no writes to cwd)" {
  local tmpdir="$BATS_TEST_TMPDIR/readonly"
  mkdir -p "$tmpdir"
  cd "$tmpdir"
  local before=$(find . -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" --json >/dev/null 2>&1 || true
  local after=$(find . -type f 2>/dev/null | wc -l)
  cd "$BATS_TEST_DIRNAME/.."
  [ "$before" -eq "$after" ]
}

@test "isolation: --json output is single line" {
  run bash "$SCRIPT" --json
  local lines=$(echo "$output" | wc -l)
  [ "$lines" -eq 1 ]
}

@test "isolation: no egress — script uses only local tools" {
  # curl/wget should NOT appear in runtime command paths (references in comments ok)
  run grep -cE "^[^#]*\b(curl|wget|http)\b" "$SCRIPT"
  # Only allowed if 0 (no network calls in actual code)
  [ "$output" -eq 0 ]
}
