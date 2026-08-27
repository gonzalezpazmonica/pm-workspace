#!/usr/bin/env bats
# Ref: SE-338 — rule-manifest-generate.sh (AC-5: determinismo, no-mutación, stale)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  GEN="$ROOT_DIR/scripts/rule-manifest-generate.sh"
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPD" 2>/dev/null || true
}

@test "SE-338: genera manifest JSON válido con total == nº de reglas" {
  out="$TMPD/manifest.json"
  run bash "$GEN" --output "$out" --domain-dir "$ROOT_DIR/docs/rules/domain"
  [ "$status" -eq 0 ]
  python3 -c "
import json,sys,glob,os
m=json.load(open('$out'))
rules=[os.path.basename(f) for f in glob.glob('$ROOT_DIR/docs/rules/domain/*.md')
       if os.path.basename(f) not in ('INDEX.md','rule-manifest.json')]
assert m['total'] == len(rules), (m['total'], len(rules))
assert len(m['rules']) == len(rules)
for k,v in m['rules'].items():
    assert v['tier'] in ('tier1','tier2','dormant')
    assert 'consumers' in v
"
}

@test "SE-338: --check detecta stale (fichero nuevo en domain-dir)" {
  out="$TMPD/manifest.json"
  bash "$GEN" --output "$out" --domain-dir "$ROOT_DIR/docs/rules/domain" >/dev/null
  # añadir una regla fake → manifest ya no refleja el filesystem
  echo "---\ncontext_tier: L1\n---\n# fake\n" > "$TMPD/domain-extra.md"
  mkdir -p "$TMPD/dom"
  cp "$ROOT_DIR/docs/rules/domain/"*.md "$TMPD/dom/" 2>/dev/null
  cp "$TMPD/domain-extra.md" "$TMPD/dom/fake-rule.md"
  cp "$out" "$TMPD/dom/rule-manifest.json"
  run bash "$GEN" --check --output "$TMPD/dom/rule-manifest.json" --domain-dir "$TMPD/dom"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "stale"
}

@test "SE-338: no-mutación — generar no toca las reglas" {
  before=$(sha256sum "$ROOT_DIR/docs/rules/domain/radical-honesty.md" | cut -d' ' -f1)
  run bash "$GEN" --output "$TMPD/m.json"
  [ "$status" -eq 0 ]
  after=$(sha256sum "$ROOT_DIR/docs/rules/domain/radical-honesty.md" | cut -d' ' -f1)
  [ "$before" == "$after" ]
}

@test "SE-338: determinista — 2 generaciones → mismo inventario (ignorando generated)" {
  bash "$GEN" --output "$TMPD/a.json" >/dev/null
  sleep 1
  bash "$GEN" --output "$TMPD/b.json" >/dev/null
  python3 -c "
import json
a=json.load(open('$TMPD/a.json')); b=json.load(open('$TMPD/b.json'))
a.pop('generated'); b.pop('generated')
assert a == b
"
}
