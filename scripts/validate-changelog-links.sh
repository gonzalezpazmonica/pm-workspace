#!/bin/bash
# validate-changelog-links.sh — Verifica que cada ## [X.Y.Z] tiene su enlace [X.Y.Z]: URL
# Puede ejecutarse standalone o desde prompt-hook-commit.sh
set -euo pipefail
CHANGELOG="${1:-CHANGELOG.md}"
[[ ! -f "$CHANGELOG" ]] && { echo "No CHANGELOG found"; exit 0; }

ERRORS=0
# Extract all version headers: ## [X.Y.Z] — ...
while IFS= read -r header_version; do
    # Check if a matching link reference exists: [X.Y.Z]: https://...
    if ! grep -q "^\[${header_version}\]: https://" "$CHANGELOG"; then
        echo "❌ Missing link for [${header_version}] in CHANGELOG.md"
        ERRORS=$((ERRORS+1))
    fi
done < <(grep -oP '(?<=^## \[)[0-9]+\.[0-9]+\.[0-9]+(?=\])' "$CHANGELOG")

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "⚠️  $ERRORS version(s) sin enlace de referencia al final del CHANGELOG."
    echo "   Formato esperado: [X.Y.Z]: https://github.com/.../compare/vA.B.C...vX.Y.Z"
    exit 1
fi
echo "✅ Todos los enlaces de versión presentes en CHANGELOG.md"
exit 0
