#!/usr/bin/env bash
set -uo pipefail

# heat-scheduler.sh — Lightweight heat-based parallelism for dev sessions
# SPEC-094: Phases = sequence, heats = parallel within phase.
# Inspired by Anvil (ppazosp/anvil)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: heat-scheduler.sh <command> [options]

Commands:
  plan <slices.json>       Generate wave plan from slices with heats
  validate <slices.json>   Check for file conflicts between parallel heats
  conflicts <slices.json>  List file conflicts (if any)

Slice JSON format:
  { "slices": [
    {"id": 1, "name": "...", "phase": 1, "heat": "core", "files": ["a.cs"]},
    ...
  ]}

Slices with same phase but different heats run in parallel.
Slices without "heat" field default to heat "serial-{id}" (no parallelism).
EOF
  exit 1
}

# ── Helpers ──────────────────────────────────────────────────────────────────

# Parse slices JSON and assign default heats
normalize_slices() {
  local input="$1"
  python3 -c "
import json, sys

data = json.load(open('$input'))
slices = data.get('slices', [])

for s in slices:
    if 'heat' not in s or not s['heat']:
        s['heat'] = f\"serial-{s['id']}\"
    if 'files' not in s:
        s['files'] = []
    if 'phase' not in s:
        s['phase'] = s['id']

json.dump({'slices': slices}, sys.stdout, indent=2)
"
}

# Detect file conflicts: two slices in same phase writing same file
detect_conflicts() {
  local input="$1"
  python3 -c "
import json, sys
from collections import defaultdict

data = json.load(sys.stdin)
slices = data.get('slices', [])

# Group by phase
phases = defaultdict(list)
for s in slices:
    phases[s['phase']].append(s)

conflicts = []
for phase_num, phase_slices in sorted(phases.items()):
    # Only check phases with multiple heats
    heats = defaultdict(list)
    for s in phase_slices:
        heats[s['heat']].append(s)

    if len(heats) <= 1:
        continue

    # Check file overlap between different heats
    file_to_heat = {}
    for heat_name, heat_slices in heats.items():
        for s in heat_slices:
            for f in s.get('files', []):
                if f in file_to_heat and file_to_heat[f] != heat_name:
                    conflicts.append({
                        'phase': phase_num,
                        'file': f,
                        'heat_a': file_to_heat[f],
                        'heat_b': heat_name
                    })
                file_to_heat[f] = heat_name

json.dump({'conflicts': conflicts, 'count': len(conflicts)}, sys.stdout, indent=2)
" < <(normalize_slices "$input")
}

# Generate wave plan
generate_plan() {
  local input="$1"
  python3 -c "
import json, sys
from collections import defaultdict

data = json.load(sys.stdin)
slices = data.get('slices', [])

# Group by phase
phases = defaultdict(list)
for s in slices:
    phases[s['phase']].append(s)

waves = []
max_parallel = 0

for phase_num in sorted(phases.keys()):
    phase_slices = phases[phase_num]
    # All slices in same phase form one wave
    tasks = []
    for s in phase_slices:
        tasks.append({'id': str(s['id']), 'heat': s['heat'], 'name': s.get('name', ''), 'files': s.get('files', [])})

    wave_num = len(waves) + 1
    waves.append({'wave': wave_num, 'phase': phase_num, 'tasks': tasks})
    if len(tasks) > max_parallel:
        max_parallel = len(tasks)

plan = {
    'waves': waves,
    'total_waves': len(waves),
    'total_slices': len(slices),
    'max_parallel': max_parallel,
    'serial_waves': sum(1 for w in waves if len(w['tasks']) == 1),
    'parallel_waves': sum(1 for w in waves if len(w['tasks']) > 1),
    'speedup_estimate': f\"{len(slices)}/{len(waves)} = {len(slices)/max(len(waves),1):.1f}x\"
}

json.dump(plan, sys.stdout, indent=2)
" < <(normalize_slices "$input")
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage
CMD="$1"; shift

case "$CMD" in
  plan)
    [[ $# -lt 1 ]] && { echo "Error: plan requires <slices.json>"; exit 1; }
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && { echo "Error: file not found: $INPUT"; exit 1; }

    # Check for conflicts first
    conflicts_json=$(detect_conflicts "$INPUT")
    conflict_count=$(echo "$conflicts_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['count'])")

    if [[ "$conflict_count" -gt 0 ]]; then
      echo "ERROR: File conflicts detected between parallel heats:" >&2
      echo "$conflicts_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data['conflicts']:
    print(f\"  Phase {c['phase']}: '{c['file']}' in heat '{c['heat_a']}' AND '{c['heat_b']}'\", file=sys.stderr)
" 2>&1 >&2
      exit 1
    fi

    generate_plan "$INPUT"
    ;;

  validate)
    [[ $# -lt 1 ]] && { echo "Error: validate requires <slices.json>"; exit 1; }
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && { echo "Error: file not found: $INPUT"; exit 1; }

    conflicts_json=$(detect_conflicts "$INPUT")
    conflict_count=$(echo "$conflicts_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['count'])")

    if [[ "$conflict_count" -eq 0 ]]; then
      echo "OK: No file conflicts between parallel heats"
      exit 0
    else
      echo "CONFLICT: $conflict_count file conflict(s) detected"
      echo "$conflicts_json"
      exit 1
    fi
    ;;

  conflicts)
    [[ $# -lt 1 ]] && { echo "Error: conflicts requires <slices.json>"; exit 1; }
    INPUT="$1"
    [[ ! -f "$INPUT" ]] && { echo "Error: file not found: $INPUT"; exit 1; }
    detect_conflicts "$INPUT"
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    usage
    ;;
esac
