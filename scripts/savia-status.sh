#!/usr/bin/env bash
# savia-status.sh — What is Savia doing right now?
# Usage: bash scripts/savia-status.sh

QUEUE="$HOME/.savia/work-queue.json"
LOG="$HOME/.savia/live.log"

echo "━━ Savia Status ━━"

# Show work queue if exists
if [[ -f "$QUEUE" ]]; then
  python3 -c "
import json, sys
try:
    d = json.load(open('$QUEUE'))
    ct = d.get('current_task', {})
    if ct:
        print(f'  Tarea: {ct.get(\"title\", \"—\")}')
        step = ct.get('step', '?')
        total = ct.get('total_steps', '?')
        print(f'  Paso:  {step}/{total} — {ct.get(\"current_file\", \"\")}')
        print(f'  ETA:   {ct.get(\"estimated_end\", \"?\")}')
    else:
        print('  Sin tarea activa en cola.')
    print()
    completed = d.get('completed', [])
    if completed:
        print('  Completado:')
        for c in completed[-5:]:
            print(f'    ✓ {c}')
        print()
    pending = d.get('pending', [])
    if pending:
        print('  Pendiente:')
        for p in pending:
            print(f'    ⏳ {p}')
        print()
except Exception as e:
    print(f'  Error leyendo cola: {e}')
" 2>/dev/null
else
  echo "  Sin cola de trabajo activa."
  echo
fi

# Show last 8 log lines
if [[ -f "$LOG" ]] && [[ -s "$LOG" ]]; then
  echo "━━ Ultimas acciones ━━"
  tail -8 "$LOG" | sed 's/^/  /'
else
  echo "  Sin actividad reciente."
fi

echo "━━━━━━━━━━━━━━━━━━━━"
