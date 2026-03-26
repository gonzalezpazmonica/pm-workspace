#!/usr/bin/env bash
# sovereignty-mask.sh — Wrapper for reversible data masking
# Usage:
#   sovereignty-mask.sh mask "text to mask" [--project my-project]
#   sovereignty-mask.sh unmask "masked text"
#   sovereignty-mask.sh show-map
#   sovereignty-mask.sh pipe-mask < input.txt > masked.txt
#   sovereignty-mask.sh pipe-unmask < masked-output.txt > real.txt
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASK_PY="$SCRIPT_DIR/sovereignty-mask.py"

# FIX B4: Parse --project from any position before determining action
PROJECT=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"
ACTION="${1:-help}"

# Find glossary
GLOSSARY=""
if [[ -n "$PROJECT" ]]; then
  GLOSSARY="$PROJECT_DIR/projects/$PROJECT/GLOSSARY-MASK.md"
  [[ ! -f "$GLOSSARY" ]] && GLOSSARY="$PROJECT_DIR/projects/$PROJECT/GLOSSARY.md"
fi
if [[ -z "$GLOSSARY" ]] || [[ ! -f "$GLOSSARY" ]]; then
  for g in "$PROJECT_DIR"/projects/*/GLOSSARY-MASK.md; do
    [[ -f "$g" ]] && GLOSSARY="$g" && break
  done
fi

# FIX B3: Use array for glossary args (handles spaces in paths)
GLOSSARY_ARGS=()
[[ -n "$GLOSSARY" ]] && [[ -f "$GLOSSARY" ]] && GLOSSARY_ARGS=(--glossary "$GLOSSARY")

case "$ACTION" in
  mask)
    shift
    TEXT="${*:-}"
    if [[ -z "$TEXT" ]] && [[ ! -t 0 ]]; then
      TEXT=$(cat)
    fi
    if [[ -z "$TEXT" ]]; then
      echo "ERROR: No text to mask" >&2; exit 1
    fi
    echo "$TEXT" | python3 "$MASK_PY" mask "${GLOSSARY_ARGS[@]}"
    ;;
  unmask)
    shift
    TEXT="${*:-}"
    if [[ -z "$TEXT" ]] && [[ ! -t 0 ]]; then
      TEXT=$(cat)
    fi
    if [[ -z "$TEXT" ]]; then
      echo "ERROR: No text to unmask" >&2; exit 1
    fi
    echo "$TEXT" | python3 "$MASK_PY" unmask
    ;;
  pipe-mask)
    python3 "$MASK_PY" mask "${GLOSSARY_ARGS[@]}"
    ;;
  pipe-unmask)
    python3 "$MASK_PY" unmask
    ;;
  show-map)
    python3 "$MASK_PY" show-map
    ;;
  *)
    echo "sovereignty-mask.sh — Reversible data masking for cloud LLM"
    echo ""
    echo "Commands:"
    echo "  mask TEXT        Mask sensitive entities with fictitious ones"
    echo "  unmask TEXT      Restore real entities from masked text"
    echo "  pipe-mask        Mask from stdin to stdout (for piping)"
    echo "  pipe-unmask      Unmask from stdin to stdout"
    echo "  show-map         Show current mask mapping table"
    echo ""
    echo "Options:"
    echo "  --project NAME   Use GLOSSARY.md from specific project"
    echo ""
    echo "The mask map is stored in output/data-sovereignty-validation/mask-map.json"
    echo "Every operation is logged to mask-audit.jsonl for auditability."
    ;;
esac
