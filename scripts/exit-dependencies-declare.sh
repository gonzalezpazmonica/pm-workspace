#!/usr/bin/env bash
set -uo pipefail
# exit-dependencies-declare.sh — SE-272 S5: Declare exit package tool dependencies
#
# Lists honestly which sections of the exit package require tools to
# fully exploit vs which are standalone text readable with any editor.
#
# Each section is classified as:
#   autonomous    — plain text, readable without any tool
#   tool-dependent — needs specific tool (listed) to fully exploit
#
# Usage:
#   bash scripts/exit-dependencies-declare.sh --package DIR
#   bash scripts/exit-dependencies-declare.sh --package DIR --json
#   bash scripts/exit-dependencies-declare.sh --help

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 2; }
warn() { echo "WARN:  $*" >&2; }
ok() { echo "OK:    $*" >&2; }
info() { echo "INFO:  $*" >&2; }

usage() {
  sed -n '2,16p' "$0" | sed 's/^# //'
}

# ── Classification per section ─────────────────────────────────────────────────

declare_section() {
  local section="$1" pkg="$2"

  case "$section" in
    00-index.md)
      echo "autonomous"
      echo "Plain Markdown, readable with any text editor"
      ;;

    01-specs)
      if [[ -d "$pkg/$section" ]]; then
        local md_count
        md_count=$(find "$pkg/$section" -name "*.md" 2>/dev/null | wc -l)
        if [[ "$md_count" -gt 0 ]]; then
          echo "autonomous"
          echo "All specs in Markdown. Readable with any text editor or Markdown viewer."
        else
          echo "autonomous"
          echo "Empty section — no tools needed"
        fi
      fi
      ;;

    02-criterion)
      echo "autonomous"
      echo "Plain Markdown copy of CRITERIO.md. Readable with any text editor."
      ;;

    03-decisions)
      echo "autonomous"
      echo "Plain Markdown decision log. Readable with any text editor."
      ;;

    04-kg)
      local has_json=0 has_zst=0
      if [[ -f "$pkg/$section/kg-dump.json" ]]; then has_json=1; fi
      if [[ -f "$pkg/$section/graph.db.zst" ]]; then has_zst=1; fi

      if [[ "$has_json" -eq 1 ]] && [[ "$has_zst" -eq 1 ]]; then
        echo "dual"
        echo "kg-dump.json: standalone JSON readable with any tool."
        echo "graph.db.zst: needs zstd decompression + SQLite viewer to query relations."
        echo "Recommend: read kg-dump.json first; use graph.db.zst for deep queries."
      elif [[ "$has_json" -eq 1 ]]; then
        echo "autonomous"
        echo "JSON format, readable with any JSON viewer, text editor, or 'python3 -m json.tool'."
      elif [[ "$has_zst" -eq 1 ]]; then
        echo "tool-dependent"
        echo "zstd-compressed SQLite database."
        echo "Needs: zstd (or zstdcat) + sqlite3 CLI or DB browser."
        echo "Command: zstdcat graph.db.zst | sqlite3"
      else
        echo "autonomous"
        echo "Empty section — no tools needed"
      fi
      ;;

    05-qa)
      local has_bats=0 has_results=0
      if [[ -d "$pkg/$section/tests" ]]; then
        has_bats=$(find "$pkg/$section/tests" -name "*.bats" 2>/dev/null | wc -l)
      fi
      if [[ -f "$pkg/$section/test-results" ]] || [[ -d "$pkg/$section/test-results" ]]; then
        has_results=1
      fi

      if [[ "$has_bats" -gt 0 ]]; then
        echo "dual"
        echo "Test results: standalone Markdown/text."
        echo "BATS test files: need BATS runner (bats-core) to execute."
        echo "Recommend: read results first; run tests only if verifying."
      elif [[ "$has_results" -eq 1 ]]; then
        echo "autonomous"
        echo "Test results in text/Markdown. Readable with any editor."
      else
        echo "autonomous"
        echo "QA evidence in text format. Readable with any editor."
      fi
      ;;

    06-kpi)
      local has_jsonl=0
      if [[ -f "$pkg/$section/sprint-history.jsonl" ]]; then has_jsonl=1; fi

      if [[ "$has_jsonl" -eq 1 ]]; then
        echo "dual"
        echo "KPI-HISTORY.md: standalone Markdown."
        echo "sprint-history.jsonl: JSONL format, readable with any text editor."
        echo "For analysis: jq or python3 -m json.tool on individual lines."
        echo "Recommend: read .md summary first; use .jsonl for programmatic analysis."
      else
        echo "autonomous"
        echo "KPI history in Markdown. Readable with any text editor."
      fi
      ;;

    07-provenance)
      echo "autonomous"
      echo "Provenance map in Markdown. Readable with any text editor."
      ;;

    *)
      echo "autonomous"
      echo "Unknown section — assuming readable"
      ;;
  esac
}

