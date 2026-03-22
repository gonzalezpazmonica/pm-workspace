#!/bin/bash
# spellcheck-docs.sh — Orthographic review for multilingual docs
# Checks for common accent/spelling errors in docs by language.
# Usage: bash scripts/spellcheck-docs.sh [FILE...] (or all *.md if no args)
# Returns exit 1 if errors found, 0 if clean. Outputs fixes as sed commands.
set -uo pipefail

ERRORS=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Common accent errors per language (word without accent → correct form)
# Only words that ALWAYS need the accent (no ambiguous cases like que/qué)
declare -A ES_FIXES=(
    ["informacion"]="información" ["sesion"]="sesión" ["busqueda"]="búsqueda"
    ["observacion"]="observación" ["configuracion"]="configuración"
    ["automaticamente"]="automáticamente" ["semantica"]="semántica"
    ["instalacion"]="instalación" ["limitacion"]="limitación"
    ["informatica"]="informática" ["especifico"]="específico"
    ["historico"]="histórico" ["matematica"]="matemática"
    ["despues"]="después" ["tambien"]="también"
    ["tecnico"]="técnico" ["tecnica"]="técnica"
)

declare -A GL_FIXES=(
    ["informacion"]="información"
    ["debeda"]="débeda" ["tecnica"]="técnica" ["tecnico"]="técnico"
    ["codigo"]="código"
)

declare -A CA_FIXES=(
    ["implementacio"]="implementació" ["informacio"]="informació"
    ["regressio"]="regressió"
)

declare -A FR_FIXES=(
    ["telemetrie"]="télémétrie" ["premiere"]="première"
    ["interieur"]="intérieur" ["capacite"]="capacité"
    ["securite"]="sécurité" ["qualite"]="qualité"
)

detect_language() {
    local file="$1"
    case "$file" in
        *.gl.md|*galego*) echo "gl" ;;
        *.eu.md|*euskara*) echo "eu" ;;
        *.ca.md|*catala*) echo "ca" ;;
        *.fr.md|*francais*) echo "fr" ;;
        *.de.md|*deutsch*) echo "de" ;;
        *.pt.md|*portugues*) echo "pt" ;;
        *.it.md|*italiano*) echo "it" ;;
        *.en.md) echo "en" ;;
        *) echo "es" ;;
    esac
}

check_file() {
    local file="$1"
    local lang=$(detect_language "$file")
    local file_errors=0

    # Select fixes by language (only check languages with dictionaries)
    case "$lang" in
        es) local -n FIXES="ES_FIXES" ;;
        gl) local -n FIXES="GL_FIXES" ;;
        ca) local -n FIXES="CA_FIXES" ;;
        fr) local -n FIXES="FR_FIXES" ;;
        *) return 0 ;;  # No dictionary for en/de/it/pt/eu — skip
    esac

    for wrong in "${!FIXES[@]}"; do
        local correct="${FIXES[$wrong]}"
        local count=$(grep -owi "$wrong" "$file" 2>/dev/null | wc -l)
        if [[ $count -gt 0 ]]; then
            echo "  [$lang] $file: '$wrong' → '$correct' ($count occurrences)"
            file_errors=$((file_errors + count))
        fi
    done

    ERRORS=$((ERRORS + file_errors))
    return $file_errors
}

# Main
FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
    # Check all markdown docs (not rules/agents/commands — those are internal)
    mapfile -t FILES < <(find "$ROOT" -maxdepth 2 -name '*.md' \
        -not -path '*/.claude/*' -not -path '*/node_modules/*' \
        -not -path '*/projects/*' -not -path '*/.git/*' | sort)
fi

echo "Spellcheck: ${#FILES[@]} files"
echo ""

for f in "${FILES[@]}"; do
    check_file "$f" || true
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo "Found $ERRORS spelling issues."
    exit 1
else
    echo "No spelling issues found."
    exit 0
fi
