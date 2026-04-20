#!/usr/bin/env bash
# python-sbom.sh — SE-056 Slice 1 Python SBOM + requirements audit.
#
# Escanea scripts/*.py + projects/*/*.py detectando imports y reportando
# cobertura vs requirements.txt (o pyproject.toml). Opcionalmente scaffold
# .savia-venv/ aislado.
#
# Usage:
#   python-sbom.sh                      # audit + report
#   python-sbom.sh --json
#   python-sbom.sh --check              # exit 1 si imports no declarados
#   python-sbom.sh --venv               # imprime instrucciones venv
#
# Exit codes:
#   0 — SBOM ok
#   1 — imports sin declarar (en --check)
#   2 — usage error
#
# Ref: SE-056, audit-arquitectura-20260420.md §4.8
# Safety: read-only. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

JSON=0
CHECK=0
VENV_HINT=0

usage() {
  cat <<EOF
Usage:
  $0 [--json] [--check] [--venv]

Options:
  --json     JSON output
  --check    Exit 1 if imports lack declaration
  --venv     Print virtualenv setup instructions

Audita imports Python en scripts/*.py vs requirements.txt / pyproject.toml.
Ref: SE-056.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --check) CHECK=1; shift ;;
    --venv) VENV_HINT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

if [[ "$VENV_HINT" -eq 1 ]]; then
  cat <<VENV_EOF
Virtualenv setup (manual):

  python3 -m venv "\$HOME/.savia-venv"
  source "\$HOME/.savia-venv/bin/activate"
  pip install --upgrade pip
  pip install -r "$PROJECT_ROOT/requirements.txt"

Activation helper (add to .bashrc / .zshrc):
  alias savia-venv='source "\$HOME/.savia-venv/bin/activate"'

Verify isolation:
  which python3    # should point to .savia-venv/bin/python3
  pip list         # isolated packages

VENV_EOF
  exit 0
fi

PY_SCRIPTS=()
while IFS= read -r f; do
  [[ -f "$f" ]] && PY_SCRIPTS+=("$f")
done < <(find "$PROJECT_ROOT/scripts" -maxdepth 2 -name "*.py" -type f 2>/dev/null)

IMPORTS=()
STDLIB_MODULES="json os sys re subprocess pathlib typing collections datetime time hashlib io argparse tempfile shutil logging math random string itertools functools urllib email base64 getpass platform socket ssl http html xml csv sqlite3 ast inspect copy dataclasses enum abc warnings traceback threading multiprocessing queue asyncio contextlib weakref gc zipfile gzip pickle struct codecs locale unicodedata textwrap unittest doctest glob fnmatch signal secrets uuid importlib __future__ operator types array bisect heapq decimal fractions statistics difflib shlex configparser tomllib getopt cmd site atexit errno select signal mmap"

# Extract unique imports from all scripts
extract_imports() {
  local f="$1"
  # Match "import X" and "from X import Y" at LINE START only (avoids doc mentions)
  # Require proper module naming (lowercase snake_case or Cap_Init)
  grep -oE '^[[:space:]]*(import |from )[a-z_][a-zA-Z0-9_]*' "$f" 2>/dev/null | \
    sed -E 's/^[[:space:]]*(import |from )//' | \
    sort -u
}

is_stdlib() {
  local mod="$1"
  [[ " $STDLIB_MODULES " == *" $mod "* ]]
}

# Aggregate imports
declare -A ALL_IMPORTS
for f in "${PY_SCRIPTS[@]}"; do
  while IFS= read -r imp; do
    [[ -z "$imp" ]] && continue
    is_stdlib "$imp" && continue
    ALL_IMPORTS[$imp]=1
  done < <(extract_imports "$f")
done

# Read requirements.txt if present
DECLARED=()
REQS_FILE="$PROJECT_ROOT/requirements.txt"
if [[ -f "$REQS_FILE" ]]; then
  while IFS= read -r line; do
    # Extract package name (strip version specifiers)
    pkg=$(echo "$line" | sed -E 's/[=<>!~;].*//;s/\[.*\]//' | xargs)
    [[ -z "$pkg" || "$pkg" == "#"* ]] && continue
    DECLARED+=("$pkg")
  done < "$REQS_FILE"
fi

# Compare
MISSING=()
PRESENT=()
for imp in "${!ALL_IMPORTS[@]}"; do
  # Normalize import name to package name (simple: lowercase, replace _ with -)
  pkg_norm=$(echo "$imp" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
  found=0
  for d in "${DECLARED[@]}"; do
    d_norm=$(echo "$d" | tr '[:upper:]' '[:lower:]')
    if [[ "$pkg_norm" == "$d_norm" || "$imp" == "$d" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 1 ]]; then
    PRESENT+=("$imp")
  else
    MISSING+=("$imp")
  fi
done

EXIT_CODE=0
if [[ "$CHECK" -eq 1 && ${#MISSING[@]} -gt 0 ]]; then
  EXIT_CODE=1
fi

if [[ "$JSON" -eq 1 ]]; then
  missing_json=$(printf '"%s",' "${MISSING[@]}")
  missing_json="[${missing_json%,}]"
  present_json=$(printf '"%s",' "${PRESENT[@]}")
  present_json="[${present_json%,}]"
  cat <<JSON
{"verdict":"$([ $EXIT_CODE -eq 0 ] && echo PASS || echo FAIL)","python_scripts":${#PY_SCRIPTS[@]},"unique_imports":${#ALL_IMPORTS[@]},"declared":${#DECLARED[@]},"missing_count":${#MISSING[@]},"present_count":${#PRESENT[@]},"missing":$missing_json,"present":$present_json,"requirements_file_exists":$([ -f "$REQS_FILE" ] && echo true || echo false)}
JSON
else
  echo "=== SE-056 Python SBOM Audit ==="
  echo ""
  echo "Python scripts:      ${#PY_SCRIPTS[@]}"
  echo "Unique 3P imports:   ${#ALL_IMPORTS[@]}"
  echo "Declared in reqs:    ${#DECLARED[@]}"
  echo "Present/declared:    ${#PRESENT[@]}"
  echo "Missing from reqs:   ${#MISSING[@]}"
  echo ""
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Imports NOT in requirements.txt:"
    for m in "${MISSING[@]}"; do
      echo "  - $m"
    done
    echo ""
  fi
  echo "Venv setup: bash $0 --venv"
fi

exit $EXIT_CODE
