#!/usr/bin/env bats
# SPEC-088: Tool-call/tool-result pair integrity during compaction
# Validates that the inviolable rule is documented in canonical locations
# AND that the conceptual classification logic preserves pairs.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CONTEXT_HEALTH="$REPO_ROOT/.claude/rules/domain/context-health.md"
  SESSION_PROTOCOL="$REPO_ROOT/.claude/rules/domain/session-memory-protocol.md"
}

# ── Documentation invariants ────────────────────────────────────────────────

@test "context-health.md exists" {
  [ -f "$CONTEXT_HEALTH" ]
}

@test "session-memory-protocol.md exists" {
  [ -f "$SESSION_PROTOCOL" ]
}

@test "context-health.md cites SPEC-088" {
  grep -q "SPEC-088" "$CONTEXT_HEALTH"
}

@test "session-memory-protocol.md cites SPEC-088" {
  grep -q "SPEC-088" "$SESSION_PROTOCOL"
}

@test "context-health.md declares the inviolable rule" {
  grep -qiE "(NUNCA|NEVER).*tool_use.*tool_result|inviolable|integridad de pares" "$CONTEXT_HEALTH"
}

@test "session-memory-protocol.md declares pair-integrity check" {
  grep -qiE "(integridad|integrity|pair).*tool_use|tool_use.*tool_result|pares tool" "$SESSION_PROTOCOL"
}

@test "context-health.md mentions promotion of paired members" {
  # Rule: if one member is preserved, the other must be promoted
  grep -qiE "promover|promote|both|ambos|miembro preservado|preserved" "$CONTEXT_HEALTH"
}

@test "session-memory-protocol.md mentions Tier promotion for pairs" {
  grep -qiE "promover|promote|Tier A|Tier C" "$SESSION_PROTOCOL"
}

# ── Conceptual logic test (Python simulator) ────────────────────────────────
# The actual classification happens in the Anthropic harness, not in our hook.
# This test verifies the algorithm we document IS correct by simulating it.

@test "pair-integrity simulator: lone tool_use in Tier C with paired result in Tier A → promote use to A" {
  result=$(python3 - <<'PY'
# Simulate the rule: "if a member is preserved, promote both"
messages = [
    {"id": 1, "type": "tool_use", "tier": "C"},      # would be dropped
    {"id": 2, "type": "tool_result", "tier": "A", "pair": 1},  # preserved
]
# Apply rule
ids_preserved = {m["id"] for m in messages if m["tier"] == "A"}
pairs = {m["pair"]: m["id"] for m in messages if "pair" in m}
for use_id, result_id in pairs.items():
    if result_id in ids_preserved or use_id in ids_preserved:
        for m in messages:
            if m["id"] in (use_id, result_id):
                m["tier"] = "A"
# Verify both promoted
assert all(m["tier"] == "A" for m in messages), f"FAIL: {messages}"
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "pair-integrity simulator: both members in Tier C → both safely dropped" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "C"},
    {"id": 2, "type": "tool_result", "tier": "C", "pair": 1},
]
# Both Tier C: rule does not promote (no member preserved)
ids_preserved = {m["id"] for m in messages if m["tier"] == "A"}
pairs = {m["pair"]: m["id"] for m in messages if "pair" in m}
for use_id, result_id in pairs.items():
    if result_id in ids_preserved or use_id in ids_preserved:
        for m in messages:
            if m["id"] in (use_id, result_id):
                m["tier"] = "A"
# Verify both still C
assert all(m["tier"] == "C" for m in messages), f"FAIL: {messages}"
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "pair-integrity simulator: pair fully in Tier A → both preserved" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "A"},
    {"id": 2, "type": "tool_result", "tier": "A", "pair": 1},
]
# Already preserved
assert all(m["tier"] == "A" for m in messages)
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "pair-integrity simulator: orphan tool_use without result → can be dropped (no pair to break)" {
  # An orphan exists in malformed history; rule only applies when both exist
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "C"},  # no paired result
]
pairs = {m["pair"]: m["id"] for m in messages if "pair" in m}
# Empty pairs → no promotion needed
assert pairs == {}
print("OK")
PY
)
  [ "$result" = "OK" ]
}

# ── Regression guard: documentation must not lose the rule ──────────────────

@test "regression: SPEC-088 references not silently removed from rules" {
  # Count refs across canonical locations — must be ≥2
  count=$(grep -lc "SPEC-088" "$CONTEXT_HEALTH" "$SESSION_PROTOCOL" 2>/dev/null | wc -l)
  [ "$count" -ge 2 ]
}
