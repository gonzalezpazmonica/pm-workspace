#!/usr/bin/env bash
# hooks-blocking-audit.sh — Verifica que los guards de seguridad llevan `blocking: true`
# (D23-5 / D-T2) según config/hooks-blocking-policy.txt.
#
# Uso: bash scripts/hooks-blocking-audit.sh [--settings FICHERO] [--policy FICHERO]
# Salida: 0 = cumple · 1 = violaciones (una línea VIOLATION por cada una) · 2 = error de uso,
#         de lectura o de política.
# Ref: docs/rules/domain/hooks-blocking-guards.md
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$ROOT/.claude/settings.json"
POLICY="$ROOT/config/hooks-blocking-policy.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings) SETTINGS="${2:-}"; shift 2 ;;
    --policy) POLICY="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

for f in "$SETTINGS" "$POLICY"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: no existe $f"
    exit 2
  fi
done

python3 - "$SETTINGS" "$POLICY" <<'PY'
import json, re, sys

settings_path, policy_path = sys.argv[1], sys.argv[2]
try:
    settings = json.load(open(settings_path, encoding="utf-8"))
except (OSError, ValueError) as e:
    print(f"ERROR: settings ilegible ({settings_path}): {e}")
    sys.exit(2)

policy = {}
for n, raw in enumerate(open(policy_path, encoding="utf-8"), 1):
    line = raw.split("#", 1)[0].strip()
    if not line:
        continue
    parts = line.split(None, 2)
    verb, name = parts[0], parts[1] if len(parts) > 1 else ""
    reason = parts[2].strip() if len(parts) > 2 else ""
    if verb not in ("blocking", "excluded", "reviewed") or not name:
        print(f"ERROR: política línea {n}: se esperaba '<blocking|excluded|reviewed> <hook> [motivo]': {raw.rstrip()}")
        sys.exit(2)
    if verb != "blocking" and len(reason) < 10:
        print(f"ERROR: política línea {n}: '{verb} {name}' necesita un motivo de al menos 10 caracteres")
        sys.exit(2)
    policy[name] = verb

# Identidad de un hook: nombre del script (.sh/.py) del comando; el campo name es solo etiqueta.
occurrences = {}
for event, groups in (settings.get("hooks") or {}).items():
    for g in groups if isinstance(groups, list) else []:
        for h in g.get("hooks") or []:
            m = re.search(r"([A-Za-z0-9_.-]+)\.(?:sh|py)\b", h.get("command") or "")
            if not m:
                continue
            occurrences.setdefault(m.group(1), []).append((event, g.get("matcher"), h.get("blocking")))

violations = []
for name, verb in sorted(policy.items()):
    occ = occurrences.get(name, [])
    if verb == "blocking" and not occ:
        violations.append(f"{name}: declarado blocking pero no registrado en settings.json")
    for event, matcher, b in occ:
        where = f"{event}[{matcher}]"
        if verb == "blocking" and b is not True:
            violations.append(f"{name} en {where}: sin blocking true (valor {json.dumps(b)})")
        if verb != "blocking" and b is True:
            violations.append(f"{name} en {where}: blocking true pero la política lo marca {verb}")

for name, occ in sorted(occurrences.items()):
    if name in policy:
        continue
    if any(b is True for _, _, b in occ):
        violations.append(f"{name}: blocking true no declarado en la política")
    if name.startswith("block-"):
        violations.append(f"{name}: guard block-* sin clasificar en la política (blocking, excluded o reviewed)")

for v in violations:
    print(f"VIOLATION {v}")
if violations:
    print(f"FAIL: {len(violations)} violación(es) de la política de hooks blocking")
    sys.exit(1)
print(f"OK: {sum(1 for v in policy.values() if v == 'blocking')} guards blocking conformes")
PY
