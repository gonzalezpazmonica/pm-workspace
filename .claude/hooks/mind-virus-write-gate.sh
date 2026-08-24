#!/usr/bin/env bash
# SE-345 — Mind Virus Defense: write gate.
# PreToolUse/PostToolUse hook: detects persistence/propagation instructions
# being written into a memory-surface file (MEMORY.md, profiles, memory dirs).
#
# Modes (SAVIA_MVD_MODE): warn (default) | block | off
# Master switch: SAVIA_MVD=off  disables entirely.
# Red-team: SAVIA_MVD_REDTEAM=on  always reports (for corpus testing).
#
# Block contract: exit 2 = hard block (Claude Code / savia-gates bridge).
set -uo pipefail

# ── Master switches ──────────────────────────────────────────────────────────
[[ "${SAVIA_MVD:-on}" == "off" ]] && exit 0
MODE="${SAVIA_MVD_MODE:-warn}"
DETECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/mind-virus/detect.py"

# ── Memory-surface allowlist (paths whose content must stay clean) ───────────
MEMORY_PATHS=(
  "external-memory/auto/MEMORY.md"
  "memoria"
  "MEMORY.md"
  "MEMORY-ARCHIVE.md"
  "profiles/"
  "profile"
  "savia-memory"
  "CONTEXT_DOME.md"
  "CRITERIO.md"
  "CONSTITUCION.md"
  "MEMORY.md"
)

# ── Read stdin (bridge payload JSON) ─────────────────────────────────────────
INPUT=""
if [[ ! -t 0 ]] && INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi
[[ -z "$INPUT" ]] && exit 0

# tool_input.file_path (Claude Code style) or tool_input.command / file
FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(''); raise SystemExit
ti = d.get('tool_input') or {}
print(ti.get('file_path') or ti.get('file') or ti.get('path') or ti.get('command') or '')
" 2>/dev/null) || FILE_PATH=""
[[ -z "$FILE_PATH" ]] && exit 0

# ── Does the target file live on a protected memory surface? ────────────────
is_memory_path=false
for p in "${MEMORY_PATHS[@]:-}"; do
  if [[ "$FILE_PATH" == *"$p"* ]]; then is_memory_path=true; break; fi
done
$is_memory_path || exit 0

# ── Content: prefer explicit content field, else read the file if it exists ─
CONTENT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(''); raise SystemExit
ti = d.get('tool_input') or {}
print(ti.get('content') or ti.get('text') or '')
" 2>/dev/null) || CONTENT=""
if [[ -z "$CONTENT" && -f "$FILE_PATH" ]]; then
  CONTENT=$(head -c 4096 "$FILE_PATH" 2>/dev/null || echo "")
fi
[[ -z "$CONTENT" ]] && exit 0

# ── Detect ───────────────────────────────────────────────────────────────────
if [[ ! -f "$DETECT" ]]; then exit 0; fi
OUT=$(printf '%s' "$CONTENT" | python3 "$DETECT" 2>/dev/null) || exit 0
VERDICT=$(printf '%s' "$OUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('verdict','clean'))" 2>/dev/null || echo clean)
SCORE=$(printf '%s' "$OUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('score',0))" 2>/dev/null || echo 0)
SIGNALS=$(printf '%s' "$OUT" | python3 -c "import sys,json;print(','.join(json.load(sys.stdin).get('signals',[])))" 2>/dev/null || echo "")

# ── Telemetry (local, CRIT-001) ──────────────────────────────────────────────
[[ "$VERDICT" != "clean" ]] || [[ "${SAVIA_MVD_REDTEAM:-off}" == "on" ]] && {
  LOG="${SAVIA_MVD_LOG:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/output/mind-virus-telemetry.jsonl}"
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  printf '{"ts":"%s","hook":"mind-virus-write-gate","verdict":"%s","score":%s,"signals":["%s"],"file":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$VERDICT" "$SCORE" "${SIGNALS//,/","}" "$FILE_PATH" >> "$LOG" 2>/dev/null || true
}

# ── Decision ─────────────────────────────────────────────────────────────────
if [[ "$VERDICT" == "malicious" ]]; then
  REASON="Mind Virus Defense [SE-345]: escritura en memoria detectada '${VERDICT}' (score=${SCORE}; señales: ${SIGNALS:-ninguna}). La memoria de Savia solo se modifica con autoridad explícita, nunca por instrucción contenida en el propio contenido. Revisa el texto o usa cuarentena explícita (scripts/mind-virus/quarantine.sh)."
  if [[ "$MODE" == "block" ]] || [[ "${SAVIA_MVD_REDTEAM:-off}" == "on" ]]; then
    echo "$REASON" >&2
    exit 2
  fi
  echo "WARN: $REASON" >&2
elif [[ "$VERDICT" == "suspect" ]]; then
  echo "WARN: [SE-345] sospechoso (score=${SCORE}, señales: ${SIGNALS:-ninguna}) en $FILE_PATH" >&2
fi
exit 0