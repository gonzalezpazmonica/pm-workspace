#!/usr/bin/env bash
# check-command-frontmatter.sh — Verifica YAML frontmatter en comandos staged
# Regla: command-validation (convención pm-workspace)
# Solo verifica ficheros que están staged (no legacy)
set -euo pipefail

VIOLATIONS=0

# Obtener ficheros actualmente staged
STAGED=$(git diff --cached --name-only 2>/dev/null || echo "")

for file in "$@"; do
  [[ -f "$file" ]] || continue
  [[ "$file" =~ \.opencode/commands/.+\.md$ ]] || continue

  # Solo verificar si el fichero está staged (no pre-existente legacy)
  if ! echo "$STAGED" | grep -q "$file"; then
    continue
  fi

  # Debe empezar con ---
  first_line=$(head -1 "$file")
  if [[ "$first_line" != "---" ]]; then
    echo "⚠️  $file: comando sin frontmatter YAML"
    ((VIOLATIONS++))
  fi
done

if [[ $VIOLATIONS -eq 0 ]]; then
  echo "✅ Frontmatter de comandos OK"
  exit 0
else
  exit 1
fi
