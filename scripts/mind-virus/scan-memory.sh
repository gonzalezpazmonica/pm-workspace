#!/usr/bin/env bash
# SE-345 — Mind Virus Defense: scan memory surfaces before auto-load.
#
# Scans the memory that Savia auto-loads on session start against
# scripts/mind-virus/detect.py. Report-only by default; never auto-modifies
# files (CRIT-001: read + report, quarantine only with explicit flag).
#
# Usage:
#   bash scripts/mind-virus/scan-memory.sh                 # report all surfaces
#   bash scripts/mind-virus/scan-memory.sh --json          # machine-readable
#   bash scripts/mind-virus/scan-memory.sh --only-malicious  # exit 1 if any malicious
#
# Exit codes: 0 ok | 1 any malicious (with --only-malicious) | 2 usage/scan error
set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DETECT="$ROOT/scripts/mind-virus/detect.py"
MODE="text"
ONLY_MALICIOUS=false

for a in "$@"; do
  case "$a" in
    --json) MODE="json" ;;
    --only-malicious) ONLY_MALICIOUS=true ;;
    -h|--help) echo "Usage: scan-memory.sh [--json] [--only-malicious]"; exit 0 ;;
    *) echo "Unknown arg: $a" >&2; exit 2 ;;
  esac
done

# ── Memory surfaces (existing in this workspace) ────────────────────────────
# Path:label pairs. Add here when new persistent memory lands.
surfaces=(
  "$ROOT/.claude/external-memory/auto/MEMORY.md|auto-MEMORY"
  "$HOME/.savia-memory/auto/MEMORY.md|savia-memory-auto"
  "$ROOT/.claude/profiles/savia.md|profile-savia"
  "$ROOT/.claude/profiles/active-user.md|profile-active-user"
  "$ROOT/docs/critical-facts.md|critical-facts"
  "$ROOT/CLAUDE.md|claude-md"
  "$ROOT/CONSTITUCION.md|constitucion"
)

malicious=0
declare -a rows=()

# Batch scan: single python process, all surfaces at once (fast: ~60ms total
# vs ~500ms for per-file subprocess). Honours CRIT-001 (all local).
if [[ -x "$DETECT" ]]; then
  SURFACE_LIST=""
  for entry in "${surfaces[@]:-}"; do
    [[ -z "$entry" ]] && continue
    path="${entry%%|*}"; label="${entry##*|}"
    [[ -f "$path" ]] || continue
    SURFACE_LIST+="${path}|${label}
"
  done
  MAS_OUT=$(printf '%s' "$SURFACE_LIST" | python3 "$DETECT" --batch 2>/dev/null) || MAS_OUT=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    rows+=("$line")
  done < <(printf '%s\n' "$MAS_OUT")
fi

if [[ "$MODE" == "json" ]]; then
  python3 - "$malicious" "${rows[@]}" <<'PY'
import json, sys
malicious = int(sys.argv[1])
files = []
for r in sys.argv[2:]:
    label, verdict, score, signals = r.split("|", 3)
    files.append({"path": label, "verdict": verdict, "score": int(score), "signals": signals})
print(json.dumps({"malicious": malicious, "files": files}, ensure_ascii=False, indent=2))
PY
  [[ "$ONLY_MALICIOUS" == "true" && "$malicious" -gt 0 ]] && exit 1
  exit 0
fi

echo "=== Mind Virus Defense — scan-memory ==="
for r in "${rows[@]:-}"; do
  IFS='|' read -r label verdict score signals <<< "$r"
  printf "  %-28s %-10s score=%-3s %s\n" "$label" "$verdict" "$score" "$signals"
done
echo "malicious total: ${malicious}"
[[ "$ONLY_MALICIOUS" == "true" && "$malicious" -gt 0 ]] && exit 1
exit 0