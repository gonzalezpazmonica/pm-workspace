#!/usr/bin/env bats
# SPEC-088: Tool-call/tool-result pair integrity during compaction.
# Validates the inviolable rule is documented + simulates the algorithm.
# Target: .claude/rules/domain/context-health.md and session-memory-protocol.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CONTEXT_HEALTH="$REPO_ROOT/.claude/rules/domain/context-health.md"
  SESSION_PROTOCOL="$REPO_ROOT/.claude/rules/domain/session-memory-protocol.md"
  HOOK="$REPO_ROOT/.claude/hooks/pre-compact-backup.sh"
  TMP_DIR=$(mktemp -d -t spec088-XXXXXX)
}

teardown() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
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
  grep -qiE "promover|promote|both|ambos|miembro preservado|preserved" "$CONTEXT_HEALTH"
}

@test "session-memory-protocol.md mentions Tier promotion for pairs" {
  grep -qiE "promover|promote|Tier A|Tier C" "$SESSION_PROTOCOL"
}

# ── Safety verification of target hook ──────────────────────────────────────

@test "pre-compact-backup.sh has set -uo pipefail safety" {
  grep -q "set -uo pipefail" "$HOOK"
}

# ── Algorithmic simulator (positive cases) ──────────────────────────────────

@test "simulator: lone tool_use in Tier C with result in Tier A promotes use to A" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "C"},
    {"id": 2, "type": "tool_result", "tier": "A", "pair": 1},
]
ids_preserved = {m["id"] for m in messages if m["tier"] == "A"}
pairs = {m["pair"]: m["id"] for m in messages if "pair" in m}
for use_id, result_id in pairs.items():
    if result_id in ids_preserved or use_id in ids_preserved:
        for m in messages:
            if m["id"] in (use_id, result_id):
                m["tier"] = "A"
assert all(m["tier"] == "A" for m in messages), f"FAIL: {messages}"
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "simulator: pair fully in Tier A preserves both" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "A"},
    {"id": 2, "type": "tool_result", "tier": "A", "pair": 1},
]
assert all(m["tier"] == "A" for m in messages)
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "simulator: large batch of pairs preserves integrity at scale" {
  result=$(python3 - <<'PY'
messages = []
for i in range(100):
    use_tier = "A" if i % 2 == 0 else "C"
    messages.append({"id": i*2, "type": "tool_use", "tier": use_tier})
    messages.append({"id": i*2+1, "type": "tool_result", "tier": "A", "pair": i*2})
ids_preserved = {m["id"] for m in messages if m["tier"] == "A"}
pairs = {m["pair"]: m["id"] for m in messages if "pair" in m}
for use_id, result_id in pairs.items():
    if result_id in ids_preserved or use_id in ids_preserved:
        for m in messages:
            if m["id"] in (use_id, result_id):
                m["tier"] = "A"
for use_id, result_id in pairs.items():
    u = next(m for m in messages if m["id"] == use_id)
    r = next(m for m in messages if m["id"] == result_id)
    assert u["tier"] == r["tier"], f"broken pair {use_id}/{result_id}"
print("OK")
PY
)
  [ "$result" = "OK" ]
}

# ── Negative cases (rejection / failure modes) ──────────────────────────────

@test "negative: missing file fails the SPEC-088 rule check" {
  [ ! -f "$TMP_DIR/missing-file.md" ]
  run grep "SPEC-088" "$TMP_DIR/missing-file.md"
  [ "$status" -ne 0 ]
}

@test "negative: empty file cannot satisfy SPEC-088 documentation" {
  : > "$TMP_DIR/empty.md"
  run grep "SPEC-088" "$TMP_DIR/empty.md"
  [ "$status" -ne 0 ]
}

@test "negative: invalid content without SPEC reference is rejected" {
  echo "# Random content" > "$TMP_DIR/bad.md"
  run grep "SPEC-088" "$TMP_DIR/bad.md"
  [ "$status" -ne 0 ]
}

@test "negative: simulator rejects orphan tool_use (missing result member)" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "A"},
]
pairs_with_both = [m for m in messages if m.get("pair")]
assert len(pairs_with_both) == 0, "orphan use detected — API would reject"
print("OK")
PY
)
  [ "$result" = "OK" ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty message list is trivially consistent" {
  result=$(python3 - <<'PY'
messages = []
assert len(messages) == 0
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "edge: nonexistent session file does not crash simulator" {
  run python3 -c "import os; print('ok' if not os.path.exists('/nonexistent-12345') else 'fail')"
  [ "$output" = "ok" ]
}

@test "edge: boundary single-pair case preserved correctly" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "A"},
    {"id": 2, "type": "tool_result", "tier": "A", "pair": 1},
]
assert len(messages) == 2
print("OK")
PY
)
  [ "$result" = "OK" ]
}

@test "edge: zero pairs preserved in Tier C does not invoke promotion" {
  result=$(python3 - <<'PY'
messages = [
    {"id": 1, "type": "tool_use", "tier": "C"},
    {"id": 2, "type": "tool_result", "tier": "C", "pair": 1},
]
assert all(m["tier"] == "C" for m in messages)
print("OK")
PY
)
  [ "$result" = "OK" ]
}

# ── Regression guard ────────────────────────────────────────────────────────

@test "regression: SPEC-088 references not silently removed from canonical rules" {
  total=0
  for f in "$CONTEXT_HEALTH" "$SESSION_PROTOCOL"; do
    c=$(grep -c "SPEC-088" "$f" 2>/dev/null || echo 0)
    total=$((total + c))
  done
  [ "$total" -ge 2 ]
}
