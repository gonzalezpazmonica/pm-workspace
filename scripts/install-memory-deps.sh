#!/usr/bin/env bash
# Installs the optional vector-memory stack in Savia's isolated CPU-only venv.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${SAVIA_VENV_DIR:-$HOME/.savia/venv}"
SYSTEM_PYTHON="${SAVIA_SYSTEM_PYTHON:-python3}"

command -v "$SYSTEM_PYTHON" >/dev/null 2>&1 || {
  echo "ERROR: Python 3 not found: $SYSTEM_PYTHON" >&2
  exit 1
}

"$SYSTEM_PYTHON" -m venv "$VENV_DIR"
PYTHON="$VENV_DIR/bin/python"
[[ -x "$PYTHON" ]] || PYTHON="$VENV_DIR/Scripts/python.exe"
[[ -x "$PYTHON" ]] || {
  echo "ERROR: venv Python not found under $VENV_DIR" >&2
  exit 1
}
"$PYTHON" -m pip install --upgrade pip

# Linux PyPI Torch wheels can pull CUDA libraries. Use the official CPU index.
case "$(uname -s)" in
Linux|MINGW*|MSYS*|CYGWIN*)
  "$PYTHON" -m pip install --index-url https://download.pytorch.org/whl/cpu "torch==2.8.0"
  ;;
*)
  "$PYTHON" -m pip install "torch==2.8.0"
  ;;
esac

"$PYTHON" -m pip install -r "$ROOT/scripts/requirements-memory.txt"
"$PYTHON" -m pip check
"$PYTHON" -c "import faiss, sentence_transformers, torch; assert not torch.cuda.is_available()"

echo "Memory dependencies installed: $PYTHON"
