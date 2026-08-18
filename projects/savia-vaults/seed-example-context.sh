#!/usr/bin/env bash
# seed-example-context.sh — SE-327..331: puebla un vault local con las specs reales
# del workspace como entidades document + relaciones tipadas.
#
# Uso: bash seed-example-context.sh [ruta-del-vault]
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${1:-$SCRIPT_DIR/vaults/example-context}"
SPECS_DIR="$SCRIPT_DIR/specs"

mkdir -p "$VAULT/docs"

# Convierte el título de una spec en id kebab-case de entidad
spec_id() {
  local file="$1"
  basename "$file" .spec.md
}

# Extrae la línea de título markdown (# SE-xxx — Título)
spec_title() {
  local file="$1"
  grep -m1 '^# ' "$file" | sed 's/^# //'
}

# Extrae el bloque de relations del frontmatter spec (si existe)
spec_relations() {
  local file="$1"
  grep -A20 '^relations:' "$file" | sed -n '/^relations:/,/^[a-z]/p' | head -25
}

echo "Seed vault desde specs..."
for f in "$SPECS_DIR"/SE-*.spec.md; do
  [ -f "$f" ] || continue
  id=$(spec_id "$f")
  title=$(spec_title "$f")
  [ -z "$title" ] && title=$(basename "$f")
  # extrae el status del frontmatter (Estado/Status)
  status=$(grep -m1 -E '^\*\*Estado|^\*\*Status|^\*\*Estado|^\*\*Status' "$f" | sed -E 's/^(\*\*Estado|\*\*Status):?\s*//; s/\*\*.*//' | tr '[:upper:]' '[:lower:]' | xargs)
  [ -z "$status" ] && status="proposed"

  # wikilinks a otras specs mencionadas
  links=""
  for other in "$SPECS_DIR"/SE-*.spec.md; do
    [ -f "$other" ] || continue
    oid=$(spec_id "$other")
    if [ "$oid" != "$id" ] && grep -q "SE-${oid}" "$f"; then
      links="${links}[[${oid}]] "
    fi
  done

  cat > "$VAULT/docs/$id.md" <<EOF
---
entity:
  type: document
  id: $id
title: "$title"
doc_type: spec
status: $status
relations:
  - type: references
    target: savia-vaults
---

# $title

Spec de referencia. Relacionada con: $links

## Resumen

$(sed -n '/^## 1\./,/^## 2\./p' "$f" | head -12)
EOF
  echo "  + $id — $title"
done

# Entidad raíz del proyecto
cat > "$VAULT/docs/savia-vaults.md" <<'EOF'
---
entity:
  type: project
  id: savia-vaults
title: "SaviaVaults — Context Dome Server"
status: active
---

# SaviaVaults

Servidor de contexto local: MCP + A2A, git-backed, BM25, Ed25519, 6-layer
security. Contiene las specs [[SE-327]], [[SE-328]], [[SE-329]], [[SE-330]],
[[SE-331]] y el resto del catálogo SE del proyecto.
EOF
echo "  + savia-vaults (project)"

echo "Seed completo. Notas: $(ls "$VAULT/docs" | wc -l)"
