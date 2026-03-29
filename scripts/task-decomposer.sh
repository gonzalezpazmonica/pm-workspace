#!/usr/bin/env bash
set -uo pipefail

# task-decomposer.sh — Classify tasks as atomic/composite and decompose recursively
# SPEC-052 Phase 1: Classification and tree generation
# Max depth: 3 levels

MAX_DEPTH="${TASK_DECOMPOSER_MAX_DEPTH:-3}"

usage() {
  echo 'Usage: task-decomposer.sh [--max-depth N] [--json] "<task description>"'
  echo 'Classify a task as atomic or composite. If composite, decompose recursively.'
  echo 'Options: --max-depth N (default 3), --json, --help'
  exit 0
}

OUTPUT_JSON=false; TASK_DESC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-depth) MAX_DEPTH="$2"; [[ "$MAX_DEPTH" -gt 3 ]] && MAX_DEPTH=3; [[ "$MAX_DEPTH" -lt 1 ]] && MAX_DEPTH=1; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    --help) usage ;;
    -*) echo "ERROR: Unknown option $1" >&2; exit 1 ;;
    *) TASK_DESC="$1"; shift ;;
  esac
done
[[ -z "${TASK_DESC:-}" ]] && { echo "ERROR: Task description is required" >&2; exit 1; }

# --- Python classification engine ---
python3 -c "
import json
import re
import sys

task_desc = sys.argv[1]
max_depth = int(sys.argv[2])
output_json = sys.argv[3] == 'true'

def classify(description):
    \"\"\"Classify a task as atomic or composite using heuristics.\"\"\"
    desc_lower = description.lower().strip()

    parts = re.split(r'\b(?:and|y|with|con)\b', desc_lower)
    has_multi_parts = len(parts) >= 2 and all(len(p.strip()) >= 3 for p in parts)
    verbs = ['create','add','implement','build','setup','configure','deploy','migrate',
             'refactor','update','delete','remove','integrate','test','validate','send',
             'crear','agregar','implementar','construir','configurar','desplegar','migrar']
    found = [v for v in verbs if re.search(r'\b' + v + r'\b', desc_lower)]
    has_multi_verbs = len(found) >= 2
    enum_sigs = [', and ',', y ',' plus ',' also ',' as well as ',' along with ']
    has_enum = any(s in desc_lower for s in enum_sigs)
    return 'composite' if sum([has_multi_parts, has_multi_verbs, has_enum]) >= 1 else 'atomic'

def decompose(description, depth, max_d, prefix=''):
    \"\"\"Recursively decompose a composite task.\"\"\"
    classification = 'atomic' if depth >= max_d else classify(description)

    node = {
        'id': prefix or '0',
        'title': description.strip(),
        'classification': classification,
        'depth': depth,
        'children': [],
    }

    if classification == 'composite' and depth < max_d:
        # Split by connectors
        parts = re.split(r'\b(?:and|y|with|con)\b', description, flags=re.IGNORECASE)
        parts = [p.strip() for p in parts if len(p.strip()) >= 3]

        if len(parts) < 2:
            node['classification'] = 'atomic'
            return node

        # Cap at 7 subtasks (Miller's law)
        parts = parts[:7]

        for i, part in enumerate(parts):
            child_prefix = f'{prefix}{i+1}' if prefix else str(i+1)
            child = decompose(part, depth + 1, max_d, child_prefix + '.')
            child['id'] = child_prefix
            node['children'].append(child)

    return node

def render_tree(node, indent='', is_last=True):
    \"\"\"Render ASCII tree.\"\"\"
    connector = '└── ' if is_last else '├── '
    tag = '(atomic)' if node['classification'] == 'atomic' else '(composite)'
    line = f\"{indent}{connector}{node['id']}: {node['title']} {tag}\"
    lines = [line]

    children = node.get('children', [])
    for i, child in enumerate(children):
        extension = '    ' if is_last else '│   '
        child_lines = render_tree(child, indent + extension, i == len(children) - 1)
        lines.extend(child_lines)

    return lines

try:
    tree = decompose(task_desc, 0, max_depth)

    if output_json:
        print(json.dumps(tree, indent=2, ensure_ascii=False))
    else:
        # Root node
        tag = '(atomic)' if tree['classification'] == 'atomic' else '(composite)'
        print(f\"Task: {tree['title']} {tag}\")
        if tree.get('children'):
            for i, child in enumerate(tree['children']):
                lines = render_tree(child, '', i == len(tree['children']) - 1)
                for line in lines:
                    print(line)
except (ValueError, TypeError, IndexError) as e:
    print(f'ERROR: Classification failed: {e}', file=sys.stderr)
    sys.exit(1)
" "$TASK_DESC" "$MAX_DEPTH" "$OUTPUT_JSON"
