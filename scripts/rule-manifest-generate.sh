#!/usr/bin/env bash
# rule-manifest-generate.sh — SE-338: genera rule-manifest.json desde el filesystem
# Ref: docs/specs/SE-338-rule-manifest-generator.spec.md
# Cierra la deuda SE-057: el manifest estaba stale desde 2026-04-16.
#
# Usage:
#   bash scripts/rule-manifest-generate.sh             # regenerar manifest
#   bash scripts/rule-manifest-generate.sh --check     # exit 1 si stale
#   bash scripts/rule-manifest-generate.sh --output FILE --domain-dir DIR
#
# Exit: 0 ok · 1 stale/FAIL · 2 usage
# PURE_BASH + python3 stdlib — sin LLM, sin red (CRIT-001, RN-04).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECK_MODE=false
OUTPUT="$ROOT/docs/rules/domain/rule-manifest.json"
DOMAIN_DIR="$ROOT/docs/rules/domain"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_MODE=true; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --domain-dir) DOMAIN_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "ERROR: opcion desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$DOMAIN_DIR" ]] || { echo "ERROR: domain dir no existe: $DOMAIN_DIR" >&2; exit 2; }

# ── Generar el manifest JSON determinista ──────────────────────────────────
GENERATED=$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

python3 - "$DOMAIN_DIR" "$GENERATED" > "$TMP" <<'PY'
import sys, os, re, json

domain_dir = sys.argv[1]
generated  = sys.argv[2]

rules = {}
for f in sorted(os.listdir(domain_dir)):
    if not f.endswith('.md'):
        continue
    if f in ('INDEX.md', 'rule-manifest.json'):
        continue
    path = os.path.join(domain_dir, f)
    try:
        txt = open(path, encoding='utf-8', errors='replace').read(400)
    except OSError:
        continue
    m = re.search(r'context_tier:\s*(L\d+)', txt)
    tier = "dormant"
    if m:
        tier = "tier1" if m.group(1) == "L1" else "tier2"
    rules[f] = {"tier": tier, "consumers": ""}

tier1 = sum(1 for v in rules.values() if v["tier"] == "tier1")
tier2 = sum(1 for v in rules.values() if v["tier"] == "tier2")
dormant = sum(1 for v in rules.values() if v["tier"] == "dormant")

out = {
    "generated": generated,
    "total": len(rules),
    "tier1_count": tier1,
    "tier2_count": tier2,
    "dormant_count": dormant,
    "rules": rules,
}
json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
print()
PY

# ── Comparar inventario (para --check) ─────────────────────────────────────
if [[ -f "$OUTPUT" ]]; then
  OLD_INVENTORY=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    for k in sorted(d.get('rules', {})):
        print(k)
except Exception:
    sys.exit(0)
" "$OUTPUT" 2>/dev/null)
  NEW_INVENTORY=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
for k in sorted(d.get('rules', {})):
    print(k)
" "$TMP" 2>/dev/null)
fi

if $CHECK_MODE; then
  if [[ ! -f "$OUTPUT" ]]; then
    echo "STALE: rule-manifest.json no existe — ejecuta sin --check para generarlo" >&2
    exit 1
  fi
  if [[ "$OLD_INVENTORY" != "$NEW_INVENTORY" ]]; then
    echo "STALE: rule-manifest.json desincronizado (reglas listadas difieren del filesystem)" >&2
    echo "  ejecuta: bash scripts/rule-manifest-generate.sh" >&2
    exit 1
  fi
  # Verificar que no haya entradas a ficheros inexistentes
  GHOSTS=$(python3 -c "
import json, sys, os
d = json.load(open(sys.argv[1]))
domain = sys.argv[2]
ghosts = [k for k in d.get('rules', {}) if not os.path.isfile(os.path.join(domain, k))]
print('\n'.join(ghosts))
" "$OUTPUT" "$DOMAIN_DIR" 2>/dev/null)
  if [[ -n "$GHOSTS" ]]; then
    echo "STALE: entradas fantasma en el manifest (ficheros inexistentes):" >&2
    echo "$GHOSTS" >&2
    exit 1
  fi
  echo "OK: rule-manifest.json sincronizado ($(python3 -c "import json;print(json.load(open('$OUTPUT'))['total'])" 2>/dev/null) reglas)"
  exit 0
fi

# ── Escribir el manifest regenerado ────────────────────────────────────────
cp "$TMP" "$OUTPUT"
TOTAL=$(python3 -c "import json;print(json.load(open('$OUTPUT'))['total'])")
T1=$(python3 -c "import json;print(json.load(open('$OUTPUT'))['tier1_count'])")
T2=$(python3 -c "import json;print(json.load(open('$OUTPUT'))['tier2_count'])")
D=$(python3 -c "import json;print(json.load(open('$OUTPUT'))['dormant_count'])")
echo "GENERATED: $OUTPUT"
echo "  total=$TOTAL tier1=$T1 tier2=$T2 dormant=$D"
echo "  generated_at=$GENERATED"
exit 0