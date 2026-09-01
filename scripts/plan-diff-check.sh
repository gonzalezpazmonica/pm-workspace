#!/usr/bin/env bash
# plan-diff-check.sh — SE-358: verifica que el diff respeta el plan.md.
# set -uo pipefail
#
# Comprueba que los archivos modificados en un diff están dentro de los
# listados en plan.md ("Files that change"). Un archivo fuera del plan es
# señal de scope creep silencioso o divergencia plan↔código.
#
# Uso:
#   plan-diff-check.sh --plan plan.md --files "a.py b.py" [--mode warn|block]
#   plan-diff-check.sh --plan plan.md --diff <(git diff --name-only)
#
# --mode warn (default): exit 0, imprime WARN de archivos divergentes
# --mode block: exit 2 si hay archivos fuera del plan
#
# Si plan.md no existe → fail-soft (WARN, no bloquea) salvo --strict.
# Ref: SE-358 — plan.md verificado (sync hook plan↔diff)
set -uo pipefail

PLAN=""
FILES_INPUT=""
MODE="warn"

while [[ $# -gt 0 ]]; do case "$1" in
  --plan) PLAN="$2"; shift 2 ;;
  --files) FILES_INPUT="$2"; shift 2 ;;
  --mode) MODE="$2"; shift 2 ;;
  *) shift ;;
esac; done

[[ -z "$PLAN" || -z "$FILES_INPUT" ]] && { echo "Uso: plan-diff-check.sh --plan plan.md --files 'a b'" >&2; exit 1; }
[[ -f "$PLAN" ]] || { echo "WARN: plan.md no existe ($PLAN) — fail-soft." >&2; exit 0; }

# Extraer archivos del plan (del validador)
PLANNED=$(python3 scripts/plan-validate.py --plan "$PLAN" --files 2>/dev/null || true)
if [[ -z "$PLANNED" ]]; then
  echo "WARN: no se pudieron extraer archivos de $PLAN (¿malformado?)" >&2
  [[ "${1:-}" == "--strict" ]] && exit 2 || exit 0
fi

# Normalizar: cada archivo cambiado debe estar en el plan (o ser docs/plan)
DIVERGENT=""
for f in $FILES_INPUT; do
  case "$f" in
    plan.md|docs/specs/*|CHANGELOG.d/*|.confidentiality-signature|.scm/*)
      continue ;;  # artefactos del proceso, no son divergencia
  esac
  if ! echo "$PLANNED" | grep -qxF "$f"; then
    DIVERGENT="$DIVERGENT $f"
  fi
done

if [[ -n "$DIVERGENT" ]]; then
  echo "WARN [SE-358]: archivos fuera del plan.md:$DIVERGENT" >&2
  [[ "$MODE" == "block" ]] && exit 2
fi

exit 0
