#!/usr/bin/env bats
# Contract for the reproducible vector-memory installation.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  INSTALLER="$ROOT/scripts/install-memory-deps.sh"
}

@test "memory installer uses isolated Savia venv" {
  grep -q 'SAVIA_VENV_DIR:-$HOME/.savia/venv' "$INSTALLER"
  grep -q 'Scripts/python.exe' "$INSTALLER"
  ! grep -q -- '--break-system-packages' "$INSTALLER"
}

@test "memory installer forces CPU-only Torch on Linux" {
  grep -q 'download.pytorch.org/whl/cpu' "$INSTALLER"
  grep -q 'assert not torch.cuda.is_available()' "$INSTALLER"
}

@test "canonical requirements use wheel backend and pinned versions" {
  grep -q '^sentence-transformers==5.7.0$' "$ROOT/scripts/requirements-memory.txt"
  grep -q '^faiss-cpu==1.14.2$' "$ROOT/scripts/requirements-memory.txt"
  ! grep -q '^hnswlib' "$ROOT/scripts/requirements-memory.txt"
  grep -q '^-r scripts/requirements-memory.txt$' "$ROOT/requirements-vector.txt"
}

@test "runtime checks use the isolated memory Python" {
  grep -q 'SAVIA_MEMORY_PYTHON:-$HOME/.savia/venv/bin/python' "$ROOT/scripts/memory-store.sh"
  grep -q 'SAVIA_MEMORY_PYTHON:-$HOME/.savia/venv/bin/python' "$ROOT/.claude/hooks/session-init.sh"
  grep -q 'venv/Scripts/python.exe' "$ROOT/scripts/memory-store.sh"
  grep -q 'venv/Scripts/python.exe' "$ROOT/.claude/hooks/session-init.sh"
  ! grep -q '| python3 -c' "$ROOT/scripts/memory-search.sh"
}
