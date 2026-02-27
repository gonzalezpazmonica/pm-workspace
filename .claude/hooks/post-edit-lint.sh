#!/bin/bash
# post-edit-lint.sh — Auto-lint tras edición de ficheros
# Usado por: settings.json (PostToolUse hook, async)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Determinar tipo de fichero y linter
EXT="${FILE_PATH##*.}"

case "$EXT" in
  cs)
    if command -v dotnet &> /dev/null; then
      dotnet format --include "$FILE_PATH" --verify-no-changes 2>&1 || true
    fi
    ;;
  py)
    if command -v ruff &> /dev/null; then
      ruff check "$FILE_PATH" 2>&1 || true
    fi
    ;;
  ts|tsx|js|jsx)
    if [ -f "$(dirname "$FILE_PATH")/node_modules/.bin/eslint" ]; then
      npx eslint "$FILE_PATH" --no-error-on-unmatched-pattern 2>&1 || true
    fi
    ;;
  go)
    if command -v gofmt &> /dev/null; then
      gofmt -l "$FILE_PATH" 2>&1 || true
    fi
    ;;
  rs)
    if command -v rustfmt &> /dev/null; then
      rustfmt --check "$FILE_PATH" 2>&1 || true
    fi
    ;;
  rb)
    if command -v rubocop &> /dev/null; then
      rubocop "$FILE_PATH" --format simple 2>&1 || true
    fi
    ;;
  php)
    if command -v php-cs-fixer &> /dev/null; then
      php-cs-fixer fix "$FILE_PATH" --dry-run --diff 2>&1 || true
    fi
    ;;
  tf)
    if command -v terraform &> /dev/null; then
      terraform fmt -check "$FILE_PATH" 2>&1 || true
    fi
    ;;
esac

exit 0
