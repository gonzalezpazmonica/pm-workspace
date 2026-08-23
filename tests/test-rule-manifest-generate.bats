#!/usr/bin/env bats
# BATS tests for scripts/rule-manifest-generate.sh (SE-338).
# Ref: SE-338 (generador determinista de rule-manifest), cierra SE-057.
# Spec: docs/specs/SE-338-rule-manifest-generator.spec.md
SCRIPT="scripts/rule-manifest-generate.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

# ── Structure / safety ──────────────────────────────────────────────────────

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-338" { run grep -c 'SE-338' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "no vendor names (RN-04, CRIT-001)" { run grep -ciE 'openai|anthropic|claude|azure|ollama|gemini' "$SCRIPT"; [[ "$output" -eq 0 ]]; }
@test "--help exits 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; }
@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }

# ── Determinismo / integridad ──────────────────────────────────────────────

@test "AC-1: genera manifest JSON válido con total == reglas en domain" {
  run bash "$SCRIPT" --output "$TMPDIR/manifest-test.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GENERATED"* ]]
  run python3 -c "import json; json.load(open('$TMPDIR/manifest-test.json'))"
  [ "$status" -eq 0 ]
  ACTUAL=$(find docs/rules/domain -maxdepth 1 -name '*.md' -not -name 'INDEX.md' -type f | wc -l | tr -d ' ')
  TOTAL=$(python3 -c "import json; print(json.load(open('$TMPDIR/manifest-test.json'))['total'])")
  [ "$TOTAL" -eq "$ACTUAL" ]
}

@test "AC-3/AC-5: --check exit 1 con manifest stale, exit 0 tras regenerar" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  # Corromper: manifest vacío → stale
  echo '{"generated":"x","total":0,"tier1_count":0,"tier2_count":0,"dormant_count":0,"rules":{}}' > "$TMPDIR/manifest-test.json"
  run bash "$SCRIPT" --check --output "$TMPDIR/manifest-test.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"STALE"* ]]
  # Regenerar → check pasa
  run bash "$SCRIPT" --output "$TMPDIR/manifest-test.json"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --check --output "$TMPDIR/manifest-test.json"
  [ "$status" -eq 0 ]
}

@test "AC-4: no referencia ficheros inexistentes (ghosts == 0)" {
  run bash "$SCRIPT" --output "$TMPDIR/manifest-test.json"
  [ "$status" -eq 0 ]
  GHOSTS=$(python3 -c "
import json, sys, os
d = json.load(open(sys.argv[1]))
ghosts = [k for k in d['rules'] if not os.path.isfile(os.path.join('docs/rules/domain', k))]
print(len(ghosts))
" "$TMPDIR/manifest-test.json")
  [ "$GHOSTS" -eq 0 ]
}

@test "AC-2: tras regenerar, rule-manifest-integrity reporta 0 missing_entries" {
  run bash "$SCRIPT" --output docs/rules/domain/rule-manifest.json
  [ "$status" -eq 0 ]
  run bash scripts/rule-manifest-integrity.sh --json
  [[ "$output" == *'"missing_entries":[]'* ]]
}

@test "RN-03: determinista — dos generaciones producen mismo inventario" {
  run bash "$SCRIPT" --output "$TMPDIR/m1.json"
  run bash "$SCRIPT" --output "$TMPDIR/m2.json"
  python3 -c "
import json
a = json.load(open('$TMPDIR/m1.json'))
b = json.load(open('$TMPDIR/m2.json'))
assert set(a['rules']) == set(b['rules']), 'inventarios difieren'
assert a['total'] == b['total']
"
}

@test "RN-01: no muta reglas (solo escribe el manifest)" {
  SHA_BEFORE=$(find docs/rules/domain -maxdepth 1 -name '*.md' -not -name 'INDEX.md' -exec sha256sum {} + | sort | sha256sum | cut -d' ' -f1)
  run bash "$SCRIPT" --output "$TMPDIR/manifest-test.json"
  [ "$status" -eq 0 ]
  SHA_AFTER=$(find docs/rules/domain -maxdepth 1 -name '*.md' -not -name 'INDEX.md' -exec sha256sum {} + | sort | sha256sum | cut -d' ' -f1)
  [ "$SHA_BEFORE" = "$SHA_AFTER" ]
}

@test "sin --output usa el path por defecto" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"docs/rules/domain/rule-manifest.json"* ]]
}