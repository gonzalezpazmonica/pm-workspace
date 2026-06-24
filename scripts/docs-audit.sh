#!/usr/bin/env bash
# docs-audit.sh — Audita la estructura actual de docs/ y propone mejoras
#
# Usage:
#   bash scripts/docs-audit.sh [--json] [--output PATH]
#
# Outputs:
#   - Por defecto: informe legible en stdout
#   - --json: JSON a stdout
#   - --output PATH: escribe el informe en PATH (en lugar de stdout)
#   - --output auto: escribe en output/docs-audit-YYYYMMDD.md
#
# Detecta:
#   - Ficheros huérfanos (sin link desde README/CLAUDE.md/ROADMAP.md)
#   - Docs en raíz de docs/ que deberían estar en subcarpetas
#   - Subcarpetas con >20 ficheros (candidatas a sub-división)
#
# Exit codes:
#   0 — audit completado (puede haber issues)
#   1 — error de entorno (directorio no encontrado, etc.)

set -uo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || echo ".")"
DOCS_DIR="$REPO_ROOT/docs"
OUTPUT_FORMAT="text"
OUTPUT_PATH=""
DATE="$(date +%Y%m%d)"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       OUTPUT_FORMAT="json"; shift ;;
    --output)     OUTPUT_PATH="$2"; shift 2 ;;
    --output=*)   OUTPUT_PATH="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ ! -d "$DOCS_DIR" ]]; then
  echo "ERROR: docs/ directory not found at $DOCS_DIR" >&2
  exit 1
fi

# Resolve auto output path
if [[ "$OUTPUT_PATH" == "auto" ]]; then
  OUTDIR="$REPO_ROOT/output"
  mkdir -p "$OUTDIR"
  OUTPUT_PATH="$OUTDIR/docs-audit-${DATE}.md"
fi

# ── Data collection ───────────────────────────────────────────────────────────

# 1. Top-level categories (depth 1)
declare -a TOP_LEVEL_DIRS=()
while IFS= read -r d; do
  TOP_LEVEL_DIRS+=("$(basename "$d")")
done < <(find "$DOCS_DIR" -maxdepth 1 -mindepth 1 -type d | sort)

# 2. Files at root of docs/ (should be in subcategories)
declare -a ROOT_MARKDOWN_FILES=()
while IFS= read -r f; do
  ROOT_MARKDOWN_FILES+=("$(basename "$f")")
done < <(find "$DOCS_DIR" -maxdepth 1 -mindepth 1 -type f -name "*.md" | sort)

# 3. Subcarpetas con >20 ficheros markdown
declare -a LARGE_SUBDIRS=()
declare -A SUBDIR_COUNTS=()
while IFS= read -r d; do
  count=$(find "$d" -maxdepth 1 -name "*.md" | wc -l)
  dname="docs/$(basename "$d")"
  SUBDIR_COUNTS["$dname"]=$count
  if [[ $count -gt 20 ]]; then
    LARGE_SUBDIRS+=("$dname ($count files)")
  fi
done < <(find "$DOCS_DIR" -maxdepth 1 -mindepth 1 -type d | sort)

# Also count root
ROOT_COUNT=$(find "$DOCS_DIR" -maxdepth 1 -name "*.md" | wc -l)

# 4. Orphan detection — files not linked from anchor docs
declare -a ANCHOR_DOCS=(
  "$REPO_ROOT/README.md"
  "$REPO_ROOT/CLAUDE.md"
  "$DOCS_DIR/ROADMAP.md"
  "$DOCS_DIR/RESOLVER.md"
)

declare -a ORPHAN_FILES=()
declare -a LINKED_FILES=()

