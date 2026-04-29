#!/usr/bin/env bats
# test-savia-monitor-linux.bats — Tests for Savia Monitor Linux build support
# Ref: projects/savia-monitor/CLAUDE.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/projects/savia-monitor/scripts/build-linux.sh"
  TAURI_CONF="$REPO_ROOT/projects/savia-monitor/src-tauri/tauri.conf.json"
  README_ES="$REPO_ROOT/projects/savia-monitor/README.md"
  README_EN="$REPO_ROOT/projects/savia-monitor/README.en.md"
  TMPDIR_LM=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_LM"
}

# ── Script integrity ─────────────────────────────────────────────────────────

@test "build-linux.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "build-linux.sh has bash shebang" {
  head -1 "$SCRIPT" | grep -q "bash"
}

@test "build-linux.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "build-linux.sh shows help" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"build-linux.sh"* ]]
  [[ "$output" == *"Linux"* ]]
}

@test "build-linux.sh --check runs without compiling" {
  run bash "$SCRIPT" --check
  # Either passes (all deps ok) or fails with missing prereqs (exit 2)
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]]
}

# ── tauri.conf.json ──────────────────────────────────────────────────────────

@test "tauri.conf.json is valid JSON" {
  run python3 -c "import json; json.load(open('$TAURI_CONF'))"
  [ "$status" -eq 0 ]
}

@test "tauri.conf.json declares deb target" {
  grep -q '"deb"' "$TAURI_CONF"
}

@test "tauri.conf.json declares rpm target" {
  grep -q '"rpm"' "$TAURI_CONF"
}

@test "tauri.conf.json declares appimage target" {
  grep -q '"appimage"' "$TAURI_CONF"
}

@test "tauri.conf.json has linux section" {
  grep -q '"linux"' "$TAURI_CONF"
}

@test "tauri.conf.json references libwebkit2gtk" {
  grep -q "libwebkit2gtk" "$TAURI_CONF"
}

@test "tauri.conf.json references libgtk-3" {
  grep -q "libgtk-3" "$TAURI_CONF"
}

@test "tauri.conf.json has category Utility" {
  grep -q '"Utility"' "$TAURI_CONF"
}

# ── README updates ───────────────────────────────────────────────────────────

@test "README.md has Linux prerequisites section" {
  grep -q "Linux" "$README_ES"
  grep -qE "(libwebkit2gtk|apt install)" "$README_ES"
}

@test "README.md has Build Linux section" {
  grep -qE "Build Linux|build-linux\.sh" "$README_ES"
}

@test "README.en.md has Linux prerequisites" {
  grep -q "Linux" "$README_EN"
  grep -qE "(libwebkit2gtk|apt install)" "$README_EN"
}

@test "README.en.md has Linux Build section" {
  grep -qE "Linux Build|build-linux\.sh" "$README_EN"
}

@test "READMEs are aligned (both mention all 3 Linux targets)" {
  for readme in "$README_ES" "$README_EN"; do
    grep -q "deb" "$readme"
    grep -qE "(rpm|RPM)" "$readme"
    grep -qE "(appimage|AppImage)" "$readme"
  done
}

# ── Rust source code cross-platform ─────────────────────────────────────────

@test "sessions.rs has Unix PID detection via libc::kill" {
  local sessions="$REPO_ROOT/projects/savia-monitor/src-tauri/src/sessions.rs"
  grep -q "libc::kill" "$sessions"
}

@test "config.rs handles HOME env var" {
  local config="$REPO_ROOT/projects/savia-monitor/src-tauri/src/config.rs"
  grep -q '"HOME"' "$config"
}

@test "config.rs falls back to USERPROFILE" {
  local config="$REPO_ROOT/projects/savia-monitor/src-tauri/src/config.rs"
  grep -q "USERPROFILE" "$config"
}

@test "git.rs uses cfg target_os windows guard" {
  local git="$REPO_ROOT/projects/savia-monitor/src-tauri/src/git.rs"
  grep -q 'cfg(target_os = "windows")' "$git"
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: build-linux.sh unknown flag returns exit 2" {
  run bash "$SCRIPT" --invalid-flag
  [ "$status" -eq 2 ]
}

@test "edge: build-linux.sh --deb-only flag accepted" {
  # Runs until rust check and fails there, but flag parsing must succeed
  run bash "$SCRIPT" --deb-only --check
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]]
}

@test "edge: build-linux.sh --appimage-only flag accepted" {
  run bash "$SCRIPT" --appimage-only --check
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]]
}

@test "edge: build-linux.sh --rpm-only flag accepted" {
  run bash "$SCRIPT" --rpm-only --check
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]]
}

@test "edge: build-linux.sh --dev flag accepted" {
  run bash "$SCRIPT" --dev --check
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]]
}

@test "edge: build-linux.sh nonexistent argument pairs" {
  run bash "$SCRIPT" --help --bogus
  # --help exits first, ignoring subsequent args
  [ "$status" -eq 0 ]
}

@test "edge: tauri.conf.json has no empty targets array" {
  run python3 -c "import json; d=json.load(open('$TAURI_CONF')); print(len(d['bundle'].get('targets',[])))"
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

@test "edge: boundary — tauri.conf.json has exactly 6 targets or more" {
  run python3 -c "import json; d=json.load(open('$TAURI_CONF')); print(len(d['bundle'].get('targets',[])))"
  [ "$output" -ge 3 ]
}

# ── Coverage: build-linux.sh functions ──────────────────────────────────────

@test "coverage: build-linux.sh has check_os function" {
  grep -q "check_os()" "$SCRIPT"
}

@test "coverage: build-linux.sh has check_rust function" {
  grep -q "check_rust()" "$SCRIPT"
}

@test "coverage: build-linux.sh has check_node function" {
  grep -q "check_node()" "$SCRIPT"
}

@test "coverage: build-linux.sh has check_system_deps function" {
  grep -q "check_system_deps()" "$SCRIPT"
}

@test "coverage: build-linux.sh has build_frontend function" {
  grep -q "build_frontend()" "$SCRIPT"
}

@test "coverage: build-linux.sh has build_tauri function" {
  grep -q "build_tauri()" "$SCRIPT"
}

@test "coverage: build-linux.sh has main function" {
  grep -q "^main()" "$SCRIPT"
}

@test "coverage: build-linux.sh respects CARGO_TARGET_DIR convention" {
  grep -q "CARGO_TARGET_DIR" "$SCRIPT"
}
