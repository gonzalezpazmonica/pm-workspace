#!/usr/bin/env bash
# turn-sdlc-audit.sh — SE-336 S1: auditor Turn-SDLC
# Clasifica cada hook registrado en .claude/settings.json en las fases F1-F6
# del modelo Turn-SDLC (requisitos → diseño → ejecución → verificación →
# entrega → retrospectiva) y genera la matriz en output/turn-sdlc-matrix.md.
#
# La clasificación fase→hook vive versionada en este script (RN-07): todo
# cambio de clasificación es auditable en el diff.
#
# Usage: turn-sdlc-audit.sh [--json]
# Exit: 0 siempre (reporte) · 2 settings.json inválido o inexistente
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$ROOT/.claude/settings.json"
OUT_MD="$ROOT/output/turn-sdlc-matrix.md"

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && JSON_MODE=true

[[ ! -f "$SETTINGS" ]] && { echo "ERROR: $SETTINGS no existe" >&2; exit 2; }
python3 -c "import json,sys; json.load(open('$SETTINGS'))" 2>/dev/null \
  || { echo "ERROR: $SETTINGS no es JSON válido" >&2; exit 2; }

# ── Clasificación de eventos por fase (RN-07: versionada aquí) ──────────────
# F1 Requisitos · F2 Diseño · F3 Ejecución · F4 Verificación · F5 Entrega · F6 Retrospectiva
declare -A EVENT_PHASE=(
  [UserPromptSubmit]="F1"
  [PreToolUse]="F2|F3"        # según matcher: plan/dispatch = F2, resto = F3
  [PostToolUse]="F4"
  [PostToolUseFailure]="F4"
  [Stop]="F5|F6"              # según hook: gates de entrega = F5, captura = F6
  [SessionEnd]="F6"
  [SessionStart]="F0"         # arranque (pre-requisitos): se reporta como infra
  [PreCompact]="F0"
  [PostCompact]="F0"
  [CwdChanged]="F0"
  [FileChanged]="F0"
  [InstructionsLoaded]="F0"
  [ConfigChange]="F0"
  [SubagentStart]="F0"
  [SubagentStop]="F6"
  [TaskCreated]="F0"
  [TaskCompleted]="F0"
  [Notification]="F0"
)

# Clasificación fina por nombre de hook (para eventos multifacts F2|F3, F5|F6).
# Formato: "nombre:regex" — primer match gana. Sin match: F3 (PreToolUse) / F5 (Stop).
declare -a F2_HOOKS=(
  'plan-gate' 'context-preflight-check' 'spec156-token-budget-projection'
  'agent-dispatch-validate' 'recursion-guard' 'subagent-audience-filter'
)
declare -a F6_HOOKS=(
  'stop-memory-extract' 'session-end-memory' 'learning-capture-hook'
  'decision-trace-capture' 'memory-auto-capture' 'session-end-snapshot'
  'pbi-history-capture' 'memory-feedback-task' 'agent-trace-log'
)

phase_for_hook() {
  local event="$1" hook="$2"
  local base="${EVENT_PHASE[$event]:-F0}"
  if [[ "$base" == "F2|F3" ]]; then
    for h in "${F2_HOOKS[@]}"; do
      [[ "$hook" == *"$h"* ]] && { printf 'F2'; return; }
    done
    printf 'F3'; return
  fi
  if [[ "$base" == "F5|F6" ]]; then
    for h in "${F6_HOOKS[@]}"; do
      [[ "$hook" == *"$h"* ]] && { printf 'F6'; return; }
    done
    printf 'F5'; return
  fi
  printf '%s' "$base"
}

# Modo del hook: block si su path/script se conoce como bloqueante, warn si
# solo advierte, capture si solo registra. Heurística por nombre (auditada).
declare -a BLOCK_HOOKS=(
  'block-' 'validate-bash-global' 'tdd-gate' 'data-sovereignty-gate'
  'compliance-gate' 'prompt-hook-commit' 'vault-frontmatter-gate'
  'memory-verified-gate' 'plan-gate' 'pr-summary-gate' 'recursion-guard'
  'pre-commit-review' 'stop-quality-gate' 'scope-guard' 'delegation-guard'
  'contract-test-guard' 'android-adb-validate' 'judge-auto-router'
)
declare -a WARN_HOOKS=(
  'warn' 'nudge' 'remind' 'lint' 'cognitive-debt' 'bus-factor' 'focal'
)
hook_mode() {
  local hook="$1"
  for h in "${BLOCK_HOOKS[@]}"; do
    [[ "$hook" == *"$h"* ]] && { printf 'block'; return; }
  done
  for h in "${WARN_HOOKS[@]}"; do
    [[ "$hook" == *"$h"* ]] && { printf 'warn'; return; }
  done
  printf 'capture'
}

