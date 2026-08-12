#!/usr/bin/env bash
# vault-links.sh — SE-325: adyacencia inline + relaciones tipadas para SaviaVaults.
#
# Aplica aprendizajes de Cosmos DB Graph al modelo de datos de SaviaVaults:
#   extract   — extrae aristas del frontmatter (links:) + wikilinks [[x]],
#               emite JSONL {from, from_type, to, to_type, rel}.
#   validate  — valida aristas contra schema/relations.yaml (vocab por par).
#   traverse  — BFS con nivel explícito + telemetría vault.traverse.
#   query     — filtra entidades por propiedades de frontmatter indexadas.
#
# Uso:
#   vault-links.sh extract <vault-path> [--out <file>]
#   vault-links.sh validate <links.jsonl> [--strict]
#   vault-links.sh traverse <links.jsonl> <id> [--depth N]
#   vault-links.sh query <vault-path> --filter 'status:approved'
#
# Exit: 0 ok, 1 fallo (--strict en validate), 2 uso inválido. Ref: SE-325.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
RELATIONS_YAML="$REPO_ROOT/projects/savia-vaults/schema/relations.yaml"

ACTION="${1:-}"
[[ -z "$ACTION" ]] && { echo "usage: vault-links.sh {extract|validate|traverse|query} ..." >&2; exit 2; }
shift

# ── extract ─────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "extract" ]]; then
  VAULT="${1:-}"
  [[ -z "$VAULT" ]] && { echo "ERROR: extract requiere <vault-path>" >&2; exit 2; }
  [[ -d "$VAULT" ]] || { echo "ERROR: vault no existe: $VAULT" >&2; exit 2; }
  shift
  OUT=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out) OUT="$2"; shift 2 ;; *) shift ;;
    esac
  done
  python3 - "$VAULT" <<'PYEOF'
import json
import os
import re
import sys

vault = sys.argv[1]

ENTITY_RE = re.compile(r'entity:\s*\{type:\s*([a-z_]+),\s*id:\s*([a-z0-9_\-\.]+)\}')
LINKS_RE = re.compile(r'^\s*-\s+to:\s*([a-z0-9_\-\.]+)\s*\n\s*rel:\s*([a-z\-]+)', re.M)
WIKILINK_RE = re.compile(r'\[\[([a-z0-9_\-\.]+)\]\]')

edges = []

def emit(from_id, from_type, to, rel):
    to_type = "document"  # tipo destino no resuelto en extract; validate lo afina
    edges.append({
        "from": from_id, "from_type": from_type,
        "to": to, "to_type": to_type, "rel": rel,
    })

for root, dirs, files in os.walk(vault):
    dirs[:] = [d for d in dirs if not d.startswith(".git")]
    for fn in sorted(files):
        if not fn.endswith(".md"):
            continue
        path = os.path.join(root, fn)
        try:
            text = open(path, encoding="utf-8").read()
        except Exception:
            continue
        m = ENTITY_RE.search(text)
        if not m:
            continue
        from_type, from_id = m.group(1), m.group(2)
        # links: explícito en frontmatter (bloque YAML)
        fm = text.split("---", 2)
        if len(fm) >= 2:
            header = fm[1]
            for lm in LINKS_RE.finditer(header):
                emit(from_id, from_type, lm.group(1), lm.group(2))
        # wikilinks en el cuerpo → derived-from
        for wm in WIKILINK_RE.finditer(text):
            to = wm.group(1)
            if to != from_id:
                emit(from_id, from_type, to, "derived-from")

for e in edges:
    print(json.dumps(e, ensure_ascii=False))
PYEOF
  exit 0
fi

# ── validate ────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "validate" ]]; then
  LINKS="${1:-}"
  [[ -z "$LINKS" ]] && { echo "ERROR: validate requiere <links.jsonl>" >&2; exit 2; }
  [[ -f "$LINKS" ]] || { echo "ERROR: no existe: $LINKS" >&2; exit 2; }
  shift
  STRICT=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict) STRICT=1; shift ;;
      *) shift ;;
    esac
  done
  python3 - "$LINKS" "$RELATIONS_YAML" "$STRICT" <<'PYEOF'
import json
import re
import sys

links_path, relations_yaml, strict = sys.argv[1:4]
strict = strict == "1"

# parsear relations.yaml (subconjunto YAML mínimo: claves y listas)
rules = {}
generic = []
with open(relations_yaml, encoding="utf-8") as f:
    current_pair = None
    in_generic = False
    for line in f:
        line = line.rstrip()
        m = re.match(r'^  ([a-z_]+/[a-z_]+):\s*$', line)
        if m:
            current_pair = m.group(1)
            in_generic = False
            rules.setdefault(current_pair, [])
            continue
        if re.match(r'^generic:', line):
            current_pair = None
            in_generic = True
            continue
        mm = re.match(r'^  - ([a-z\-]+)\s*$', line)
        if mm and in_generic:
            generic.append(mm.group(1))
        elif mm and current_pair:
            rules[current_pair].append(mm.group(1))
        mm4 = re.match(r'^    - ([a-z\-]+)\s*$', line)
        if mm4 and in_generic:
            generic.append(mm4.group(1))
        elif mm4 and current_pair:
            rules[current_pair].append(mm4.group(1))

