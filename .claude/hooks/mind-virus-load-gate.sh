#!/usr/bin/env bash
set -uo pipefail
# SE-345 — Mind Virus Defense: load gate (SessionStart).
#
# Scans the memory surfaces that Savia auto-loads into context and blocks the
# load path for malicious files. Like the study's finding: a brief system
# warning dramatically cuts contagion; this gate makes it deterministic.
#
# Modes (SAVIA_MVD_MODE): warn (default — log only) | block (exit 2)
# Never auto-modifies (CRIT-001): read + report; quarantine is explicit.

[[ "${SAVIA_MVD:-on}" == "off" ]] && exit 0
MODE="${SAVIA_MVD_MODE:-warn}"
SCAN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/mind-virus/scan-memory.sh"

if [[ ! -f "$SCAN" ]]; then exit 0; fi

OUT=$(bash "$SCAN" --json 2>/dev/null) || true
MALICIOUS=$(printf '%s' "$OUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('malicious', 0))
except Exception:
    print(0)
" 2>/dev/null || echo 0)

if [[ "$MALICIOUS" -gt 0 ]]; then
  if [[ "$MODE" == "block" ]]; then
    echo "Mind Virus Defense [SE-345]: PAUSA DE CARGA — ${MALICIOUS} fichero(s) de memoria con carga 'malicious'. Usa scripts/mind-virus/quarantine.sh --quarantine <path> (explícito) y re-lanza." >&2
    exit 2
  fi
  echo "WARN [SE-345]: ${MALICIOUS} fichero(s) de memoria 'malicious' detectados al cargar. Revisa con scripts/mind-virus/scan-memory.sh" >&2
fi
exit 0