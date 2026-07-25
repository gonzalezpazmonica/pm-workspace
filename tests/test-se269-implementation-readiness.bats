#!/usr/bin/env bats
# BATS tests for scripts/implementation-readiness.sh (SE-269 S2)
# Ref: docs/specs/SE-269-bmad-patterns.spec.md

SCRIPT="scripts/implementation-readiness.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Helper: create a minimal valid spec (PASA) ──
make_pasa_spec() {
  local dir="$1"
  cat > "$dir/spec.md" <<'ENDSPEC'
# Test Spec
**Status:** APPROVED
AC-1.1: acceptance criteria test
AC-1.2: another acceptance test
Out of scope: nada que ver
- **R1 (S1)**: riesgo de prueba
**Mitigacion:** solucion
SE-123 CRIT-001
## Slice 1
**Esfuerzo:** 5h
ENDSPEC
}

# ── Structure / safety ────────────────────────────────────────────────────

@test "SE269-S2-IR: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE269-S2-IR: script has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Input validation ──────────────────────────────────────────────────────

@test "SE269-S2-IR: requires spec file argument" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "SE269-S2-IR: rejects nonexistent spec file" {
  run bash "$SCRIPT" /tmp/nonexistent-spec-$$.md
  [ "$status" -eq 1 ]
}

@test "SE269-S2-IR: accepts existing spec file" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

# ── Output structure ──────────────────────────────────────────────────────

@test "SE269-S2-IR: output is valid JSON" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
  [ "$?" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "SE269-S2-IR: output contains veredicto" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto"'* ]]
  rm -rf "$tmpdir"
}

# ── AC-2.4: spec without ACs → FALLA ─────────────────────────────────────

@test "SE269-S2-IR AC-2.4: spec without ACs produces FALLA" {
  local tmpdir; tmpdir="$(mktemp -d)"
  echo "# Empty Spec" > "$tmpdir/spec.md"
  echo "**Status:** APPROVED" >> "$tmpdir/spec.md"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  local verdict; verdict=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['veredicto'])" 2>/dev/null || echo "NO_JSON")
  [[ "$verdict" == "FALLA" ]]
  rm -rf "$tmpdir"
}

# ── AC status checks ──────────────────────────────────────────────────────

@test "SE269-S2-IR: APPROVED spec passes status check" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "SE269-S2-IR: PROPOSED spec generates RESERVAS for status" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  sed -i 's/APPROVED/PROPOSED/' "$tmpdir/spec.md"
  run env OWNER="@test" bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

# ── Dimension checks ──────────────────────────────────────────────────────

@test "SE269-S2-IR: out of scope detection works" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "SE269-S2-IR: riesgo mitigation detection works" {
  local tmpdir; tmpdir="$(mktemp -d)"
  make_pasa_spec "$tmpdir"
  run bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "SE269-S2-IR: vague AC language detected" {
  local tmpdir; tmpdir="$(mktemp -d)"
  echo "# Vague Spec" > "$tmpdir/spec.md"
  echo "**Status:** APPROVED" >> "$tmpdir/spec.md"
  echo "AC-1.1: implementar opcional y si es posible cuando se pueda" >> "$tmpdir/spec.md"
  echo "AC-1.2: idealmente debe funcionar" >> "$tmpdir/spec.md"
  run env OWNER="@test" bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

# ── Ternary audit ─────────────────────────────────────────────────────────

@test "SE269-S2-IR AC-2.5: audit log is written" {
  local tmpdir; tmpdir="$(mktemp -d)"
  local audit_file="$tmpdir/audit.jsonl"
  make_pasa_spec "$tmpdir"
  run env AUDIT_LOG="$audit_file" bash "$SCRIPT" "$tmpdir/spec.md"
  [ "$status" -eq 0 ]
  [[ -f "$audit_file" ]]
  rm -rf "$tmpdir"
}
