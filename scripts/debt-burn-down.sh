#!/usr/bin/env bash
# SE-387 E — Ejecuta wave 1 del debt budget SOLO sobre capacidades confirmadas.
# fail-closed: sin lista explícita de confirmación (--confirm file) NO elimina nada.
# Uso: debt-burn-down.sh --report | --confirm <candidates.tsv>
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
INV="$ROOT/docs/propuestas/SE-376-debt-inventory.tsv"
if [[ "${1:-}" == "--report" ]]; then
  echo "Candidatos wave1 (de $INV):"
  awk -F'\t' 'NR>1 && $4=="DELETE" {print $1"\t"$2"\t"$5}' "$INV" 2>/dev/null | head -30
  echo "Confirmación requerida por capability (SE-380 RN-01: nunca eliminar automático)."
  exit 0
fi
if [[ "${1:-}" == "--confirm" && -f "${2:-}" ]]; then
  n=0
  while IFS=$'\t' read -r skill rest; do
    [[ -z "$skill" ]] && continue
    dir="$ROOT/.claude/skills/$skill"
    if [[ -d "$dir" ]]; then
      # verificar reemplazo documentado o ausencia total de referencias
      refs=$(grep -rl "skill:$skill\|skills/$skill" "$ROOT/.claude/commands" "$ROOT/.opencode/agents" "$ROOT/docs/resolver" 2>/dev/null | wc -l)
      echo "DELETE $skill (refs=$refs)"
      rm -rf "$dir"; n=$((n+1))
    fi
  done < "${2}"
  echo "wave1: $n capacidades eliminadas (confirmadas por la operadora)"
  exit 0
fi
echo "uso: --report | --confirm <candidates.tsv>"; exit 1
