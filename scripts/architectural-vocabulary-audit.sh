#!/usr/bin/env bash
# architectural-vocabulary-audit.sh — SE-082 Slice única.
#
# Static auditor over recent outputs of `architect` and `architecture-judge`.
# Detects use of prohibited terms (boundary / component / service / API)
# in architectural contexts where the canonical vocabulary
# (Module / Interface / Seam / Adapter / Depth / Locality) should apply.
#
# Modes:
#   architectural-vocabulary-audit.sh                # --report (default), warning-only, exit 0
#   architectural-vocabulary-audit.sh --gate         # exit 1 on any violation (Slice 2 hook-up)
#   architectural-vocabulary-audit.sh --json         # machine-readable
#   architectural-vocabulary-audit.sh --file PATH    # audit a single output file
#
# Default scan globs (override via env AUDIT_GLOBS):
#   output/architect-*.md
#   output/architecture-*.md
#   output/agent-runs/architect-*/*.md
#
# Output TSV (default --report) goes to stdout AND to:
#   output/architectural-vocabulary-audit-YYYYMMDD.tsv
#
# Columns: file | line | term | severity | excerpt
#
# Reference: SE-082 (`docs/propuestas/SE-082-architectural-vocabulary-discipline.md`)
# Pattern source: `mattpocock/skills/improve-codebase-architecture/LANGUAGE.md` (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
AUDIT_GLOBS="${AUDIT_GLOBS:-output/architect-*.md output/architecture-*.md output/agent-runs/architect-*/*.md}"

MODE="report"
JSON_OUT=0
SINGLE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --gate)   MODE="gate"; shift ;;
    --json)   JSON_OUT=1; shift ;;
    --file)   SINGLE_FILE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── Prohibited terms ────────────────────────────────────────────────────────
# Each term has a regex (case-insensitive, word-boundary) and a "preferred"
# replacement to suggest in the audit report.

declare -A PREFER
PREFER[boundary]="seam"
PREFER[component]="module"
PREFER[service]="module"
PREFER[api]="interface"

# ── Helpers ─────────────────────────────────────────────────────────────────

# Audit a single file. Emits TSV lines (no header).
# Skips fenced code blocks (triple-backtick) and inline code (single-backtick segments)
# because terms in code (e.g. "API_KEY", "BoundaryService class") are not vocabulary
# violations — they're identifier names from the codebase.
audit_one_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  python3 - "$file" <<'PYEOF'
import re, sys

path = sys.argv[1]
prohibited = {
    'boundary': 'seam',
    'component': 'module',
    'service':   'module',
    'api':       'interface',
}

# State machine to skip fenced code blocks + inline code spans.
in_fence = False
with open(path, 'r', encoding='utf-8', errors='replace') as fh:
    for lineno, raw in enumerate(fh, 1):
        line = raw.rstrip('\n')
        if line.lstrip().startswith('```'):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        # Strip inline `…` code spans
        cleaned = re.sub(r'`[^`]*`', '', line)
        for term, prefer in prohibited.items():
            # Whole-word, case-insensitive
            for m in re.finditer(rf'\b{re.escape(term)}\b', cleaned, re.IGNORECASE):
                excerpt = cleaned.strip()[:80]
                # severity: WARN (Slice 1 is warning-only)
                print(f"{path}\t{lineno}\t{term}\tWARN\t{excerpt}\t→ prefer: {prefer}")
PYEOF
}

# ── Discover targets ────────────────────────────────────────────────────────

declare -a FILES
if [ -n "$SINGLE_FILE" ]; then
  if [ -f "$SINGLE_FILE" ]; then
    FILES+=("$SINGLE_FILE")
  else
    echo "ERROR: --file path not found: $SINGLE_FILE" >&2; exit 2
  fi
else
  for glob in $AUDIT_GLOBS; do
    while IFS= read -r f; do
      [ -f "$f" ] && FILES+=("$f")
    done < <(compgen -G "$ROOT_DIR/$glob" 2>/dev/null || true)
  done
fi

# ── Run audit ───────────────────────────────────────────────────────────────

mkdir -p "$OUTPUT_DIR"
TODAY=$(date +%Y%m%d)
TSV_FILE="$OUTPUT_DIR/architectural-vocabulary-audit-$TODAY.tsv"

{
  printf "file\tline\tterm\tseverity\texcerpt\n"
  for f in ${FILES[@]+"${FILES[@]}"}; do
    audit_one_file "$f"
  done
} > "$TSV_FILE"

VIOLATIONS=$(awk -F'\t' 'NR>1 && $4=="WARN"' "$TSV_FILE" | wc -l | tr -d ' ')
FILE_COUNT=0
if [ -n "${FILES+x}" ]; then FILE_COUNT=${#FILES[@]}; fi

# ── Output ──────────────────────────────────────────────────────────────────

emit_summary_text() {
  echo "=== architectural-vocabulary-audit (SE-082 Slice única) ==="
  echo "  files audited: $FILE_COUNT"
  echo "  violations:    $VIOLATIONS (boundary/component/service/api in non-code prose)"
  echo "  TSV:           $TSV_FILE"
}

emit_summary_json() {
  printf '{"file_count":%s,"violations":%s,"tsv":"%s"}\n' \
    "$FILE_COUNT" "$VIOLATIONS" "$TSV_FILE"
}

case "$MODE" in
  report)
    if [ "$JSON_OUT" -eq 1 ]; then emit_summary_json; else emit_summary_text; cat "$TSV_FILE"; fi
    exit 0
    ;;
  gate)
    if [ "$JSON_OUT" -eq 1 ]; then emit_summary_json; else emit_summary_text; fi
    if [ "$VIOLATIONS" -gt 0 ]; then
      echo "GATE FAIL: $VIOLATIONS vocabulary violations — replace with canonical terms" >&2
      awk -F'\t' 'NR>1 && $4=="WARN"' "$TSV_FILE" | head -10 >&2
      exit 1
    fi
    exit 0
    ;;
esac