# ── JSON output ────────────────────────────────────────────────────────────────

output_json() {
  local pkg="$1"
  local sections=("00-index.md" "01-specs" "02-criterion" "03-decisions" "04-kg" "05-qa" "06-kpi" "07-provenance")

  echo '{'
  echo '  "package": "'"$pkg"'",'
  echo '  "generated_at": "'"$(date -Iseconds)"'",'
  echo '  "sections": {'

  local first=1
  for sec in "${sections[@]}"; do
    local classification="" rationale=""
    local result
    result=$(declare_section "$sec" "$pkg" 2>/dev/null | head -1)
    classification="$result"
    rationale=$(declare_section "$sec" "$pkg" 2>/dev/null | tail -n +2)

    # Escape rationale for JSON
    rationale=$(echo "$rationale" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '""')

    if [[ $first -eq 1 ]]; then first=0; else echo ','; fi
    printf '    "%s": {"classification": "%s", "rationale": %s}' "$sec" "$classification" "$rationale"
  done

  echo ''
  echo '  },'
  echo '  "summary": {'
  local autonomous=0 tool_dependent=0 dual=0
  for sec in "${sections[@]}"; do
    local classification
    classification=$(declare_section "$sec" "$pkg" 2>/dev/null | head -1)
    case "$classification" in
      autonomous) autonomous=$((autonomous + 1)) ;;
      tool-dependent) tool_dependent=$((tool_dependent + 1)) ;;
      dual) dual=$((dual + 1)) ;;
    esac
  done
  printf '    "autonomous_sections": %d,\n' "$autonomous"
  printf '    "tool_dependent_sections": %d,\n' "$tool_dependent"
  printf '    "dual_sections": %d\n' "$dual"
  echo '  }'
  echo '}'
}

# ── Table output ───────────────────────────────────────────────────────────────

output_table() {
  local pkg="$1"
  local sections=("00-index.md" "01-specs" "02-criterion" "03-decisions" "04-kg" "05-qa" "06-kpi" "07-provenance")

  echo ""
  echo "=== EXIT PACKAGE TOOL DEPENDENCIES ==="
  echo "Package: $pkg"
  echo ""

  printf "%-22s  %-16s  %s\n" "SECTION" "CLASSIFICATION" "RATIONALE"
  printf '%0.s-' {1..100}
  echo ""

  for sec in "${sections[@]}"; do
    local classification rationale
    classification=$(declare_section "$sec" "$pkg" 2>/dev/null | head -1)
    rationale=$(declare_section "$sec" "$pkg" 2>/dev/null | tail -1)

    printf "%-22s  %-16s  %s\n" "$sec" "$classification" "$rationale"
  done

  printf '%0.s-' {1..100}
  echo ""

  local autonomous=0 tool_dependent=0 dual=0
  for sec in "${sections[@]}"; do
    local classification
    classification=$(declare_section "$sec" "$pkg" 2>/dev/null | head -1)
    case "$classification" in
      autonomous) autonomous=$((autonomous + 1)) ;;
      tool-dependent) tool_dependent=$((tool_dependent + 1)) ;;
      dual) dual=$((dual + 1)) ;;
    esac
  done

  echo ""
  echo "Summary: $autonomous autonomous, $dual dual, $tool_dependent tool-dependent"
  echo ""

  if [[ "$tool_dependent" -eq 0 ]] && [[ "$dual" -eq 0 ]]; then
    echo "This exit package is fully autonomous. A person with any text editor can"
    echo "reconstruct the engagement state without additional tools."
  elif [[ "$tool_dependent" -le 1 ]]; then
    echo "This exit package is mostly autonomous. One section requires a specific tool."
    echo "The tool is documented above. Reading the other sections does not require it."
  else
    echo "This exit package has tool dependencies. See the table above for which"
    echo "sections need which tools. All autonomous sections are readable with"
    echo "a standard text editor."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  local pkg="" mode="table"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --package) pkg="$2"; shift 2 ;;
      --json) mode="json"; shift ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$pkg" ]] && die "--package DIR required"
  [[ ! -d "$pkg" ]] && die "Package directory not found: $pkg"

  case "$mode" in
    json)  output_json "$pkg" ;;
    table) output_table "$pkg" ;;
  esac
}

main "$@"
