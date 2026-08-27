#!/usr/bin/env bats
# Ref: SE-264 — memory-store.sh consolidate (AC-05: ≥6 tests)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMPD="$(mktemp -d)"
  STORE="$TMPD/store.jsonl"
  PY="${SAVIA_MEMORY_PYTHON:-$HOME/.savia/venv/bin/python}"
  [[ -x "$PY" ]] || PY="$(command -v python3)"
}

teardown() {
  rm -rf "$TMPD" 2>/dev/null || true
}

_seed() {
  cat > "$STORE" <<'EOF'
{"ts":"2026-07-01T00:00:00Z","type":"episode","title":"many","topic_key":"episode/many","content":"test noise"}
{"ts":"2026-07-02T00:00:00Z","type":"bug","title":"test rebuild","topic_key":"bug/test-rebuild","content":"fixture"}
{"ts":"2026-07-03T00:00:00Z","type":"decision","title":"Use Redis","topic_key":"decision/use-redis","content":"decision humana"}
{"ts":"2026-01-01T00:00:00Z","type":"pattern","title":"p1","topic_key":"pattern/p1","content":"duplicado"}
{"ts":"2026-01-15T00:00:00Z","type":"pattern","title":"p1","topic_key":"pattern/p1","content":"duplicado (nuevo)"}
EOF
}

@test "SE-264: consolidate --dry-run no modifica el store" {
  _seed
  before=$(sha256sum "$STORE" | cut -d' ' -f1)
  "$PY" "$ROOT_DIR/scripts/memory-consolidate.py" --store "$STORE" --dry-run --stale-days 200 >/dev/null
  after=$(sha256sum "$STORE" | cut -d' ' -f1)
  [ "$before" == "$after" ]
}

@test "SE-264: dedup por topic_key (conserva la más reciente)" {
  _seed
  "$PY" "$ROOT_DIR/scripts/memory-consolidate.py" --store "$STORE" --stale-days 5000 >/dev/null
  n=$(grep -c 'pattern/p1' "$STORE")
  [ "$n" -eq 1 ]
}

@test "SE-264: strip de entradas test/bench (episode many, test rebuild)" {
  _seed
  "$PY" "$ROOT_DIR/scripts/memory-consolidate.py" --store "$STORE" --stale-days 5000 >/dev/null
  ! grep -q '"type":"episode"' "$STORE"
  ! grep -q '"title":"test rebuild"' "$STORE"
}

@test "SE-264: decisión humana protegida NO se strippea" {
  _seed
  "$PY" "$ROOT_DIR/scripts/memory-consolidate.py" --store "$STORE" --stale-days 5000 >/dev/null
  grep -q '"type": *"decision"' "$STORE"
}

@test "SE-264: stale flag + reporte" {
  _seed
  "$PY" "$ROOT_DIR/scripts/memory-consolidate.py" --store "$STORE" --stale-days 30 > "$TMPD/report.json"
  python3 -c "
import json
r=json.load(open('$TMPD/report.json'))
assert r['scanned']==5
assert r['deduped']==1
assert r['stripped']>=2
assert r['kept'] >= 1
"
}

@test "SE-264: CRIT-001 — sin llamadas de red" {
  ! grep -rniE 'http://|https://|requests\.|urllib|boto3|openai|anthropic' "$ROOT_DIR/scripts/memory-consolidate.py"
}
