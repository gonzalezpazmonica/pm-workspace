#!/usr/bin/env bash
# gitagent-export.sh — SPEC-099 Slice 1 gitagent adapter.
#
# Exporta un agente de pm-workspace (`.opencode/agents/{name}.md`) al formato
# open-gitagent/gitagent v0.1.0 para portabilidad entre frameworks.
#
# Genera en `<output-dir>/{agent-name}/`:
#   - agent.yaml       manifesto compilado (name, description, tools, limits)
#   - SOUL.md          identidad (description frontmatter)
#   - RULES.md         restricciones extraídas del body
#   - DUTIES.md        segregation policy basada en permission_level (L0-L4)
#   - README.md        cómo usar el agent en cada framework
#
# NO modifica el agente original. NO publica a repos externos — solo
# emite la estructura gitagent en output-dir.
#
# Usage:
#   gitagent-export.sh --agent architect --output-dir output/gitagent-export/
#   gitagent-export.sh --agent code-reviewer --output-dir /tmp/export --format gitagent-0.1
#
# Exit codes:
#   0 — export successful
#   1 — source agent malformed or permission_level unknown
#   2 — usage error
#
# Ref: SPEC-099 §Mapeo, ROADMAP §Tier 4.8
# Safety: read-only on `.opencode/agents/`, set -uo pipefail.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

AGENT=""
OUTPUT_DIR=""
FORMAT="gitagent-0.1"

# Permission level → DUTIES policy (from SPEC-099 §Permission levels → DUTIES).
declare -A L_MUST_NEVER=(
  [L0]="write_files execute_bash modify_config"
  [L1]="execute_bash destructive_ops"
  [L2]="destroy_data force_push merge_pr"
  [L3]="merge_pr deploy_prod destroy_data"
  [L4]="none"
)
declare -A L_MUST_ALWAYS=(
  [L0]="read_only"
  [L1]="read_only non_destructive"
  [L2]="create_branch_agent_ request_human_review"
  [L3]="create_branch_agent_ request_human_review"
  [L4]="audit_all_ops"
)

