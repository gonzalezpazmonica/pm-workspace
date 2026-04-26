#!/usr/bin/env bash
# opencode-parity-audit.sh — SE-077 Slice 2
#
# Compares Claude Code hook registration (.claude/settings.json) against the
# OpenCode plugin manifest emitted at plugin load time
# (~/.savia/opencode/plugins/savia-gates/manifest.json). Reports the gap as
# the count of unjustified missing bindings. CI uses --check vs the baseline
# (.ci-baseline/opencode-parity-gap.count) to prevent regressions.
#
# A hook can declare `# opencode-binding: NOT_EXPOSED — <reason>` (or a
# specific handler name) in its header to be excluded from the gap count.
#
# Usage:
#   bash scripts/opencode-parity-audit.sh           # default text gap report
#   bash scripts/opencode-parity-audit.sh --json
#   bash scripts/opencode-parity-audit.sh --baseline
#   bash scripts/opencode-parity-audit.sh --check
#
# Exit codes:
#   0 ok | 1 regression vs baseline | 2 baseline missing (--check only)
#   3 manifest missing (Slice 1 not deployed yet) | 4 usage error
#
# Reference: SE-077 Slice 2 (docs/propuestas/SE-077-opencode-replatform-v114.md)
# Reference: docs/rules/domain/opencode-savia-bridge.md
# Reference: docs/rules/domain/autonomous-safety.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SETTINGS="${SETTINGS:-${ROOT}/.claude/settings.json}"
HOOKS_DIR="${HOOKS_DIR:-${ROOT}/.claude/hooks}"
MANIFEST="${OPENCODE_MANIFEST:-${HOME}/.savia/opencode/plugins/savia-gates/manifest.json}"
BASELINE="${ROOT}/.ci-baseline/opencode-parity-gap.count"
MODE="text"

usage() {
  cat <<USG
Usage: opencode-parity-audit.sh [--json|--baseline|--check]

Modes:
  (default)   Print the gap report (human-readable)
  --json      Machine-readable JSON
  --baseline  Write the current gap count to ${BASELINE}
  --check     Exit 1 if current gap > baseline (CI guard)
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     MODE="json"; shift ;;
    --baseline) MODE="baseline"; shift ;;
    --check)    MODE="check"; shift ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 4 ;;
  esac
done

[[ -f "$SETTINGS" ]] || { echo "ERROR: settings missing: $SETTINGS" >&2; exit 4; }

# Step 1: enumerate Claude Code hook bindings → list of "<event>:<basename>"
cc_bindings=$(python3 - "$SETTINGS" <<'PY'
import json, sys, re, os
data = json.load(open(sys.argv[1]))
hooks = data.get("hooks", {}) or {}
out = []
for ev, entries in hooks.items():
    if not isinstance(entries, list):
        continue
    for entry in entries:
        for h in entry.get("hooks", []) or []:
            cmd = h.get("command", "")
            m = re.search(r'/([^/"\s]+\.sh)', cmd)
            if not m:
                continue
            base = m.group(1)
            out.append(f"{ev}:{base}")
print("\n".join(sorted(set(out))))
PY
)

# Step 2: enumerate OpenCode plugin manifest bindings
oc_bindings=""
if [[ -f "$MANIFEST" ]]; then
  oc_bindings=$(python3 - "$MANIFEST" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print(""); raise SystemExit
out = []
for b in data.get("bindings", []) or []:
    out.append(f"{b.get('event','')}:{b.get('claudeHook','')}")
print("\n".join(sorted(set(out))))
PY
)
fi

# Step 3: parse justification headers in the bash hooks (one line each)
justified() {
  local hookfile="$1"
  local header
  header=$(grep -E '^#\s*opencode-binding:' "$hookfile" 2>/dev/null | head -1 || true)
  [[ -n "$header" ]] && return 0
  return 1
}

matched=()
missing=()
justified_set=()
total=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  total=$((total + 1))
  if echo "$oc_bindings" | grep -Fxq "$line"; then
    matched+=("$line")
    continue
  fi
  base="${line#*:}"
  if [[ -f "${HOOKS_DIR}/${base}" ]] && justified "${HOOKS_DIR}/${base}"; then
    justified_set+=("$line")
    continue
  fi
  missing+=("$line")
done <<< "$cc_bindings"

gap=${#missing[@]}

case "$MODE" in
  text)
    echo "OpenCode parity audit"
    echo "  total Claude Code bindings : ${total}"
    echo "  matched in OpenCode plugin : ${#matched[@]}"
    echo "  justified (NOT_EXPOSED)    : ${#justified_set[@]}"
    echo "  unjustified gap            : ${gap}"
    if [[ "$gap" -gt 0 ]]; then
      echo "  missing:"
      for m in "${missing[@]}"; do echo "    - $m"; done
    fi
    ;;
  json)
    python3 - <<PY
import json
print(json.dumps({
  "total": ${total},
  "matched": ${#matched[@]},
  "justified": ${#justified_set[@]},
  "gap": ${gap},
  "missing": $(printf '%s\n' "${missing[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
}, indent=2))
PY
    ;;
  baseline)
    mkdir -p "$(dirname "$BASELINE")"
    echo "$gap" > "$BASELINE"
    echo "wrote ${BASELINE} = ${gap}"
    ;;
  check)
    [[ -f "$BASELINE" ]] || { echo "ERROR: baseline missing: ${BASELINE}" >&2; exit 2; }
    [[ -f "$MANIFEST" ]] || { echo "ERROR: manifest missing: ${MANIFEST} (Slice 1 not deployed)" >&2; exit 3; }
    base=$(cat "$BASELINE" | tr -d '[:space:]')
    if [[ "$gap" -gt "$base" ]]; then
      echo "FAIL: gap ${gap} > baseline ${base} (regression)"
      exit 1
    fi
    echo "PASS: gap ${gap} ≤ baseline ${base}"
    ;;
esac