violations = []
total = 0
with open(links_path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        total += 1
        pair = f"{e['from_type']}/{e['to_type']}"
        allowed = rules.get(pair, generic)
        if e["rel"] not in allowed:
            violations.append({
                "from": e["from"], "to": e["to"], "rel": e["rel"],
                "pair": pair, "allowed": allowed,
            })

for v in violations:
    print(f"WARN: {v['from']} --{v['rel']}--> {v['to']} no permitido para {v['pair']} (permitidas: {v['allowed']})")
print(f"validate: {total} aristas, {len(violations)} fuera de vocabulario")
if violations and strict:
    print("STRICT: violaciones presentes -> FAIL")
    sys.exit(1)
sys.exit(0)
PYEOF
  exit $?
fi

# ── traverse (BFS con nivel explícito + telemetría) ─────────────────────────
if [[ "$ACTION" == "traverse" ]]; then
  LINKS="${1:-}"; ID="${2:-}"
  [[ -z "$LINKS" || -z "$ID" ]] && { echo "ERROR: traverse requiere <links.jsonl> <id>" >&2; exit 2; }
  shift 2
  DEPTH=2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --depth) DEPTH="$2"; shift 2 ;; *) shift ;;
    esac
  done
  python3 - "$LINKS" "$ID" "$DEPTH" <<'PYEOF'
import json
import sys

links_path, start, max_depth = sys.argv[1:4]
max_depth = int(max_depth)

adj = {}
with open(links_path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        adj.setdefault(e["from"], set()).add(e["to"])

# BFS con nivel explícito (aprendizaje Cosmos: breadth-first)
levels = {0: [start]}
visited = {start}
for depth in range(1, max_depth + 1):
    frontier = []
    for node in levels.get(depth - 1, []):
        for nxt in adj.get(node, []):
            if nxt not in visited:
                visited.add(nxt)
                frontier.append(nxt)
    if not frontier:
        break
    levels[depth] = frontier

# niveles ordenados con profundidad
result = []
for depth in sorted(levels):
    for node in levels[depth]:
        result.append({"level": depth, "node": node})

print(json.dumps({
    "start": start, "depth": max_depth,
    "nodes_visited": len(visited),
    "traversal": result,
}, ensure_ascii=False, indent=2))
PYEOF
  # Telemetría SE-313: evento vault.traverse (AC-S3.2) — nunca bloquea.
  VISITED=$(python3 - "$LINKS" "$ID" <<'PYEOF' 2>/dev/null
import json, sys
adj = {}
with open(sys.argv[1], encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try: e = json.loads(line)
        except Exception: continue
        adj.setdefault(e["from"], set()).add(e["to"])
seen={sys.argv[2]}
front=[sys.argv[2]]
while front:
    n=front.pop()
    for nxt in adj.get(n,[]):
        if nxt not in seen: seen.add(nxt); front.append(nxt)
print(len(seen))
PYEOF
)
  bash "$SCRIPT_DIR/otel-emit.sh" "vault.traverse" \
    start="$ID" depth="$DEPTH" nodes_visited="${VISITED:-0}" >/dev/null 2>&1 || true
  exit 0
fi

# ── query (filtro por frontmatter indexado) ─────────────────────────────────
if [[ "$ACTION" == "query" ]]; then
  VAULT="${1:-}"
  [[ -z "$VAULT" ]] && { echo "ERROR: query requiere <vault-path>" >&2; exit 2; }
  shift
  FILTER=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --filter) FILTER="$2"; shift 2 ;; *) shift ;;
    esac
  done
  [[ -z "$FILTER" ]] && { echo "ERROR: query requiere --filter 'key:value'" >&2; exit 2; }
  python3 - "$VAULT" "$FILTER" <<'PYEOF'
import json
import os
import re
import sys

vault, filter_expr = sys.argv[1:3]
key, _, value = filter_expr.partition(":")
key = key.strip().lower()
value = value.strip().lower()

ENTITY_RE = re.compile(r'entity:\s*\{type:\s*([a-z_]+),\s*id:\s*([a-z0-9_\-\.]+)\}')
PROP_RE = re.compile(r'^([a-z_]+):\s*(.+)$')

hits = []
for root, dirs, files in os.walk(vault):
    dirs[:] = [d for d in dirs if not d.startswith(".git")]
    for fn in sorted(files):
        if not fn.endswith(".md"):
            continue
        path = os.path.join(root, fn)
        try:
            text = open(path, encoding="utf-8").read()
        except Exception:
            continue
        m = ENTITY_RE.search(text)
        if not m:
            continue
        etype, eid = m.group(1), m.group(2)
        fm = text.split("---", 2)
        props = {"type": etype, "id": eid}
        if len(fm) >= 2:
            for line in fm[1].splitlines():
                pm = PROP_RE.match(line.strip())
                if pm:
                    props[pm.group(1).lower()] = pm.group(2).strip().strip('"').lower()
        if props.get(key) == value:
            hits.append({"id": eid, "type": etype, "file": path})

for h in hits:
    print(json.dumps(h, ensure_ascii=False))
print(f"query: {len(hits)} entidad(es) con {key}={value}")
PYEOF
  exit 0
fi

echo "ERROR: acción desconocida '$ACTION'" >&2
echo "usage: vault-links.sh {extract|validate|traverse|query} ..." >&2
exit 2
