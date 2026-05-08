#!/bin/bash
# spellcheck-docs.sh — Orthographic review using accent dictionaries
# Usage: bash scripts/spellcheck-docs.sh [--fix] [FILE...]
# Without --fix: report only. With --fix: auto-correct in place.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DICT_ES="$SCRIPT_DIR/accent-dictionary-es.txt"
FIX_MODE=false
ERRORS=0

# Parse flags
FILES=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix) FIX_MODE=true; shift ;;
        *) FILES+=("$1"); shift ;;
    esac
done

# Default: all markdown docs (not internal rules/agents/commands)
if [[ ${#FILES[@]} -eq 0 ]]; then
    mapfile -t FILES < <(find "$ROOT" -maxdepth 3 -name '*.md' \
        -not -path '*/.claude/rules/*' -not -path '*/.opencode/agents/*' \
        -not -path '*/.opencode/commands/*' -not -path '*/.opencode/skills/*' \
        -not -path '*/node_modules/*' -not -path '*/projects/*' \
        -not -path '*/.git/*' | sort)
fi

detect_language() {
    case "$1" in
        *.gl.md) echo "gl" ;; *.eu.md) echo "eu" ;; *.ca.md) echo "ca" ;;
        *.fr.md) echo "fr" ;; *.de.md) echo "de" ;; *.pt.md) echo "pt" ;;
        *.it.md) echo "it" ;; *.en.md) echo "en" ;; *) echo "es" ;;
    esac
}

check_file_with_dict() {
    local file="$1" dict="$2" lang="$3"
    local file_errors=0

    while IFS='|' read -r wrong correct; do
        [[ "$wrong" =~ ^#.*$ || -z "$wrong" ]] && continue
        wrong=$(echo "$wrong" | tr -d ' ')
        correct=$(echo "$correct" | tr -d ' ')

        # Case-insensitive fixed-string search (no regex injection via dictionary)
        local count=$(grep -owi -F "${wrong}" "$file" 2>/dev/null | wc -l)
        if [[ $count -gt 0 ]]; then
            echo "  [$lang] $file: '$wrong' -> '$correct' ($count)"
            file_errors=$((file_errors + count))

            if [[ "$FIX_MODE" == "true" ]]; then
                # Escape regex special chars for safe sed substitution
                local esc_w esc_c
                esc_w=$(printf '%s\n' "$wrong" | sed 's/[^^]/[&]/g; s/\^/\\^/g')
                esc_c=$(printf '%s\n' "$correct" | sed 's/[&/\\]/\\&/g')
                sed -i "s/${esc_w}/${esc_c}/gI" "$file"
            fi
        fi
    done < "$dict"

    ERRORS=$((ERRORS + file_errors))
}

echo "Spellcheck: ${#FILES[@]} files (fix=$FIX_MODE)"
echo ""

for f in "${FILES[@]}"; do
    lang=$(detect_language "$f")
    case "$lang" in
        es) [[ -f "$DICT_ES" ]] && check_file_with_dict "$f" "$DICT_ES" "es" ;;
        # Other languages: only check with ES dict for now
        # (gl/ca/fr share many accent patterns with ES)
        gl|ca) [[ -f "$DICT_ES" ]] && check_file_with_dict "$f" "$DICT_ES" "$lang" ;;
        *) ;; # Skip en/de/it/pt/eu — no dict yet
    esac
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
    if [[ "$FIX_MODE" == "true" ]]; then
        echo "Fixed $ERRORS accent issues."
    else
        echo "Found $ERRORS accent issues. Run with --fix to auto-correct."
    fi
    exit 1
else
    echo "No accent issues found."
    exit 0
fi
