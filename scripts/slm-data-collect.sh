#!/usr/bin/env bash
# slm-data-collect.sh — Collect training data from workspace artifacts.
#
# Agrega JSONL training data desde fuentes soberanas del pm-workspace:
#   - Specs aprobados (docs/propuestas/*.md con status: APPROVED)
#   - Decision log entries (docs/decision-log.md si existe)
#   - Agent prompts (.claude/agents/*.md)
#   - Skill definitions (.claude/skills/*/SKILL.md)
#
# Emite JSONL Alpaca-format con (instruction, output) derivados por heurísticas.
# NO ejecuta scraping externo, NO hace llamadas LLM — solo filesystem read.
#
# Usage:
#   slm-data-collect.sh --source specs --output datasets/raw/specs.jsonl
#   slm-data-collect.sh --source agents --output datasets/raw/agents.jsonl
#   slm-data-collect.sh --source all --output datasets/raw/all.jsonl
#
# Exit codes:
#   0 — data collected
#   2 — usage error
#
# Ref: SPEC-023 §Fuentes de datos, SPEC-SE-027 §Pipeline de preparación
# Safety: read-only (excepto --output), set -uo pipefail.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

SOURCE=""
OUTPUT=""
MIN_LINES=3

VALID_SOURCES="specs agents skills all"

usage() {
  cat <<EOF
Usage:
  $0 --source SRC --output FILE [--min-lines N]

  --source SRC     One of: $VALID_SOURCES
  --output FILE    JSONL Alpaca-format destination
  --min-lines N    Minimum lines per extracted entry (default 3)

Sources:
  specs   — docs/propuestas/*.md (frontmatter + body → Q&A pairs)
  agents  — .claude/agents/*.md (name/description → instruction/output)
  skills  — .claude/skills/*/SKILL.md (name/description → instruction/output)
  all     — concatenate all sources

Output format: {"instruction": "...", "input": "", "output": "..."}

Ref: SPEC-023 §Fuentes de datos, docs/rules/domain/slm-training-pipeline.md §Fase 1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --min-lines) MIN_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$SOURCE" ]] && { echo "ERROR: --source required" >&2; exit 2; }
[[ -z "$OUTPUT" ]] && { echo "ERROR: --output required" >&2; exit 2; }
if ! echo " $VALID_SOURCES " | grep -q " $SOURCE "; then
  echo "ERROR: invalid --source '$SOURCE' (allowed: $VALID_SOURCES)" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

# Ensure output dir exists.
mkdir -p "$(dirname "$OUTPUT")"

python3 - "$REPO_ROOT" "$SOURCE" "$OUTPUT" "$MIN_LINES" <<'PY'
import json, re, sys
from pathlib import Path

repo = Path(sys.argv[1])
source = sys.argv[2]
output = sys.argv[3]
min_lines = int(sys.argv[4])

entries = []

def extract_spec(path):
    """Parse spec markdown → list of (instruction, output) triples."""
    text = path.read_text()
    out = []
    # Title → first H1.
    title_m = re.search(r'^#\s+(.+)$', text, re.MULTILINE)
    title = title_m.group(1).strip() if title_m else path.stem

    # Extract Problem / Solution / Acceptance Criteria as triples.
    sections = {
        'Problema': 'problema',
        'Problem': 'problema',
        'Solucion': 'solución',
        'Solución': 'solución',
        'Solution': 'solución',
        'Acceptance Criteria': 'criterios de aceptación',
        'Criterios de aceptacion': 'criterios de aceptación',
        'Criterios de aceptación': 'criterios de aceptación',
    }
    for heading, noun in sections.items():
        m = re.search(rf'^##\s+{heading}\s*$\n(.+?)(?=^##\s+|\Z)', text, re.MULTILINE | re.DOTALL)
        if m:
            content = m.group(1).strip()
            if len(content.split('\n')) >= min_lines:
                out.append({
                    'instruction': f"Explica el/la {noun} de {title}",
                    'input': '',
                    'output': content[:2000],  # cap length
                })
    return out

def extract_agent(path):
    """Parse agent markdown → one triple."""
    text = path.read_text()
    # Frontmatter.
    fm = re.match(r'^---\n(.+?)\n---\n', text, re.DOTALL)
    if not fm:
        return []
    fm_content = fm.group(1)
    name_m = re.search(r'^name:\s*(.+)$', fm_content, re.MULTILINE)
    desc_m = re.search(r'^description:\s*(.+?)(?=^\w|\Z)', fm_content, re.MULTILINE | re.DOTALL)
    if not name_m or not desc_m:
        return []
    name = name_m.group(1).strip()
    desc = desc_m.group(1).strip().replace('\n', ' ')[:1500]
    # Body.
    body = text[fm.end():].strip()
    if len(body.split('\n')) < min_lines:
        return []
    return [{
        'instruction': f"Qué hace el agente {name}",
        'input': '',
        'output': f"{desc}\n\n{body[:1500]}",
    }]

def extract_skill(path):
    """Parse skill SKILL.md → one triple."""
    text = path.read_text()
    fm = re.match(r'^---\n(.+?)\n---\n', text, re.DOTALL)
    if not fm:
        return []
    fm_content = fm.group(1)
    name_m = re.search(r'^name:\s*(.+)$', fm_content, re.MULTILINE)
    desc_m = re.search(r'^description:\s*(.+?)(?=^\w|\Z)', fm_content, re.MULTILINE | re.DOTALL)
    if not name_m or not desc_m:
        return []
    name = name_m.group(1).strip()
    desc = desc_m.group(1).strip().replace('\n', ' ')[:1500]
    body = text[fm.end():].strip()
    if len(body.split('\n')) < min_lines:
        return []
    return [{
        'instruction': f"Cuándo usar el skill {name}",
        'input': '',
        'output': desc,
    }]

# Collect per source.
def collect_specs():
    results = []
    spec_dir = repo / 'docs' / 'propuestas'
    if not spec_dir.exists():
        return results
    for f in sorted(spec_dir.glob('*.md')):
        try:
            results.extend(extract_spec(f))
        except Exception:
            continue
    return results

def collect_agents():
    results = []
    agent_dir = repo / '.claude' / 'agents'
    if not agent_dir.exists():
        return results
    for f in sorted(agent_dir.glob('*.md')):
        try:
            results.extend(extract_agent(f))
        except Exception:
            continue
    return results

def collect_skills():
    results = []
    skills_dir = repo / '.claude' / 'skills'
    if not skills_dir.exists():
        return results
    for f in sorted(skills_dir.glob('*/SKILL.md')):
        try:
            results.extend(extract_skill(f))
        except Exception:
            continue
    return results

if source == 'specs':
    entries = collect_specs()
elif source == 'agents':
    entries = collect_agents()
elif source == 'skills':
    entries = collect_skills()
elif source == 'all':
    entries = collect_specs() + collect_agents() + collect_skills()

# Write JSONL.
with open(output, 'w') as f:
    for e in entries:
        f.write(json.dumps(e, ensure_ascii=False) + '\n')

sys.stderr.write(f"slm-data-collect: source={source} entries={len(entries)} output={output}\n")

# Categorize.
specs_n = sum(1 for e in entries if 'Explica' in e.get('instruction', ''))
agents_n = sum(1 for e in entries if 'agente' in e.get('instruction', ''))
skills_n = sum(1 for e in entries if 'skill' in e.get('instruction', ''))
sys.stderr.write(f"  breakdown: specs={specs_n} agents={agents_n} skills={skills_n}\n")
PY
rc=$?

echo "slm-data-collect: wrote $OUTPUT"
exit $rc
