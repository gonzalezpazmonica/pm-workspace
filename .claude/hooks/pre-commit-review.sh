#!/bin/bash
# pre-commit-review.sh - Code review automatizado pre-commit (Guardian Angel)
set -euo pipefail

RULES_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/rules/domain/code-review-rules.md"
CACHE_DIR="${CLAUDE_PROJECT_DIR:-.}/output/.review-cache"
mkdir -p "$CACHE_DIR"

# Skip if no rules file
[[ ! -f "$RULES_FILE" ]] && exit 0

# Hash de reglas para invalidación
RULES_HASH=$(sha256sum "$RULES_FILE" | cut -d' ' -f1)
RULES_HASH_FILE="$CACHE_DIR/.rules-hash"

# Si las reglas cambiaron, invalidar toda la caché
if [[ -f "$RULES_HASH_FILE" ]]; then
    OLD_HASH=$(cat "$RULES_HASH_FILE")
    if [[ "$OLD_HASH" != "$RULES_HASH" ]]; then
        # FIX: Check directory exists before trying to delete files in it
        if [[ -d "$CACHE_DIR" ]]; then
            find "$CACHE_DIR" -name "*.passed" -type f -delete 2>/dev/null || true
        fi
        echo "⚠️ Reglas de review cambiadas — caché invalidada"
    fi
fi
echo "$RULES_HASH" > "$RULES_HASH_FILE"

# Obtener ficheros staged
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[[ -z "$STAGED" ]] && exit 0

FAILED=0
PASSED=0
CACHED=0
ISSUES=""

for FILE in $STAGED; do
    # Solo revisar código fuente
    case "$FILE" in
        *.cs|*.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.php|*.rb|*.java|*.kt|*.swift|*.dart|*.vb|*.cbl) ;;
        *) continue ;;
    esac

    # Hash combinado: contenido staged + reglas
    CONTENT_HASH=$(git show ":$FILE" 2>/dev/null | sha256sum | cut -d' ' -f1)
    COMBINED_HASH=$(echo -n "${CONTENT_HASH}${RULES_HASH}" | sha256sum | cut -d' ' -f1)
    CACHE_FILE="$CACHE_DIR/${COMBINED_HASH}.passed"

    # Cache hit → skip
    if [[ -f "$CACHE_FILE" ]]; then
        CACHED=$((CACHED + 1))
        PASSED=$((PASSED + 1))
        continue
    fi

    # Review básico basado en reglas
    CONTENT=$(git show ":$FILE" 2>/dev/null || true)
    FILE_ISSUES=""

    # Detectar console.log/print en producción (no en tests)
    if [[ "$FILE" != *test* && "$FILE" != *spec* ]]; then
        if echo "$CONTENT" | grep -nE '^\s*(console\.(log|debug)|print\(|System\.out\.print|fmt\.Print)' > /dev/null 2>&1; then
            FILE_ISSUES+="  ⚠️ Debug statements detectados en $FILE\n"
        fi
    fi

    # Detectar hardcoded secrets
    if echo "$CONTENT" | grep -nEi '(password|secret|api[_-]?key|token)\s*=\s*["\x27][^"\x27]{8,}' > /dev/null 2>&1; then
        FILE_ISSUES+="  🔴 Posible secret hardcodeado en $FILE\n"
    fi

    # Detectar TODO sin ticket
    if echo "$CONTENT" | grep -nE 'TODO[^(]|TODO$|FIXME[^(]|FIXME$|HACK[^(]|HACK$' > /dev/null 2>&1; then
        FILE_ISSUES+="  ⚠️ TODO/FIXME sin ticket en $FILE\n"
    fi

    # Detectar any en TypeScript
    if [[ "$FILE" == *.ts || "$FILE" == *.tsx ]]; then
        if echo "$CONTENT" | grep -nE ':\s*any\b|as\s+any\b|<any>' > /dev/null 2>&1; then
            FILE_ISSUES+="  ⚠️ Uso de 'any' en TypeScript: $FILE\n"
        fi
    fi

    if [[ -n "$FILE_ISSUES" ]]; then
        ISSUES+="$FILE_ISSUES"
        FAILED=$((FAILED + 1))
    else
        # Solo cachear PASSED
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $FILE" > "$CACHE_FILE"
        PASSED=$((PASSED + 1))
    fi
done

# Resultado
TOTAL=$((PASSED + FAILED))
if [[ $TOTAL -eq 0 ]]; then
    exit 0
fi

echo "📋 Code Review: $PASSED passed, $FAILED failed ($CACHED cached)"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "$ISSUES"
    echo "STATUS: FAILED — Revisar issues antes de finalizar"
else
    echo "STATUS: PASSED"
fi

# No bloquear (warning only) — el PM decide
exit 0
