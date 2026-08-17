#!/usr/bin/env bats
# SCL-003 — Recall operativo: recuperar lecciones de la cúpula cuando se trabaja
# Ref: docs/specs/SCL-003-recall-operativo.spec.md

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
  TMPD="$(mktemp -d -t scl-s3-XXXXXX)"
  mkdir -p "$TMPD/vault/learning" "$TMPD/proposals"
  export SCL_VAULT_DIR="$TMPD/vault"
  export SCL_PROPOSALS_DIR="$TMPD/proposals"
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
print(json.dumps([{'path': p, 'score': 42.0, 'snippet': 'fixture'} for p in glob.glob(os.path.join(sys.argv[1], 'learning', '*.md'))]))
PY
EOF
  printf '%s\n' \
    '# Criterio fixture' \
    'CRIT-034 — Diagnostico obligatorio' \
    '  principio: Exigir diagnostico no vacio antes de cambiar el hook.' \
    '  provenance: human_authored' > "$SCL_CRITERIO_PATH"
  # Crear una lección persistida en la cúpula de prueba
  echo "ev-s3" > "$TMPD/ev.txt"
  bash "$PROP" --origin "leccion: el hook de captura pierde diagnostico" \
    --evidence "$TMPD/ev.txt" --diagnosis "la captura generaba ruido sin causa raiz" \
    --change "exigir diagnostico no vacio" --target criterio --trigger ledger \
    --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  bash "$PERSIST" --file "$f" >/dev/null 2>&1
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "SCL-008 TS-01: propuesta INFERRED relevante permanece en sombra" {
  run bash "$RECALL" --query "hook de captura diagnostico" --top 3 --mode effective --criterio "$SCL_CRITERIO_PATH" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['effective_hits'] == []; assert d['shadow_hits'] >= 1"
}

@test "AC-2: recall sin contexto relacionado no produce ruido (exit 0, 0 hits)" {
  run bash "$RECALL" --query "receta de paella valenciana" --top 3
  [ "$status" -eq 0 ]
  [[ "$output" != *"LP-"* ]]
}

@test "SCL-008 TS-05: shadow mide sin emitir contexto" {
  run bash "$RECALL" --query "hook captura diagnostico" --top 3 --mode shadow --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['effective_hits'] == []; assert d['shadow_hits'] >= 1"
}

@test "AC-4: recall registra en el log de utilidad (recall.jsonl)" {
  bash "$RECALL" --query "hook captura diagnostico" --top 3 >/dev/null 2>&1
  [ -f "$TMPD/recall.jsonl" ]
  python3 - "$TMPD/recall.jsonl" <<'PY'
import json, sys
d = json.loads(open(sys.argv[1], encoding='utf-8').read().splitlines()[-1])
assert 'query_hash' in d and 'query' not in d
assert d['shadow_hits'] >= 1
PY
}

@test "SCL-008 TS-01: hook no inyecta propuestas inferidas" {
  run bash -c "printf '%s' '{\"content\":\"voy a mejorar el hook de captura de memoria que pierde diagnostico\"}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_RECALL_LOG='$TMPD/recall.jsonl' SCL_NODE_PATH=bash SCL_VAULT_CLI='$SCL_VAULT_CLI' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "AC-6: hook NO inyecta en prompt no relacionado (umbral de score)" {
  run bash -c "printf '%s' '{\"content\":\"hazme un resumen del tiempo en Madrid\"}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_RECALL_LOG='$TMPD/recall.jsonl' SCL_NODE_PATH=bash SCL_VAULT_CLI='$SCL_VAULT_CLI' bash '$HOOK'"
  [[ "$output" != *"Lecciones aprendidas relevantes"* ]]
}

@test "AC-7: hook nunca bloquea (exit 0 siempre)" {
  run bash -c "printf '%s' '{}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_RECALL_LOG='$TMPD/recall.jsonl' SCL_NODE_PATH=bash SCL_VAULT_CLI='$SCL_VAULT_CLI' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "SCL-008 TS-07: log no persiste el prompt" {
  secret="credencial-secreta-no-persistir"
  bash "$RECALL" --query "$secret" --mode shadow --json >/dev/null
  hash=$(printf '%s' "$secret" | sha256sum | cut -d' ' -f1)
  grep -q "$hash" "$TMPD/recall.jsonl"
  ! grep -q "$secret" "$TMPD/recall.jsonl"
}
