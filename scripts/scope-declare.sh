#!/usr/bin/env bash
# scope-declare.sh — SE-315 S1: extrae el alcance declarado de una spec.
#
# Extrae de una spec SE-XXX aprobada:
#   - declared_paths: paths de ficheros que la spec dice crear/modificar
#   - root_dirs:      directorios raíz que la spec toca
#   - spec_id:        id de la spec (SE-XXX / SPEC-XXX)
#
# Soporta dos formatos de declaración:
#   1. Tablas markdown "Fichero | Proposito" (savia-vaults y propuestas con
#      sección "Ficheros a Crear/Modificar").
#   2. Menciones inline de paths con extensión conocida
#      (scripts/foo.sh, tests/bar.bats, docs/x.md, ...).
#
# Uso:
#   scope-declare.sh <spec-file>            # JSON a stdout
#   scope-declare.sh <spec-file> --json     # idem (explícito)
#
# Exit: 0 = spec parseable, 2 = usage / fichero no existe.
#
# Ref: SE-315 (docs/propuestas/SE-315-scope-creep-gate.md)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 <spec-file> [--json]

Extrae el alcance declarado de una spec (paths + directorios raíz).

  <spec-file>   Ruta a la spec (docs/propuestas/*.md o projects/*/specs/*.md)
  --json        Emitir JSON a stdout (por defecto)

Exit: 0 = spec parseable, 2 = uso inválido o fichero inexistente.
Ref: SE-315 (scope-creep-gate).
EOF
}

[[ $# -eq 0 ]] && { usage; exit 2; }

SPEC_FILE="$1"
shift
[[ "$SPEC_FILE" == "-h" || "$SPEC_FILE" == "--help" ]] && { usage; exit 0; }

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: spec no existe: $SPEC_FILE" >&2
  exit 2
fi

python3 - "$SPEC_FILE" <<'PYEOF'
import json
import re
import sys

spec_file = sys.argv[1]
with open(spec_file, encoding="utf-8") as fh:
    content = fh.read()

# ── id de la spec ──────────────────────────────────────────────────────────
m = re.search(r"\b(SE|SPEC)-[0-9]+", content)
spec_id = m.group(0) if m else "unknown"

declared = set()
root_dirs = set()

EXT = r"(sh|py|md|bats|json|yaml|yml|ts|tsx|js|mjs|csv|xlsx)"

# ── Fase 1: tabla markdown de ficheros ─────────────────────────────────────
# `| scripts/foo.sh | Proposito |` o `| \`scripts/foo.sh\` | ... |`
for line in content.splitlines():
    if not line.lstrip().startswith("|"):
        continue
    cells = [c.strip().strip("`") for c in line.split("|")]
    if len(cells) < 2:
        continue
    f = cells[1]
    if re.fullmatch(r"[A-Za-z0-9_.\-\/]+", f) and re.search(r"\.(?:%s)$" % EXT, f):
        declared.add(f)

# ── Fase 2: menciones inline de paths ──────────────────────────────────────
prefixes = r"(\.claude/|\.opencode/|scripts/|tests/|config/|docs/|projects/)"
pat = re.compile(
    r"`?(" + prefixes + r"[A-Za-z0-9_./-]+\.(?:%s))`?" % EXT
)
for m in pat.finditer(content):
    p = m.group(1)
    # limpiar puntuación final
    p = re.sub(r"[.)\],;:]*$", "", p)
    p = re.sub(r"^\./", "", p)
    p = re.sub(r"/{2,}", "/", p)
    declared.add(p)

# ── root_dirs: directorio de cada path (dirname) + dir de nivel superior ──
for p in declared:
    d = p.rsplit("/", 1)
    if len(d) == 2:
        root_dirs.add(d[0])
        root_dirs.add(d[0].split("/", 1)[0])
    else:
        root_dirs.add(p)

out = {
    "spec_id": spec_id,
    "spec_file": spec_file.split("/")[-1],
    "declared_paths": sorted(declared),
    "root_dirs": sorted(root_dirs),
}
print(json.dumps(out, indent=2))
PYEOF