# Build set of all linked paths from anchor docs
declare -A LINKED_SET=()
for anchor in "${ANCHOR_DOCS[@]}"; do
  if [[ -f "$anchor" ]]; then
    # Extract markdown links: [text](path) and @path references
    while IFS= read -r link; do
      # Normalize: remove leading ./docs/ or docs/
      link="${link#./}"
      link="${link#docs/}"
      LINKED_SET["$link"]=1
    done < <(grep -oP '(?<=\()(docs/[^)]+\.md|[^)]+\.md)(?=\))' "$anchor" 2>/dev/null || true)
    # Also @-style imports
    while IFS= read -r link; do
      link="${link#@}"
      link="${link#docs/}"
      LINKED_SET["$link"]=1
    done < <(grep -oP '@docs/[^\s]+\.md' "$anchor" 2>/dev/null | sed 's/@docs\///' || true)
  fi
done

# Check root-level docs/ markdown files for orphan status
for f in "${ROOT_MARKDOWN_FILES[@]}"; do
  fname="$f"
  if [[ -z "${LINKED_SET[$fname]+x}" ]]; then
    ORPHAN_FILES+=("docs/$f")
  else
    LINKED_FILES+=("docs/$f")
  fi
done

ORPHAN_COUNT=${#ORPHAN_FILES[@]}
ROOT_FILE_COUNT=${#ROOT_MARKDOWN_FILES[@]}
LARGE_COUNT=${#LARGE_SUBDIRS[@]}

# 5. Candidates for moving to subcategories
# Root files that don't match "official root" names
OFFICIAL_ROOT=("ROADMAP.md" "RESOLVER.md" "ARCHITECTURE.md" "STRUCTURE.md" "INDEX.md" "AGENTS.md")
declare -a CANDIDATES_FOR_SUBDIR=()
for f in "${ROOT_MARKDOWN_FILES[@]}"; do
  is_official=0
  for official in "${OFFICIAL_ROOT[@]}"; do
    if [[ "$f" == "$official" ]]; then
      is_official=1
      break
    fi
  done
  if [[ $is_official -eq 0 ]]; then
    CANDIDATES_FOR_SUBDIR+=("$f")
  fi
done
CANDIDATE_COUNT=${#CANDIDATES_FOR_SUBDIR[@]}

# ── Output: JSON ──────────────────────────────────────────────────────────────
emit_json() {
  printf '{\n'
  printf '  "date": "%s",\n' "$DATE"
  printf '  "docs_root": "%s",\n' "$DOCS_DIR"
  printf '  "summary": {\n'
  printf '    "root_markdown_files": %d,\n' "$ROOT_FILE_COUNT"
  printf '    "orphan_files": %d,\n' "$ORPHAN_COUNT"
  printf '    "candidates_for_subdir": %d,\n' "$CANDIDATE_COUNT"
  printf '    "large_subdirs": %d\n' "$LARGE_COUNT"
  printf '  },\n'

  # top_level_dirs array
  printf '  "top_level_dirs": ['
  local first=1
  for d in "${TOP_LEVEL_DIRS[@]}"; do
    [[ $first -eq 1 ]] || printf ','
    printf '"%s"' "$d"
    first=0
  done
  printf '],\n'

  # orphans array
  printf '  "orphan_files": ['
  first=1
  for f in "${ORPHAN_FILES[@]}"; do
    [[ $first -eq 1 ]] || printf ','
    printf '"%s"' "$f"
    first=0
  done
  printf '],\n'

  # candidates for subdir
  printf '  "candidates_for_subdir": ['
  first=1
  for f in "${CANDIDATES_FOR_SUBDIR[@]}"; do
    [[ $first -eq 1 ]] || printf ','
    printf '"%s"' "docs/$f"
    first=0
  done
  printf '],\n'

  # large subdirs
  printf '  "large_subdirs": ['
  first=1
  for d in "${LARGE_SUBDIRS[@]}"; do
    [[ $first -eq 1 ]] || printf ','
    printf '"%s"' "$d"
    first=0
  done
  printf ']\n'
  printf '}\n'
}

# ── Output: Markdown report ───────────────────────────────────────────────────
emit_text() {
  cat <<HEADER
# docs/ Audit Report — ${DATE}

> Generated by \`scripts/docs-audit.sh\`
> Repo: ${REPO_ROOT}

## Summary

| Metric | Count |
|---|---|
| Root .md files | ${ROOT_FILE_COUNT} |
| Orphan root files (not linked from anchors) | ${ORPHAN_COUNT} |
| Root files → candidate for subcategory | ${CANDIDATE_COUNT} |
| Subdirectories with >20 files | ${LARGE_COUNT} |

## Top-Level Categories (docs/ depth 1)

HEADER

  for d in "${TOP_LEVEL_DIRS[@]}"; do
    count="${SUBDIR_COUNTS["docs/$d"]:-0}"
    echo "- \`docs/${d}/\` — ${count} markdown files"
  done

  printf '\n## Root of docs/ — All .md Files (%d)\n\n' "$ROOT_FILE_COUNT"
  echo 'These files live directly in docs/ root. The official root should contain only:'
  echo '`ROADMAP.md`, `RESOLVER.md`, `ARCHITECTURE.md`, `STRUCTURE.md`, `INDEX.md`'
  echo ""
  for f in "${ROOT_MARKDOWN_FILES[@]}"; do
    echo "- \`docs/${f}\`"
  done

  printf '\n## Orphan Files (%d)\n\n' "$ORPHAN_COUNT"
  echo 'Not linked from: README.md, CLAUDE.md, ROADMAP.md, RESOLVER.md'
  echo ""
  if [[ ${#ORPHAN_FILES[@]} -eq 0 ]]; then
    echo '_None detected._'
  else
    for f in "${ORPHAN_FILES[@]}"; do
      echo "- \`${f}\`"
    done
  fi

  printf '\n## Candidates for Subcategory (%d)\n\n' "$CANDIDATE_COUNT"
  echo 'Root files that do not match the official root set and should be moved to a subcategory:'
  echo ""
  if [[ ${#CANDIDATES_FOR_SUBDIR[@]} -eq 0 ]]; then
    echo '_None._'
  else
    for f in "${CANDIDATES_FOR_SUBDIR[@]}"; do
      echo "- \`docs/${f}\`"
    done
  fi

  printf '\n## Large Subdirectories (>20 files) — Subdivision Candidates\n\n'
  if [[ ${#LARGE_SUBDIRS[@]} -eq 0 ]]; then
    echo '_No subdirectory exceeds 20 markdown files._'
  else
    for d in "${LARGE_SUBDIRS[@]}"; do
      echo "- \`${d}\`"
    done
  fi

  printf '\n## Recommendations\n\n'
  if [[ $CANDIDATE_COUNT -gt 0 ]]; then
    printf '1. **Move %d root-level docs** to appropriate subcategories (see STRUCTURE.md taxonomy).\n' "$CANDIDATE_COUNT"
    printf '   Create redirect stubs in old locations for 60 days.\n'
  fi
  if [[ $LARGE_COUNT -gt 0 ]]; then
    printf '2. **Subdivide %d large directories**: each has >20 files and could benefit from sub-grouping.\n' "$LARGE_COUNT"
  fi
  if [[ $ORPHAN_COUNT -gt 0 ]]; then
    printf '3. **Link or archive %d orphan files**: add links from ROADMAP.md or INDEX.md, or move to docs/archive/.\n' "$ORPHAN_COUNT"
  fi
  printf '\n---\n_Run `bash scripts/docs-audit.sh --output auto` to save to output/_\n'
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  if [[ -n "$OUTPUT_PATH" ]]; then
    emit_json > "$OUTPUT_PATH"
    echo "JSON written to $OUTPUT_PATH" >&2
  else
    emit_json
  fi
else
  if [[ -n "$OUTPUT_PATH" ]]; then
    emit_text > "$OUTPUT_PATH"
    echo "Report written to $OUTPUT_PATH" >&2
  else
    emit_text
  fi
fi
