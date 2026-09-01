#!/usr/bin/env bash
# org-registrar.sh — SE-365: CLI del grafo organizacional (wrapper).
# set -uo pipefail
#
# Envuelve org-registrar.py: validar entidades, indexar el grafo, consultar
# dependencias, preparar propuestas (escritura mediada).
#
# Uso:
#   org-registrar.sh validate --file entity.md
#   org-registrar.sh index --dir . --json
#   org-registrar.sh query --graph graph.json --what uses_resource --id X
#   org-registrar.sh propose --file entity.md
# Ref: SE-365 — Company as Code
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${PYTHON:-python3}"

exec "$PY" "$ROOT/scripts/org-registrar.py" "$@"
