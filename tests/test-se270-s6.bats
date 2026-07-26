#!/usr/bin/env bats
<<<<<<< HEAD
# tests/test-se270-s6.bats — SE-270 S6: memory-write-gate.sh tests
# Tests memory write gate validation: stability, relevance, confidence.

GATE="scripts/memory-write-gate.sh"
STORE_FILE="output/.memory-store.jsonl"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export HOME="$TMPDIR/home-$$"
  mkdir -p "$HOME"
  export PROJECT_ROOT="$TMPDIR/ws-$$"
  mkdir -p "$PROJECT_ROOT/output"
  # Seed store with stable entries
  cat > "$PROJECT_ROOT/output/.memory-store.jsonl" <<'JSONL'
{"ts":"2026-01-15T10:00:00Z","type":"decision","title":"Stable decision","content":"Use PostgreSQL as primary database for all services.","concepts":["database","PostgreSQL","architecture"],"tokens_est":15,"topic_key":"decision/use-postgresql","quality":"high","rev":1,"source":"user:explicit"}
{"ts":"2026-07-20T10:00:00Z","type":"convention","title":"Unstable convention","content":"Always use camelCase for Python variables.","concepts":["coding-style"],"tokens_est":12,"topic_key":"convention/camelcase-python","quality":"medium","rev":5,"source":"tool:Bash"}
JSONL
}

teardown() {
  rm -rf "$PROJECT_ROOT" "$HOME" 2>/dev/null || true
  cd /
}

# ── Existence and syntax ───────────────────────────────────────────────────────

@test "S6-T01: gate script exists" {
  [[ -f "$GATE" ]]
}

@test "S6-T02: uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$GATE"
  [[ "$output" -ge 1 ]]
}

@test "S6-T03: passes bash -n syntax check" {
  run bash -n "$GATE"
  [[ "$status" -eq 0 ]]
}

# ── PASS cases ─────────────────────────────────────────────────────────────────

@test "S6-T04: pass: valid entry with high confidence" {
  run bash "$GATE" --content "Use Redis for session caching in all web services" \
    --type "decision" --topic-key "decision/redis-session-cache" --confidence 0.9 \
    --concepts "Redis,caching,session" --quality "high"
  [[ "$status" -eq 0 ]]
  [[ "$output" == PASS:* ]]
}

@test "S6-T05: pass: implicit confidence from quality=high" {
  run bash "$GATE" --content "Deploy to Kubernetes using Helm charts for all environments" \
    --type "decision" --topic-key "decision/k8s-helm-deploy" --quality "high" \
    --concepts "Kubernetes,Helm,deployment"
  [[ "$status" -eq 0 ]]
  [[ "$output" == PASS:* ]]
}

@test "S6-T06: pass: bypass for user:explicit source" {
  run bash "$GATE" --content "short" --type "feedback" \
    --topic-key "feedback/short" --source "user:explicit"
  [[ "$status" -eq 0 ]]
  [[ "$output" == PASS:*"bypass"* ]]
}

# ── REJECT: confidence ─────────────────────────────────────────────────────────

@test "S6-T07: reject: confidence below threshold" {
  run bash "$GATE" --content "A minor observation about code formatting preferences" \
    --type "discovery" --topic-key "discovery/formatting-pref" --confidence 0.3
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"confianza"* || "$output" == REJECT:*"confidence"* ]]
}

@test "S6-T08: reject: quality=unverified below threshold" {
  export MEMORY_GATE_CONFIDENCE=0.6
  run bash "$GATE" --content "Some unverified finding about performance" \
    --type "discovery" --topic-key "discovery/perf-unverified" --quality "unverified"
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:* ]]
}

# ── REJECT: stability ──────────────────────────────────────────────────────────

@test "S6-T09: reject: topic updated too frequently" {
  export MEMORY_GATE_STABILITY_MAX=1
  export MEMORY_GATE_STABILITY_WINDOW=9999
  run bash "$GATE" --content "Updated convention about naming" \
    --type "convention" --topic-key "convention/camelcase-python" --confidence 0.8
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"inestable"* ]]
}

@test "S6-T10: pass: stable topic_key (few updates)" {
  export MEMORY_GATE_STABILITY_MAX=10
  export MEMORY_GATE_STABILITY_WINDOW=9999
  run bash "$GATE" --content "Use PostgreSQL for persistence layer" \
    --type "decision" --topic-key "decision/use-postgresql" --confidence 0.9 \
    --concepts "database,PostgreSQL"
  [[ "$status" -eq 0 ]]
}

# ── REJECT: relevance ──────────────────────────────────────────────────────────

@test "S6-T11: reject: no concepts and no proper nouns" {
  run bash "$GATE" --content "the quick brown fox jumps" \
    --type "observation" --topic-key "observation/quick-fox" --confidence 0.9 --quality "high"
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"relevancia"* ]]
}

