#!/usr/bin/env bats
# BATS tests for scripts/review-checkpoint.sh (SE-269 S3)
# Ref: docs/specs/SE-269-bmad-patterns.spec.md

SCRIPT="scripts/review-checkpoint.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Structure / safety ────────────────────────────────────────────────────

@test "SE269-S3: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE269-S3: script has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Input validation ──────────────────────────────────────────────────────

@test "SE269-S3: requires --branch or --pr" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "SE269-S3: --branch with valid name succeeds" {
  run bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
}

@test "SE269-S3: --pr with number succeeds" {
  run bash "$SCRIPT" --pr 123
  [ "$status" -eq 0 ]
}

# ── Output structure ──────────────────────────────────────────────────────

@test "SE269-S3: output is valid JSON" {
  run bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "SE269-S3: output contains checkpoint_id" {
  run bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"checkpoint_id"'* ]]
}

@test "SE269-S3: output contains file path" {
  run bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"file"'* ]]
}

@test "SE269-S3: output contains timestamp" {
  run bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"timestamp"'* ]]
}

# ── Package file generation ───────────────────────────────────────────────

@test "SE269-S3: generates markdown package file" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  [[ -f "$pkg_file" ]]
  rm -rf "$(dirname "$output_dir")"
}

@test "SE269-S3 AC-3.2: package has 5 sections" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -c "^## " "$pkg_file"
  # Should have at least 5 sections (header + 5 numbered sections)
  [[ "$output" -ge 5 ]]
  rm -rf "$(dirname "$output_dir")"
}

@test "SE269-S3: package contains section 1 (Que cambio)" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -q "Que cambio" "$pkg_file"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$output_dir")"
}

@test "SE269-S3: package contains section 2 (Orden de lectura)" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -q "Orden de lectura" "$pkg_file"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$output_dir")"
}

@test "SE269-S3: package contains section 3 (Hallazgos)" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -q "Hallazgos" "$pkg_file"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$output_dir")"
}

@test "SE269-S3: package contains section 4 (Verificacion manual)" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -q "Verificacion manual" "$pkg_file"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$output_dir")"
}

@test "SE269-S3: package contains section 5 (Cierre)" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -q "Cierre" "$pkg_file"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$output_dir")"
}

# ── Spec integration ──────────────────────────────────────────────────────

@test "SE269-S3: --spec flag is accepted" {
  run bash "$SCRIPT" --branch "agent/se269-test" --spec "docs/specs/SE-269-bmad-patterns.spec.md"
  [ "$status" -eq 0 ]
}

# ── Cierre options ────────────────────────────────────────────────────────

@test "SE269-S3: cierre section contains decision options" {
  local output_dir; output_dir="$(mktemp -d)/review-checkpoints"
  mkdir -p "$output_dir"
  run env OUTPUT_DIR="$output_dir" bash "$SCRIPT" --branch "agent/se269-test"
  [ "$status" -eq 0 ]
  local pkg_file; pkg_file=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['file'])" 2>/dev/null)
  run grep -q "APROBAR\|REHACER\|SEGUIR DISCUTIENDO" "$pkg_file"
  [ "$status" -eq 0 ]
  rm -rf "$(dirname "$output_dir")"
}
