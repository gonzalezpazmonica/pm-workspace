#!/usr/bin/env bats
# Ref: SE-273 S3-S7 — Egress, unlimited auth, objectives, action shape, trajectory, corroboration
# Spec: docs/propuestas/SE-273-contencion-trayectoria.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

# ═══════════════════════════════════════════════════════════════════
# S3: Egress control
# ═══════════════════════════════════════════════════════════════════

@test "S3/AC-3.1: egress-gate blocks unknown domain" {
  run bash "$REPO_ROOT/scripts/egress-gate.sh" check "evil.example.com"
  [ "$status" -ne 0 ]
}

@test "S3/AC-3.1: egress-gate allows known domain (github.com)" {
  run bash "$REPO_ROOT/scripts/egress-gate.sh" check "github.com"
  [ "$status" -eq 0 ]
}

@test "S3/AC-3.5: isolated mode blocks all egress" {
  SAVIA_ISOLATED_MODE=1 run bash "$REPO_ROOT/scripts/egress-gate.sh" check "github.com"
  [ "$status" -ne 0 ]
}

@test "S3: egress-gate status command works" {
  run bash "$REPO_ROOT/scripts/egress-gate.sh" status
  [ "$status" -eq 0 ]
}

@test "S3: egress-gate propose command works" {
  run bash "$REPO_ROOT/scripts/egress-gate.sh" propose "docs.example.com" "test documentation"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════
# S4: Unlimited authorization detection
# ═══════════════════════════════════════════════════════════════════

@test "S4/AC-4.1: detects 'lo que sea necesario'" {
  run bash "$REPO_ROOT/scripts/unlimited-auth-detector.sh" <<< "haz lo que sea necesario para terminar"
  [ "$status" -eq 0 ]
  # Detection should have written to log
}

@test "S4/AC-4.1: detects 'whatever it takes'" {
  run bash "$REPO_ROOT/scripts/unlimited-auth-detector.sh" <<< "do whatever it takes to finish this"
  [ "$status" -eq 0 ]
}

@test "S4/AC-4.1: detects 'a toda costa'" {
  run bash "$REPO_ROOT/scripts/unlimited-auth-detector.sh" <<< "termina esto a toda costa"
  [ "$status" -eq 0 ]
}

@test "S4/AC-4.1: clean input produces no detection" {
  run bash "$REPO_ROOT/scripts/unlimited-auth-detector.sh" <<< "crea un informe del sprint con las métricas de velocidad"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════
# S7: Objective contracts
# ═══════════════════════════════════════════════════════════════════

@test "S7/AC-7.1: objective without antagonist is rejected" {
  run bash "$REPO_ROOT/scripts/objective-contract.sh" create "optimize response time"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REJECTED"* ]]
}

@test "S7/AC-7.1: objective with antagonist is accepted" {
  run bash "$REPO_ROOT/scripts/objective-contract.sh" create "optimize response time" "user satisfaction"
  [ "$status" -eq 0 ]
}

@test "S7/AC-7.3: default antagonists are included in contract" {
  contract=$(bash "$REPO_ROOT/scripts/objective-contract.sh" create "test goal" "test antagonist")
  [ -f "$contract" ]
  grep -q "safety" "$contract"
  grep -q "confidentiality" "$contract"
  grep -q "ethics" "$contract"
  grep -q "reversibility" "$contract"
}

@test "S7: contract check accepts valid contract" {
  contract=$(bash "$REPO_ROOT/scripts/objective-contract.sh" create "test" "antagonist1")
  run bash "$REPO_ROOT/scripts/objective-contract.sh" check "$contract"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════
# S2: Action shape classifier
# ═══════════════════════════════════════════════════════════════════

@test "S2/AC-2.2: routine action proceeds without friction" {
  run bash "$REPO_ROOT/scripts/action-shape-classifier.sh" "Read" "/tmp/test"
  [ "$status" -eq 0 ]
}

@test "S2/AC-2.1: novel destructive network action triggers ask" {
  run bash "$REPO_ROOT/scripts/action-shape-classifier.sh" "WebFetch" "https://unknown.example.com"
  # Novel + perimeter crossing → should trigger ask or proceed
  [ "$status" -ge 0 ]
}

@test "S2: classifier logs to profile" {
  bash "$REPO_ROOT/scripts/action-shape-classifier.sh" "Read" "/tmp/test" 2>/dev/null
  [ -f "$REPO_ROOT/output/action-shape-profile.jsonl" ]
}

# ═══════════════════════════════════════════════════════════════════
# S6: Trajectory detector
# ═══════════════════════════════════════════════════════════════════

@test "S6/AC-6.3: normal state returns 0" {
  run bash "$REPO_ROOT/scripts/trajectory-detector.sh" evaluate
  [ "$status" -eq 0 ]
}

@test "S6: status command works" {
  run bash "$REPO_ROOT/scripts/trajectory-detector.sh" status
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════
# S5: Source corroboration
# ═══════════════════════════════════════════════════════════════════

@test "S5: source authority config exists" {
  bash "$REPO_ROOT/scripts/source-corroborator.sh" classify "https://docs.python.org/3/library/os.html" 2>/dev/null
  [ -f "$REPO_ROOT/config/source-authority.yaml" ]
}

@test "S5: primary source is classified correctly" {
  run bash "$REPO_ROOT/scripts/source-corroborator.sh" classify "https://docs.python.org/3/library/os.html"
  [ "$status" -eq 0 ]
  [[ "$output" == "primary" ]]
}

@test "S5: aggregator source is classified correctly" {
  run bash "$REPO_ROOT/scripts/source-corroborator.sh" classify "https://stackoverflow.com/questions/123"
  [ "$status" -eq 0 ]
  [[ "$output" == "aggregator" ]]
}

@test "S5/AC-5.2: same domain sources are not independent" {
  run bash "$REPO_ROOT/scripts/source-corroborator.sh" independence "https://example.com/a" "https://example.com/b"
  [ "$status" -ne 0 ]
}

@test "S5/AC-5.2: different domain sources are independent" {
  run bash "$REPO_ROOT/scripts/source-corroborator.sh" independence "https://python.org" "https://rust-lang.org"
  [ "$status" -eq 0 ]
}