# ── Extracción de registros ─────────────────────────────────────────────────
mapfile -t ROWS < <(python3 - "$SETTINGS" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
hooks = d.get('hooks', {})
rows = []
for event, groups in sorted(hooks.items()):
    for g in groups:
        matcher = g.get('matcher', '-')
        for h in g.get('hooks', []):
            cmd = h.get('command', '')
            if not cmd:
                continue
            # nombre corto del script
            name = cmd.split('/')[-1].split(' ')[0].strip('"')
            rows.append((event, matcher, name, cmd))
for r in rows:
    print('\t'.join(r))
PYEOF
)

TOTAL=${#ROWS[@]}
UNCLASSIFIED=0
declare -A PHASE_COUNT
declare -a MD_ROWS JSON_ROWS

for line in "${ROWS[@]}"; do
  IFS=$'\t' read -r event matcher name cmd <<< "$line"
  phase=$(phase_for_hook "$event" "$name")
  mode=$(hook_mode "$name")
  [[ "$phase" == "F0" ]] && UNCLASSIFIED=$((UNCLASSIFIED+1))
  PHASE_COUNT[$phase]=$(( ${PHASE_COUNT[$phase]:-0} + 1 ))
  MD_ROWS+=("| $phase | $event | $matcher | \`$name\` | $mode |")
  JSON_ROWS+=("{\"phase\":\"$phase\",\"event\":\"$event\",\"matcher\":\"$matcher\",\"hook\":\"$name\",\"mode\":\"$mode\"}")
done

if $JSON_MODE; then
  printf '{"total":%d,"unclassified_f0":%d,"phases":{' "$TOTAL" "$UNCLASSIFIED"
  first=true
  for p in F1 F2 F3 F4 F5 F6 F0; do
    [[ -z "${PHASE_COUNT[$p]:-}" ]] && continue
    $first || printf ','
    first=false
    printf '"%s":%d' "$p" "${PHASE_COUNT[$p]}"
  done
  printf '},"hooks":['
  printf '%s\n' "${JSON_ROWS[@]}" | paste -sd, -
  printf ']}\n'
  exit 0
fi

# ── Markdown matrix ─────────────────────────────────────────────────────────
mkdir -p "$ROOT/output"
{
  echo "# Turn-SDLC Matrix — auto-generated $(date +%Y-%m-%d)"
  echo
  echo "> SE-336 S1 · Generado por \`scripts/turn-sdlc-audit.sh\` — no editar a mano."
  echo "> F1 Requisitos · F2 Diseño · F3 Ejecución · F4 Verificación · F5 Entrega · F6 Retrospectiva · F0 Infra/arranque"
  echo
  echo "## Resumen"
  echo
  echo "| Fase | Hooks |"
  echo "|---|---|"
  for p in F1 F2 F3 F4 F5 F6 F0; do
    [[ -z "${PHASE_COUNT[$p]:-}" ]] && PHASE_COUNT[$p]=0
    echo "| $p | ${PHASE_COUNT[$p]} |"
  done
  echo
  echo "Total registraciones: **$TOTAL** · Infra/arranque (F0): $UNCLASSIFIED"
  echo
  echo "## Matriz por hook"
  echo
  echo "| Fase | Evento | Matcher | Hook | Modo |"
  echo "|---|---|---|---|---|"
  printf '%s\n' "${MD_ROWS[@]}"
} > "$OUT_MD"

echo "Generated $OUT_MD ($TOTAL hooks, F0=$UNCLASSIFIED)"
echo "Phases: F1=${PHASE_COUNT[F1]:-0} F2=${PHASE_COUNT[F2]:-0} F3=${PHASE_COUNT[F3]:-0} F4=${PHASE_COUNT[F4]:-0} F5=${PHASE_COUNT[F5]:-0} F6=${PHASE_COUNT[F6]:-0}"
