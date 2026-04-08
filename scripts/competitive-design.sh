#!/usr/bin/env bash
set -uo pipefail

# competitive-design.sh — Parallel design generation with 3 philosophies
# SPEC-095: Minimal, Clean, Pragmatic — then evaluate and compare.
# Inspired by Anvil (ppazosp/anvil)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: competitive-design.sh <command> [options]

Commands:
  philosophies             List the 3 design philosophies with prompts
  generate <spec.md>       Generate 3 designs (outputs to stdout as JSON)
  evaluate <designs.json>  Score 3 designs on 4 criteria (0-10 each)
  compare <designs.json>   Generate markdown comparison table

Design philosophies:
  minimal    — Minimum changes, reuse existing code, avoid new abstractions
  clean      — Ideal clean architecture, no legacy compromises
  pragmatic  — Balance tech debt vs delivery speed, 80/20 approach
EOF
  exit 1
}

# ── Philosophy Prompts ───────────────────────────────────────────────────────

philosophy_prompt() {
  local philosophy="$1"
  case "$philosophy" in
    minimal)
      cat <<'PROMPT'
Design with MINIMUM CHANGES to the existing codebase. Priorities:
1. Reuse existing patterns, classes, and utilities — do not create new abstractions
2. Modify as few files as possible
3. Prefer adding to existing files over creating new ones
4. Accept some tech debt if it means fewer changes
5. Optimize for shortest implementation time
PROMPT
      ;;
    clean)
      cat <<'PROMPT'
Design with IDEAL CLEAN ARCHITECTURE. Priorities:
1. Strict separation of concerns (domain, application, infrastructure, API)
2. Dependency inversion — depend on abstractions, not implementations
3. Each class has single responsibility
4. Design for testability and maintainability
5. Ignore legacy constraints — design as if starting fresh
PROMPT
      ;;
    pragmatic)
      cat <<'PROMPT'
Design with PRAGMATIC BALANCE. Priorities:
1. Follow existing patterns where they work, improve where they don't
2. New abstractions only when they pay for themselves within 2 sprints
3. 80/20 rule: cover main cases well, handle edge cases simply
4. Moderate test coverage on critical paths, skip ceremonial tests
5. Balance delivery speed with 6-month maintainability
PROMPT
      ;;
    *)
      echo "Unknown philosophy: $philosophy" >&2
      return 1
      ;;
  esac
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_philosophies() {
  echo "=== Design Philosophies ==="
  echo ""
  for p in minimal clean pragmatic; do
    echo "--- $p ---"
    philosophy_prompt "$p"
    echo ""
  done
}

cmd_generate() {
  local spec_path="$1"
  [[ ! -f "$spec_path" ]] && { echo "Error: spec not found: $spec_path" >&2; exit 1; }

  local spec_content
  spec_content=$(cat "$spec_path")
  local spec_name
  spec_name=$(basename "$spec_path" .spec.md)

  python3 -c "
import json, sys

spec_name = '$spec_name'
spec_path = '$spec_path'

designs = {
    'spec': spec_name,
    'spec_path': spec_path,
    'philosophies': ['minimal', 'clean', 'pragmatic'],
    'designs': {
        'minimal': {
            'philosophy': 'minimal',
            'status': 'pending',
            'prompt_variant': 'minimum-changes',
            'content': None,
            'scores': None
        },
        'clean': {
            'philosophy': 'clean',
            'status': 'pending',
            'prompt_variant': 'ideal-architecture',
            'content': None,
            'scores': None
        },
        'pragmatic': {
            'philosophy': 'pragmatic',
            'status': 'pending',
            'prompt_variant': 'balanced-approach',
            'content': None,
            'scores': None
        }
    }
}

json.dump(designs, sys.stdout, indent=2)
"
}

cmd_evaluate() {
  local designs_file="$1"
  [[ ! -f "$designs_file" ]] && { echo "Error: file not found: $designs_file" >&2; exit 1; }

  python3 -c "
import json, sys

data = json.load(open('$designs_file'))
criteria = ['implementation_complexity', 'spec_alignment', 'maintainability_6m', 'regression_risk']

# Create evaluation template
evaluation = {
    'spec': data.get('spec', ''),
    'criteria': criteria,
    'criteria_descriptions': {
        'implementation_complexity': 'How easy to implement (10=trivial, 0=very complex)',
        'spec_alignment': 'How well it covers all spec requirements (10=100%, 0=0%)',
        'maintainability_6m': 'How maintainable in 6 months (10=excellent, 0=unmaintainable)',
        'regression_risk': 'Risk of breaking existing code (10=zero risk, 0=high risk)'
    },
    'evaluations': {}
}

for phil in data.get('philosophies', []):
    evaluation['evaluations'][phil] = {
        'philosophy': phil,
        'scores': {c: None for c in criteria},
        'total': None,
        'notes': ''
    }

json.dump(evaluation, sys.stdout, indent=2)
"
}

cmd_compare() {
  local designs_file="$1"
  [[ ! -f "$designs_file" ]] && { echo "Error: file not found: $designs_file" >&2; exit 1; }

  python3 -c "
import json, sys

data = json.load(open('$designs_file'))
evals = data.get('evaluations', {})
criteria = data.get('criteria', [])
philosophies = list(evals.keys())

# Header
print('# Competitive Design Comparison')
print()
print(f'Spec: {data.get(\"spec\", \"unknown\")}')
print()

# Table
header = '| Criterion | ' + ' | '.join(p.capitalize() for p in philosophies) + ' |'
separator = '|' + '|'.join(['---'] * (len(philosophies) + 1)) + '|'
print(header)
print(separator)

totals = {p: 0 for p in philosophies}
for c in criteria:
    label = c.replace('_', ' ').capitalize()
    row = f'| {label} |'
    for p in philosophies:
        score = evals[p]['scores'].get(c)
        score_str = str(score) if score is not None else '-'
        row += f' {score_str} |'
        if score is not None:
            totals[p] += score
    print(row)

# Total row
total_row = '| **Total** |'
for p in philosophies:
    total_row += f' **{totals[p]}** |'
print(total_row)

# Recommendation
best = max(totals, key=totals.get)
print()
print(f'## Recommendation: {best.capitalize()}')
print(f'Highest score: {totals[best]}/40')
"
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage
CMD="$1"; shift

case "$CMD" in
  philosophies)
    cmd_philosophies
    ;;
  generate)
    [[ $# -lt 1 ]] && { echo "Error: generate requires <spec.md>"; exit 1; }
    cmd_generate "$1"
    ;;
  evaluate)
    [[ $# -lt 1 ]] && { echo "Error: evaluate requires <designs.json>"; exit 1; }
    cmd_evaluate "$1"
    ;;
  compare)
    [[ $# -lt 1 ]] && { echo "Error: compare requires <designs.json>"; exit 1; }
    cmd_compare "$1"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    ;;
esac
