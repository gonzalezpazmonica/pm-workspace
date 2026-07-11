#!/usr/bin/env bats
# tests/test-se-263-s234.bats — Tests for SE-263 S2+S3+S4

# ── S2: Instance Identity ──

@test "S2-T01: instance-card.sh exists and is executable" {
  [[ -f "scripts/instance-card.sh" ]]
  [[ -x "scripts/instance-card.sh" ]]
}

@test "S2-T02: instance-card verify rejects missing card" {
  run bash scripts/instance-card.sh verify --id nonexistent
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "not found" ]]
}

@test "S2-T03: instance-card show rejects missing card" {
  run bash scripts/instance-card.sh show --id nonexistent
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "not found" ]]
}

@test "S2-T04: instance-card help works" {
  run bash scripts/instance-card.sh --help
  [[ "$status" -eq 0 ]]
}

@test "S2-T05: generate synthetic card and verify it" {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/test-instance.card.json" << 'JSON'
{
  "schemaVersion": "1.0",
  "instanceId": "test-instance",
  "principal": "test-operator",
  "publicKey": "dGVzdA==",
  "createdAt": "2026-07-11T00:00:00Z",
  "skills": [
    {"id": "situacion.query", "maxLevel": 2}
  ],
  "status": "active",
  "signature": "dGVzdHNpZw==",
  "signedBy": "test-instance"
}
JSON
  run bash scripts/instance-card.sh verify --id test-instance --registry "$dir"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "VALID" ]]
  rm -rf "$dir"
}

@test "S2-T06: verify detects revoked card" {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/revoked.card.json" << 'JSON'
{"instanceId":"revoked","principal":"x","status":"revoked","publicKey":"","signature":"x"}
JSON
  run bash scripts/instance-card.sh verify --id revoked --registry "$dir"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "REVOKED" ]]
  rm -rf "$dir"
}

@test "S2-T07: verify detects unsigned card" {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/unsigned.card.json" << 'JSON'
{"instanceId":"unsigned","principal":"x","status":"active","publicKey":""}
JSON
  run bash scripts/instance-card.sh verify --id unsigned --registry "$dir"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "UNSIGNED" ]]
  rm -rf "$dir"
}

# ── S3: Domain Export ──

@test "S3-T01: federation export rules file exists" {
  [[ -f "rules/federation-export.rules.yaml" ]]
}

@test "S3-T02: export rules have prompt injection guard enabled" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/federation-export.rules.yaml'))
assert d['prompt_injection']['treat_peer_content_as_untrusted'] == True
assert d['prompt_injection']['quarantine_on_detection'] == True
"
}

# ── S4: Git Plane + Agent Index ──

@test "S4-T01: agent-index-generate.sh exists and is executable" {
  [[ -f "scripts/agent-index-generate.sh" ]]
  [[ -x "scripts/agent-index-generate.sh" ]]
}

@test "S4-T02: agent-index-generate creates valid JSON from cards" {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/cards"
  cat > "$dir/cards/test.card.json" << 'JSON'
{"instanceId":"test","principal":"op","status":"active","publicKey":"","signature":"x"}
JSON
  local out="$dir/index.json"
  run bash scripts/agent-index-generate.sh "$dir/cards" "$out"
  [[ "$status" -eq 0 ]]
  [[ -f "$out" ]]
  python3 -c "import json; d=json.load(open('$out')); assert d['agents']['test']['principal']=='op'"
  rm -rf "$dir"
}

@test "S4-T03: agent-index-generate skips revoked cards" {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/cards"
  cat > "$dir/cards/revoked.card.json" << 'JSON'
{"instanceId":"revoked","principal":"x","status":"revoked","publicKey":"","signature":"x"}
JSON
  local out="$dir/index.json"
  run bash scripts/agent-index-generate.sh "$dir/cards" "$out"
  python3 -c "import json; d=json.load(open('$out')); assert len(d['agents'])==0"
  rm -rf "$dir"
}

@test "S4-T04: agent-index-generate is deterministic" {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/cards"
  cat > "$dir/cards/a.card.json" << 'JSON'
{"instanceId":"a","principal":"x","status":"active","publicKey":"","signature":"x"}
JSON
  bash scripts/agent-index-generate.sh "$dir/cards" "$dir/index1.json"
  bash scripts/agent-index-generate.sh "$dir/cards" "$dir/index2.json"
  run diff "$dir/index1.json" "$dir/index2.json"
  [[ "$status" -eq 0 ]]
  rm -rf "$dir"
}
