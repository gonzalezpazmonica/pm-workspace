#!/usr/bin/env bats
# SCL-008 — human authority boundary for learning recall

set -uo pipefail

setup_file() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT
}

setup() {
  RECALL="$REPO_ROOT/scripts/learning-recall.sh"
  HOOK="$REPO_ROOT/.claude/hooks/learning-recall-hook.sh"
  PROP="$REPO_ROOT/scripts/learning-proposal.sh"
  PERSIST="$REPO_ROOT/scripts/learning-persist.sh"
  TMPD="$(mktemp -d -t scl-s8-XXXXXX)"
  mkdir -p "$TMPD/vault/learning" "$TMPD/proposals"
  export SCL_VAULT_DIR="$TMPD/vault"
  export SCL_RECALL_LOG="$TMPD/recall.jsonl"
  export SCL_CRITERIO_PATH="$TMPD/CRITERIO.md"
  export SCL_NODE_PATH="bash"
  export SCL_VAULT_CLI="$TMPD/fake-vault-cli.sh"
  cat > "$SCL_VAULT_CLI" <<'EOF'
#!/usr/bin/env bash
vault=""
while [[ $# -gt 0 ]]; do
  case "$1" in --path) vault="$2"; shift 2 ;; *) shift ;; esac
done
python3 - "$vault" <<'PY'
import glob, json, os, sys
print(json.dumps([{'path': p, 'score': 42.0, 'snippet': 'hostile proposal text'} for p in glob.glob(os.path.join(sys.argv[1], 'learning', '*.md'))]))
PY
EOF
  printf '%s\n' \
    '# Criterio fixture' \
    'CRIT-034 — Credenciales locales' \
    '  principio: Las credenciales se resuelven desde un vault local.' \
    '  provenance: human_authored' > "$SCL_CRITERIO_PATH"
  echo 'credential evidence' > "$TMPD/evidence.txt"
  bash "$PROP" --origin credential-rule --evidence "$TMPD/evidence.txt" \
    --diagnosis 'hardcoded credential' --change 'resolve credential from local vault' \
    --target criterio --criterion-id CRIT-034 --output-dir "$TMPD/proposals" \
    --graph-index "$TMPD/graph.jsonl" >/dev/null
  PROPOSAL=$(ls "$TMPD/proposals/"*.md)
  sed -i 's/^provenance: .*/provenance: human_authored/;s/^lifecycle: .*/lifecycle: active/' "$PROPOSAL"
  bash "$PERSIST" --file "$PROPOSAL" >/dev/null
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "TS-02: active human proposal resolves principle from CRITERIO.md" {
  run bash "$RECALL" --query 'credential local vault' --mode effective \
    --criterio "$SCL_CRITERIO_PATH" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); h=d['effective_hits'][0]; assert h['criterion_id']=='CRIT-034'; assert h['principle']=='Las credenciales se resuelven desde un vault local.'"
}

@test "TS-03: linked INFERRED criterion is rejected" {
  sed -i 's/provenance: human_authored/provenance: INFERRED/' "$SCL_CRITERIO_PATH"
  run bash "$RECALL" --query 'credential local vault' --mode effective \
    --criterio "$SCL_CRITERIO_PATH" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['effective_hits']==[]; assert d['rejected_hits'] >= 1"
}

@test "TS-11: Claude and OpenCode payloads produce identical canonical context" {
  run bash -c "printf '%s' '{\"content\":\"credential local vault configuration\"}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_CRITERIO_PATH='$SCL_CRITERIO_PATH' SCL_RECALL_LOG='$TMPD/recall.jsonl' SCL_NODE_PATH=bash SCL_VAULT_CLI='$SCL_VAULT_CLI' bash '$HOOK'"
  [ "$status" -eq 0 ]
  claude_output="$output"
  run bash -c "printf '%s' '{\"prompt_text\":\"credential local vault configuration\"}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_CRITERIO_PATH='$SCL_CRITERIO_PATH' SCL_RECALL_LOG='$TMPD/recall.jsonl' SCL_NODE_PATH=bash SCL_VAULT_CLI='$SCL_VAULT_CLI' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ "$output" = "$claude_output" ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'CRIT-034' in d['hookSpecificOutput']['additionalContext']"
}

@test "TS-10: learning operations do not modify foundational files" {
  criterio_before=$(sha256sum "$REPO_ROOT/CRITERIO.md" | cut -d' ' -f1)
  constitution_before=$(sha256sum "$REPO_ROOT/.claude/CONSTITUCION.md" | cut -d' ' -f1)
  bash "$RECALL" --query 'credential local vault' --mode effective --criterio "$SCL_CRITERIO_PATH" --json >/dev/null
  [ "$criterio_before" = "$(sha256sum "$REPO_ROOT/CRITERIO.md" | cut -d' ' -f1)" ]
  [ "$constitution_before" = "$(sha256sum "$REPO_ROOT/.claude/CONSTITUCION.md" | cut -d' ' -f1)" ]
}

@test "security: search results outside the vault are rejected" {
  outside="$TMPD/outside.md"
  cp "$TMPD/vault/learning/"*.md "$outside"
  cat > "$SCL_VAULT_CLI" <<EOF
#!/usr/bin/env bash
printf '%s\n' '[{"path":"$outside","score":99.0}]'
EOF
  run bash "$RECALL" --query 'credential local vault' --mode effective --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['effective_hits']==[]; assert d['rejected_hits']==1"
}
