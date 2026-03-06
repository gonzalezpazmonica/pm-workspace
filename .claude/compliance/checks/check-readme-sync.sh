#!/usr/bin/env bash
# check-readme-sync.sh — Verifica que README.md ≤ 150 líneas y que README.en.md existe si README.md cambia
# Regla: readme conventions (pm-workspace)
set -euo pipefail

VIOLATIONS=0
FILES_CHANGED="$*"

# Check README size
for readme in README.md README.en.md; do
  [[ -f "$readme" ]] || continue
  lines=$(wc -l < "$readme")
  if (( lines > 150 )); then
    echo "❌ $readme: $lines líneas (máx 150)"
    ((VIOLATIONS++))
  fi
done

# Si README.md cambió, README.en.md debería cambiar también (bilingual sync)
if echo "$FILES_CHANGED" | grep -q "README.md" && ! echo "$FILES_CHANGED" | grep -q "README.en.md"; then
  echo "⚠️  README.md modificado pero README.en.md no — ¿falta sincronizar traducción?"
  # Solo warning, no bloquea
fi

if [[ $VIOLATIONS -eq 0 ]]; then
  echo "✅ READMEs dentro de límites"
  exit 0
else
  exit 1
fi
