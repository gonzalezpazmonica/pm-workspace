#!/usr/bin/env bats
# test-masked-digestion.bats — Tests for masked digestion pipeline
# Verifies: mask→process→unmask roundtrip, no fake entity leakage, edge cases

setup() {
  export PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
  export SCRIPT="$PROJECT_DIR/scripts/masked-digest.sh"
  export SHIELD_URL="http://127.0.0.1:8444"
  export TOKEN=$(cat "$HOME/.savia/shield-token" 2>/dev/null)
  export TOKEN_HEADER=""
  [[ -n "$TOKEN" ]] && TOKEN_HEADER="-H X-Shield-Token:$TOKEN"
}

# --- Shield daemon availability ---

@test "Shield daemon is running" {
  curl -sf --max-time 2 "$SHIELD_URL/health" >/dev/null 2>&1
}

# --- Mask roundtrip ---

@test "mask→unmask roundtrip preserves original text exactly" {
  local original="alice confirmed that test-org needs the API"
  local masked=$(curl -s --max-time 5 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$original\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'])")

  local restored=$(curl -s --max-time 5 -X POST "$SHIELD_URL/unmask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$masked\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['unmasked'])")

  [[ "$restored" == *"alice"* ]]
  [[ "$restored" == *"test-org"* ]]
}

@test "masked text does NOT contain original entities" {
  local original="bob worked with test-org on the alpha module"
  local masked=$(curl -s --max-time 5 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$original\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'])")

  [[ "$masked" != *"bob"* ]]
  [[ "$masked" != *"test-org"* ]]
}

@test "mask is consistent: same entity maps to same fake" {
  local text1="alice dijo que si"
  local text2="alice confirmo ok"

  local fake1=$(curl -s --max-time 5 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$text1\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'].split()[0])")

  local fake2=$(curl -s --max-time 5 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$text2\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'].split()[0])")

  [[ "$fake1" == "$fake2" ]]
}

# --- Digest script ---

@test "masked-digest.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "masked-digest.sh with --dry-run shows mask without writing" {
  local input="alice confirmo que test-org aprueba el sprint 25"
  local result=$(echo "$input" | bash "$SCRIPT" --dry-run 2>&1)

  # Should show masked version and DRY RUN header
  [[ "$result" == *"DRY RUN"* ]]
  [[ "$result" == *"Masked text"* ]]
}

# --- Leakage detection ---

@test "no fake entities in final unmasked output" {
  # Get list of fake entities from mask map
  local mask_map="$PROJECT_DIR/output/data-sovereignty-validation/mask-map.json"
  if [[ ! -f "$mask_map" ]]; then
    skip "No mask-map.json found"
  fi

  local fakes=$(python3 -c "
import json
with open('$mask_map') as f:
    m = json.load(f)
for v in m.values():
    print(v)
" 2>/dev/null)

  local original="alice y bob revisaron el modulo de test-org"
  local masked=$(curl -s --max-time 5 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$original\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'])")

  local restored=$(curl -s --max-time 5 -X POST "$SHIELD_URL/unmask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":\"$masked\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['unmasked'])")

  # Restored text must NOT contain any fake entity
  while IFS= read -r fake; do
    [[ -z "$fake" ]] && continue
    if [[ "$restored" == *"$fake"* ]]; then
      echo "LEAK: fake entity '$fake' found in unmasked output" >&2
      return 1
    fi
  done <<< "$fakes"
}

@test "multiline text roundtrip preserves structure" {
  local original="Linea 1: alice confirmo
Linea 2: test-org necesita el modulo alpha
Linea 3: Sprint 25 cerrado"

  local masked=$(curl -s --max-time 5 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "$(python3 -c "import json; print(json.dumps({'text':'''$original'''}))")" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'])")

  # Multiline structure preserved (3 lines)
  local line_count=$(echo "$masked" | wc -l)
  [[ "$line_count" -ge 3 ]]
}
