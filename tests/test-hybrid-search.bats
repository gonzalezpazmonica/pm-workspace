#!/usr/bin/env bats
# BATS tests for hybrid-search.py (SE-342 S6 / Labs L22)
# Ref: SE-342 S6, hypothesis l22-vector-store-hybrid.md, CRIT-001

SCRIPT="scripts/hybrid-search.py"
IDXDIR="$(mktemp -d -t hs.XXXXXX)"
IDX="$IDXDIR/index.json"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  # deterministic dome fixture: 3 markdown notes
  mkdir -p "$IDXDIR/notes"
  cat > "$IDXDIR/notes/riego.md" <<'EOF'
---
title: Riego de precisión
---
El riego por goteo optimiza el agua del cultivo de tomate.
EOF
  cat > "$IDXDIR/notes/plagas.md" <<'EOF'
---
title: Plagas
---
Detección foliar de plagas con visión computacional en cultivos.
EOF
  cat > "$IDXDIR/notes/energia.md" <<'EOF'
---
title: Energía
---
Comunidades energéticas rurales y balance de red fotovoltaica.
EOF
  # disable embeddings (local endpoint unreachable by default) -> pure BM25 path
  export SAVIA_EMBED_URL="http://127.0.0.1:1/nope"
  rm -f "$IDX"
}

teardown() {
  rm -rf "$IDXDIR"
  cd /
}

@test "script exists and executable" {
  [[ -x "$SCRIPT" ]]
}

@test "py_compile OK" {
  run python3 -m py_compile "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "index builds over notes dir" {
  run python3 "$SCRIPT" index --dir "$IDXDIR/notes" --out "$IDX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"indexed 3 notes"* ]]
  [[ -f "$IDX" ]]
}

@test "query returns riego note for 'riego agua tomate'" {
  python3 "$SCRIPT" index --dir "$IDXDIR/notes" --out "$IDX" >/dev/null
  run python3 "$SCRIPT" query "riego agua tomate" --index "$IDX" --top 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"riego.md"* ]]
}

@test "query deterministic and ranked (best match first)" {
  python3 "$SCRIPT" index --dir "$IDXDIR/notes" --out "$IDX" >/dev/null
  run python3 "$SCRIPT" query "plagas cultivos vision" --index "$IDX" --top 3
  [ "$status" -eq 0 ]
  first="$(echo "$output" | head -1 | cut -f1)"
  [[ "$first" == *"plagas.md"* ]]
}

@test "query without index returns error" {
  run python3 "$SCRIPT" query "x" --index "$IDXDIR/missing.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"index not found"* ]]
}

@test "query with unreachable embeddings degrades to BM25 (still exits 0)" {
  python3 "$SCRIPT" index --dir "$IDXDIR/notes" --out "$IDX" >/dev/null
  run python3 "$SCRIPT" query "energia fotovoltaica red" --index "$IDX" --top 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"energia.md"* ]]
}