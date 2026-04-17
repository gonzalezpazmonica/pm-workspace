#!/bin/bash
# memory-sync-index.sh — Sync auto-memory markdown → JSONL vector index
# Source of truth: markdown files in Claude Code auto-memory
# JSONL store: derived index for semantic search (rebuildable)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STORE_FILE="${PROJECT_ROOT}/output/.memory-store.jsonl"
MEMORY_DIR="${1:-}"

if [[ -z "$MEMORY_DIR" ]]; then
    echo "Usage: memory-sync-index.sh <auto-memory-dir>"
    echo "  e.g.: memory-sync-index.sh ~/.claude/projects/<project>/memory/"
    exit 1
fi

[[ -d "$MEMORY_DIR" ]] || { echo "Error: $MEMORY_DIR not found"; exit 1; }

mkdir -p "$(dirname "$STORE_FILE")"

synced=0
skipped=0
errors=0

for md_file in "$MEMORY_DIR"/*.md; do
    [[ -f "$md_file" ]] || continue
    filename="$(basename "$md_file")"

    # Skip MEMORY.md index file
    [[ "$filename" == "MEMORY.md" ]] && continue

    # Parse frontmatter
    name=""; type=""; description=""
    in_frontmatter=false
    content_lines=()

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                in_frontmatter=false
                continue
            else
                in_frontmatter=true
                continue
            fi
        fi
        if $in_frontmatter; then
            case "$line" in
                name:*)       name="$(echo "$line" | sed 's/^name:[[:space:]]*//')" ;;
                type:*)       type="$(echo "$line" | sed 's/^type:[[:space:]]*//')" ;;
                description:*) description="$(echo "$line" | sed 's/^description:[[:space:]]*//')" ;;
            esac
        else
            content_lines+=("$line")
        fi
    done < "$md_file"

    # Skip files without frontmatter
    if [[ -z "$name" || -z "$type" ]]; then
        echo "  SKIP (no frontmatter): $filename"
        ((skipped++))
        continue
    fi

    # Build content string (join lines, trim)
    content="$(printf '%s\n' "${content_lines[@]}" | sed '/^$/d' | head -20 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

    # Derive topic_key from filename (without .md)
    topic_key="${filename%.md}"

    # Check if already in store (by topic_key)
    if grep -q "\"topic_key\":\"$topic_key\"" "$STORE_FILE" 2>/dev/null; then
        echo "  EXISTS: $topic_key"
        ((skipped++))
        continue
    fi

    # Save via memory-store.sh
    if bash "$SCRIPT_DIR/memory-store.sh" save \
        --type "$type" \
        --title "$name" \
        --content "$content" \
        --topic "$topic_key" 2>/dev/null; then
        echo "  SYNCED: $topic_key ($type)"
        ((synced++))
    else
        echo "  ERROR: $topic_key"
        ((errors++))
    fi
done

echo ""
echo "Sync complete: $synced synced, $skipped skipped, $errors errors"
echo "Store: $STORE_FILE ($(wc -l < "$STORE_FILE") entries)"

# Rebuild vector index if possible
if command -v python3 &>/dev/null; then
    python3 -c "import sentence_transformers; import faiss" 2>/dev/null && {
        echo "Rebuilding vector index..."
        python3 "$SCRIPT_DIR/memory-vector.py" rebuild --store "$STORE_FILE" 2>&1
    } || echo "Vector deps not available, skipping index rebuild"
fi
