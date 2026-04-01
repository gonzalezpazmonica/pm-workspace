#!/usr/bin/env bats
# test-masked-digestion-e2e.bats — End-to-end leakage tests
# Verifies that NO fake entity survives into final unmasked output

setup() {
  export PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
  export SHIELD_URL="http://127.0.0.1:8444"
  export TOKEN=$(cat "$HOME/.savia/shield-token" 2>/dev/null || true)
  export TOKEN_HEADER=""
  [[ -n "$TOKEN" ]] && TOKEN_HEADER="-H X-Shield-Token:$TOKEN" || true
  export MASK_MAP="$PROJECT_DIR/output/data-sovereignty-validation/mask-map.json"
}

daemon_available() {
  curl -sf --max-time 2 "$SHIELD_URL/health" >/dev/null 2>&1
}

get_all_fakes() {
  python3 -c "
import json
with open('$MASK_MAP') as f:
    m = json.load(f)
for v in m.values():
    print(v)
" 2>/dev/null
}

get_all_reals() {
  python3 -c "
import json
with open('$MASK_MAP') as f:
    m = json.load(f)
for k in m.keys():
    print(k)
" 2>/dev/null
}

mask_text() {
  local escaped=$(printf '%s' "$1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  curl -s --max-time 10 -X POST "$SHIELD_URL/mask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":$escaped}" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'])"
}

unmask_text() {
  local escaped=$(printf '%s' "$1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  curl -s --max-time 10 -X POST "$SHIELD_URL/unmask" \
    -H "Content-Type: application/json" $TOKEN_HEADER \
    -d "{\"text\":$escaped}" | python3 -c "import sys,json; print(json.load(sys.stdin)['unmasked'])"
}

@test "e2e: complex paragraph with multiple entities roundtrips clean" {
  daemon_available || skip "Shield daemon not running"
  [[ ! -f "$MASK_MAP" ]] && skip "No mask-map.json"

  local original="alice confirmed in the test-org meeting that bob \
will lead the integration of module-alpha with the beta system. carol \
will review the gamma component before sprint 26. dave assigned eve \
to the support team for module-delta."

  local masked=$(mask_text "$original")
  # Simulate Claude adding analysis (with fake names)
  local claude_response="$masked

## Summary
$(echo "$masked" | head -1). 3 owners and 2 systems identified."

  local final=$(unmask_text "$claude_response")

  # No fake entity in final output
  while IFS= read -r fake; do
    [[ -z "$fake" ]] && continue
    [[ ${#fake} -lt 3 ]] && continue
    if [[ "$final" == *"$fake"* ]]; then
      echo "LEAK: '$fake' in final output" >&2
      return 1
    fi
  done <<< "$(get_all_fakes)"

  # All real entities restored
  [[ "$final" == *"alice"* ]]
  [[ "$final" == *"test-org"* ]]
  [[ "$final" == *"bob"* ]]
}

@test "e2e: masked text contains ZERO real entities" {
  daemon_available || skip "Shield daemon not running"
  [[ ! -f "$MASK_MAP" ]] && skip "No mask-map.json"

  local original="test-org, alice, bob, module-alpha, gamma, module-delta"
  local masked=$(mask_text "$original")

  while IFS= read -r real; do
    [[ -z "$real" ]] && continue
    [[ ${#real} -lt 3 ]] && continue
    if [[ "$masked" == *"$real"* ]]; then
      echo "EXPOSURE: '$real' visible in masked text" >&2
      return 1
    fi
  done <<< "$(get_all_reals)"
}

@test "e2e: mask map has sufficient coverage for project" {
  daemon_available || skip "Shield daemon not running"
  [[ ! -f "$MASK_MAP" ]] && skip "No mask-map.json"

  local count=$(MMPATH="$MASK_MAP" python3 -c "import json,os; print(len(json.load(open(os.environ['MMPATH']))))" 2>/dev/null)

  # Minimum coverage: at least 20 entity mappings
  [[ "$count" -ge 20 ]]
}

@test "e2e: markdown formatting survives roundtrip" {
  daemon_available || skip "Shield daemon not running"
  local original="## Meeting with test-org

- **alice**: confirmed deadline
- **bob**: will lead module-alpha
- Pending: review with carol

> Note: test-org needs delivery before Sprint 26"

  local masked=$(mask_text "$original")
  local restored=$(unmask_text "$masked")

  # Markdown structure preserved
  [[ "$restored" == *"## Meeting"* ]]
  [[ "$restored" == *"- **"* ]]
  [[ "$restored" == *"> Note:"* ]]
  # Real entities restored
  [[ "$restored" == *"test-org"* ]]
  [[ "$restored" == *"alice"* ]]
}

@test "e2e: handles in member profiles survive roundtrip" {
  daemon_available || skip "Shield daemon not running"
  local original="@alice.test confirmed. @bob.test will lead."
  local masked=$(mask_text "$original")
  local restored=$(unmask_text "$masked")

  # Handles should be restored or preserved
  [[ "$restored" == *"alice"* ]] || [[ "$restored" == *"Alice"* ]]
}