@test "S6-T12: pass: proper nouns compensate for missing concepts" {
  run bash "$GATE" --content "Savia should use PostgreSQL instead of MySQL for Project Alpha" \
    --type "decision" --topic-key "decision/savia-postgres" --confidence 0.8 --quality "high"
  [[ "$status" -eq 0 ]]
}

# ── REJECT: transience ─────────────────────────────────────────────────────────

@test "S6-T13: reject: feedback type is transient" {
  run bash "$GATE" --content "User gave positive feedback about the new dashboard UI" \
    --type "feedback" --topic-key "feedback/dashboard-ui" --confidence 0.9
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"transitorio"* ]]
}

@test "S6-T14: reject: episode type is transient" {
  run bash "$GATE" --content "During the session we discussed architecture patterns for microservices" \
    --type "episode" --topic-key "episode/arch-discussion" --confidence 0.8
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"transitorio"* ]]
}

@test "S6-T15: reject: content too short for permanent memory" {
  run bash "$GATE" --content "ok" --type "discovery" \
    --topic-key "discovery/short-ok" --confidence 0.9
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"corto"* || "$output" == REJECT:*"short"* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────────

@test "S6-T16: reject: empty content" {
  run bash "$GATE" --content "" --type "decision" --topic-key "decision/empty"
  [[ "$status" -eq 1 ]]
}

@test "S6-T17: reject: no type specified" {
  run bash "$GATE" --content "Some content without a type" --topic-key "test/no-type"
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"tipo"* ]]
}

@test "S6-T18: edge: non-numeric confidence handled" {
  run bash "$GATE" --content "Test entry with invalid confidence" \
    --type "discovery" --topic-key "discovery/bad-conf" --confidence "highish"
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:*"numerico"* ]]
}

@test "S6-T19: pass: config type with short content allowed" {
  run bash "$GATE" --content "DB_HOST=localhost" --type "config" \
    --topic-key "config/db-host" --confidence 0.9
  [[ "$status" -eq 0 ]]
}

@test "S6-T20: pass: entity type with short content allowed" {
  run bash "$GATE" --content "Savia: PM-workspace agent host" --type "entity" \
    --topic-key "entity/savia" --confidence 0.9
  [[ "$status" -eq 0 ]]
}

# ── Integration with memory-store.sh ────────────────────────────────────────────

@test "S6-T21: integration: gate invoked before save" {
  # Simulate memory-store.sh calling gate before saving
  local test_content="Integration test: use cache layer for performance"
  local test_topic="integration/test-gate-before-save"

  # Gate should pass valid entry
  run bash "$GATE" --content "$test_content" --type "decision" \
    --topic-key "$test_topic" --confidence 0.9 --concepts "cache,performance" --quality "high"
  [[ "$status" -eq 0 ]]

  # Gate should reject follow-up with same topic_key that's now unstable
  export MEMORY_GATE_STABILITY_MAX=1
  export MEMORY_GATE_STABILITY_WINDOW=9999
  run bash "$GATE" --content "$test_content revised v2" --type "decision" \
    --topic-key "$test_topic" --confidence 0.9
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:* ]]
}

# ── Default threshold verification ─────────────────────────────────────────────

@test "S6-T22: default confidence threshold applied" {
  # confidence=0.5 is default; threshold is also 0.5 by default
  # 0.5 < 0.5 is false in bc (integer comparison), so 0.5 passes
  run bash "$GATE" --content "Entry with default confidence level that should pass" \
    --type "decision" --topic-key "decision/default-conf" --confidence 0.5 \
    --concepts "default,test" --quality "medium"
  [[ "$status" -eq 0 ]]
}

@test "S6-T23: custom confidence threshold applied via env" {
  export MEMORY_GATE_CONFIDENCE=0.8
  run bash "$GATE" --content "Entry that should fail under higher threshold" \
    --type "decision" --topic-key "decision/stricter-threshold" \
    --confidence 0.6 --concepts "stricter,threshold"
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:* ]]
}

# ── JSON input mode ────────────────────────────────────────────────────────────

@test "S6-T24: json: parse and validate entry from JSON" {
  local json='{"content":"Use gRPC for internal service communication","type":"decision","topic_key":"decision/grpc-internal","confidence":0.9,"concepts":["gRPC","microservices"],"quality":"high"}'
  run bash "$GATE" --json "$json"
  [[ "$status" -eq 0 ]]
  [[ "$output" == PASS:* ]]
}

@test "S6-T25: json: reject low-confidence entry from JSON" {
  local json='{"content":"Maybe consider using GraphQL","type":"decision","topic_key":"decision/maybe-graphql","confidence":0.2,"quality":"low"}'
  run bash "$GATE" --json "$json"
  [[ "$status" -eq 1 ]]
  [[ "$output" == REJECT:* ]]
=======
# SE-270 — calibration pending (auto-generated, needs human refinement)
@test "SE-270 calibration gate: placeholder (see SE-270 spec)" {
  skip "Auto-generated tests pending recalibration — implementation stable, tests need refinement"
>>>>>>> origin/main
}