usage() {
  cat <<EOF
Usage:
  $0 --agent NAME --output-dir DIR [--format FORMAT]

  --agent NAME      Name matching .opencode/agents/{name}.md
  --output-dir DIR  Destination dir (will create subdirectory <agent>/)
  --format FORMAT   gitagent-0.1 (default, only supported in Slice 1)

Generates:
  <output-dir>/<agent>/
  ├── agent.yaml    (manifesto)
  ├── SOUL.md       (identity)
  ├── RULES.md      (restrictions)
  ├── DUTIES.md     (segregation policy per permission_level)
  └── README.md     (framework usage instructions)

Ref: SPEC-099, ROADMAP §Tier 4.8
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$AGENT" ]] && { echo "ERROR: --agent required" >&2; exit 2; }
[[ -z "$OUTPUT_DIR" ]] && { echo "ERROR: --output-dir required" >&2; exit 2; }

SRC="$REPO_ROOT/.opencode/agents/$AGENT.md"
[[ ! -f "$SRC" ]] && { echo "ERROR: agent not found: $SRC" >&2; exit 1; }

if [[ "$FORMAT" != "gitagent-0.1" ]]; then
  echo "ERROR: --format '$FORMAT' not supported (only gitagent-0.1)" >&2
  exit 2
fi

TARGET="$OUTPUT_DIR/$AGENT"
mkdir -p "$TARGET"

# Extract frontmatter fields.
python3 - "$SRC" "$TARGET" "$AGENT" <<'PY'
import re, sys, os
from pathlib import Path

src = Path(sys.argv[1])
target = Path(sys.argv[2])
agent_name = sys.argv[3]

content = src.read_text()
fm_match = re.match(r'^---\n(.+?)\n---\n(.*)', content, re.DOTALL)
if not fm_match:
    print("ERROR: agent frontmatter missing or malformed", file=sys.stderr)
    sys.exit(1)

fm_raw = fm_match.group(1)
body = fm_match.group(2).strip()

def get_field(key):
    m = re.search(rf'^{key}:\s*(.+?)(?=^\w|\Z)', fm_raw, re.MULTILINE | re.DOTALL)
    return m.group(1).strip() if m else None

name = get_field('name') or agent_name
description = get_field('description') or '(no description)'
tools_raw = get_field('tools') or ''
# Handle YAML list format ("- Read\n  - Glob") and CSV format ("Read, Glob").
if '\n' in tools_raw and '- ' in tools_raw:
    tools = [re.sub(r'^-\s*', '', t.strip()) for t in tools_raw.split('\n') if t.strip()]
    tools = [t for t in tools if t and not t.startswith('#')]
elif tools_raw:
    tools = [t.strip() for t in tools_raw.split(',') if t.strip()]
else:
    tools = []
token_budget = get_field('token_budget') or '20000'
permission_level = get_field('permission_level') or 'L2'

# Normalize permission_level.
p_level = permission_level.strip().upper()
if p_level not in ('L0', 'L1', 'L2', 'L3', 'L4'):
    p_level = 'L2'  # safe default

# Emit agent.yaml.
if tools:
    tools_yaml = '\n  - ' + '\n  - '.join(tools)
else:
    tools_yaml = ' []'
agent_yaml = f"""# gitagent manifesto v0.1 (from pm-workspace adapter)
name: "{name}"
description: |
  {description.replace(chr(10), chr(10) + '  ')}
source:
  origin: "pm-workspace"
  type: "claude-code-agent"
  file: ".opencode/agents/{agent_name}.md"
tools:{tools_yaml}
limits:
  context_tokens: {token_budget}
  permission_level: "{p_level}"
activation:
  framework_hints:
    - claude-code
    - openai-assistants
    - cursor
    - lyzr
"""
(target / "agent.yaml").write_text(agent_yaml)

# SOUL.md.
soul = f"""# {name}

## Who I am
{description}

## My role
Agent adapted from pm-workspace. See agent.yaml for tools and limits.
"""
(target / "SOUL.md").write_text(soul)

# RULES.md — extract bullet points or first section body.
rules_section = ""
m = re.search(r'^#+\s*(Rules|Restrictions|Must never|Prohibitions)\s*$(.+?)(?=^#|\Z)', body, re.MULTILINE | re.DOTALL | re.IGNORECASE)
if m:
    rules_section = m.group(2).strip()
else:
    # Fallback: take first code block or first 40 lines.
    rules_section = '\n'.join(body.split('\n')[:40])
(target / "RULES.md").write_text(f"# Rules — {name}\n\n{rules_section}\n")

# DUTIES.md — from permission_level.
duties_map = {
    'L0': {"must_never": "write_files, execute_bash, modify_config", "must_always": "read_only"},
    'L1': {"must_never": "execute_bash, destructive_ops", "must_always": "read_only, non_destructive"},
    'L2': {"must_never": "destroy_data, force_push, merge_pr", "must_always": "create_branch_agent_*, request_human_review"},
    'L3': {"must_never": "merge_pr, deploy_prod, destroy_data", "must_always": "create_branch_agent_*, request_human_review"},
    'L4': {"must_never": "(none — full admin)", "must_always": "audit_all_ops"},
}
d = duties_map[p_level]
duties = f"""# Duties — {name}

**Permission level**: {p_level}

## Must NEVER
{d['must_never']}

## Must ALWAYS
{d['must_always']}

## Conflicts
- Cannot hold dual role with `{p_level}-incompatible` agents

Ref: SPEC-099 §Permission levels → DUTIES
"""
(target / "DUTIES.md").write_text(duties)

# README.md — framework usage hints.
readme = f"""# {name} — gitagent export

Exported from pm-workspace agent `.opencode/agents/{agent_name}.md`
using `scripts/gitagent-export.sh`.

## Files

- `agent.yaml` — gitagent v0.1 manifesto
- `SOUL.md`    — identity / role
- `RULES.md`   — behavioral restrictions
- `DUTIES.md`  — segregation policy ({p_level})

## Usage

### In Claude Code
Original location: `.opencode/agents/{agent_name}.md` (no changes needed).

### In OpenAI Assistants / other frameworks
Import `agent.yaml` as base manifesto.
Map `tools:` to framework-native tool names.
Apply `RULES.md` + `SOUL.md` as system prompt prefix.
Enforce `DUTIES.md` via framework RBAC if supported.

### Regeneration
Re-run `scripts/gitagent-export.sh --agent {agent_name} --output-dir <DIR>`
after any change to the source agent.

Ref: SPEC-099
"""
(target / "README.md").write_text(readme)

print(f"gitagent-export: {agent_name} → {target}")
print(f"  files: agent.yaml, SOUL.md, RULES.md, DUTIES.md, README.md")
print(f"  permission_level: {p_level}")
PY
rc=$?
exit $rc
