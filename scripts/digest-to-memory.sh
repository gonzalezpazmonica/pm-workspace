#!/bin/bash
# digest-to-memory.sh — Bridge: digest agents -> memory-store + graph
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE="$SCRIPT_DIR/memory-store.sh"

TYPE="" TITLE="" PROJECT="" WHAT="" WHY="" WHERE="" LEARNED=""
CONCEPTS="" EXPIRES="" SOURCE_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        --what) WHAT="$2"; shift 2 ;;
        --why) WHY="$2"; shift 2 ;;
        --where) WHERE="$2"; shift 2 ;;
        --learned) LEARNED="$2"; shift 2 ;;
        --concepts) CONCEPTS="$2"; shift 2 ;;
        --expires) EXPIRES="$2"; shift 2 ;;
        --source) SOURCE_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$TYPE" || -z "$TITLE" ]] && { echo "Error: --type and --title required"; exit 1; }

MEMORY_TYPE="$TYPE"
case "$TYPE" in
    meeting|daily|standup|retro|review|planning)
        MEMORY_TYPE="discovery"
        [[ -z "$CONCEPTS" ]] && CONCEPTS="meeting,$TYPE"
        [[ -z "$EXPIRES" ]] && EXPIRES="90"
        ;;
    document|pdf|docx|xlsx|pptx)
        MEMORY_TYPE="discovery"
        [[ -z "$CONCEPTS" ]] && CONCEPTS="document,$TYPE"
        ;;
    visual|image|whiteboard)
        MEMORY_TYPE="discovery"
        [[ -z "$CONCEPTS" ]] && CONCEPTS="visual,$TYPE"
        ;;
esac

CMD=(bash "$STORE" save --type "$MEMORY_TYPE" --title "$TITLE")
[[ -n "$PROJECT" ]] && CMD+=(--project "$PROJECT")
[[ -n "$WHAT" ]] && CMD+=(--what "$WHAT")
[[ -n "$WHY" ]] && CMD+=(--why "$WHY")
[[ -n "$WHERE" ]] && CMD+=(--where "$WHERE")
[[ -n "$LEARNED" ]] && CMD+=(--learned "$LEARNED")
[[ -n "$CONCEPTS" ]] && CMD+=(--concepts "$CONCEPTS")
[[ -n "$EXPIRES" ]] && CMD+=(--expires "$EXPIRES")

if [[ -z "$WHAT" && -z "$WHY" && -z "$WHERE" && -z "$LEARNED" ]]; then
    if [[ -n "$SOURCE_FILE" ]]; then
        CMD+=(--content "Digested from: $SOURCE_FILE")
    else
        CMD+=(--content "Digest: $TITLE")
    fi
fi

"${CMD[@]}"
