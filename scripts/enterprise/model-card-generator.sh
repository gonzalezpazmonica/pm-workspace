#!/usr/bin/env bash
# model-card-generator.sh — SPEC-SE-006 AI Act Model Cards for Registered Agents
set -uo pipefail
#
# Genera AI Act model cards para cada agente registrado en el workspace.
# Lee:  .opencode/agents/*.md + .claude/enterprise/manifest.json
# Para cada agente: genera .claude/enterprise/model-cards/{agent}.md
#
# Contenido de cada card:
#   - Propósito, modelo LLM, token_budget, permission_level, limitaciones
#   - AI Act Annex III evaluation (auto, con humano como revisor final)
#
# Reference: SPEC-SE-006 (docs/propuestas/savia-enterprise/SPEC-SE-006-governance-compliance.md)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AGENTS_DIR="${ROOT_DIR}/.opencode/agents"
OUTPUT_DIR="${ROOT_DIR}/.claude/enterprise/model-cards"
MANIFEST="${ROOT_DIR}/.claude/enterprise/manifest.json"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
model-card-generator.sh — SPEC-SE-006 AI Act Model Card Generator

Usage:
  model-card-generator.sh [--agent NAME] [--output-dir DIR] [--list]
  model-card-generator.sh --help

Options:
  --agent NAME     Generate card for a single agent only
  --output-dir DIR Override output directory (default: .claude/enterprise/model-cards/)
  --list           List agents that would be processed, then exit

Generates one model card per agent in .claude/enterprise/model-cards/{agent}.md
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

# Extract frontmatter field from agent .md file
extract_field() {
  local file="$1" field="$2"
  # Try YAML frontmatter (between --- markers)
  awk '/^---/{f=!f; next} f && /^'"$field"':/{gsub(/^'"$field"':\s*/, ""); print; exit}' "$file" 2>/dev/null || true
}

# Extract description (first paragraph after frontmatter)
extract_description() {
  local file="$1"
  # Try frontmatter description field first
  local desc
  desc="$(extract_field "$file" "description")"
  if [[ -z "$desc" ]]; then
    # Fall back to first non-empty line after frontmatter
    desc="$(awk 'BEGIN{f=0} /^---/{f++; next} f>=2 && /^[^#]/ && NF>0{print; exit}' "$file" 2>/dev/null || true)"
  fi
  echo "${desc:-No description available}"
}

# Determine Annex III risk category based on agent description + name
annex3_risk() {
  local name="$1" desc="$2"
  local combined="${name} ${desc}"
  combined="${combined,,}"  # lowercase

  # High-risk indicators (AI Act Annex III)
  if echo "$combined" | grep -qE "hr|payroll|resource|bench|recruit|hire|bias|medical|health|safety|critical.infra|banking|credit|loan"; then
    echo "HIGH — Annex III candidate (resource management / financial / critical infra)"
  elif echo "$combined" | grep -qE "security|pentest|vuln|exploit|attack|compliance|legal|gdpr|audit"; then
    echo "MEDIUM — security/compliance tooling, human oversight required"
  elif echo "$combined" | grep -qE "code|developer|writer|analyst|architect|reviewer|test"; then
    echo "LOW — development assistance tool, not Annex III"
  else
    echo "LOW — general purpose tool, not Annex III"
  fi
}

# Generate a single model card
generate_card() {
  local agent_file="$1"
  local agent_name
  agent_name="$(basename "$agent_file" .md)"
  local out_file="${OUTPUT_DIR}/${agent_name}.md"

  # Extract fields
  local model permission_level token_budget
  model="$(extract_field "$agent_file" "model")"
  permission_level="$(extract_field "$agent_file" "permission_level")"
  token_budget="$(extract_field "$agent_file" "token_budget")"
  local description
  description="$(extract_description "$agent_file")"

  # Defaults when not set in frontmatter
  model="${model:-unspecified}"
  permission_level="${permission_level:-L1}"
  token_budget="${token_budget:-8000}"

  # Map model aliases
  case "$model" in
    heavy) model_id="claude-opus-4 (heavy tier)" ;;
    mid)   model_id="claude-sonnet-4.5 (mid tier)" ;;
    fast)  model_id="claude-haiku-3 (fast tier)" ;;
    *)     model_id="${model}" ;;
  esac

  local risk
  risk="$(annex3_risk "$agent_name" "$description")"

  local generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat > "$out_file" <<CARD
---
generated_at: "${generated_at}"
generator: model-card-generator.sh
spec: SE-006
agent: ${agent_name}
---

# AI Model Card — ${agent_name}

> **AI Act Compliance Document** · Generated: ${generated_at}
> Reviewer: human (mandatory for Annex III candidates — Rule 8, CLAUDE.md)

## Identity

| Field | Value |
|-------|-------|
| Agent name | \`${agent_name}\` |
| LLM model | ${model_id} |
| Permission level | ${permission_level} |
| Token budget | ${token_budget} tokens |
| Source | \`.opencode/agents/${agent_name}.md\` |

## Purpose & Capabilities

${description}

## Limitations

- Outputs are proposals, not authoritative decisions (Rule 8 CLAUDE.md — human decides)
- No access to external networks in air-gap mode (SE-005)
- Cannot approve or merge pull requests autonomously (autonomous-safety.md)
- Token budget limits reasoning depth on large codebases
- Not a substitute for domain-expert human review on high-risk tasks

## Bias & Fairness

- Equality Shield (docs/rules/domain/equality-shield.md) applies to all agent outputs
- Counterfactual test enforced: responses must not vary by protected attributes
- Bias test documentation: pending human-led evaluation (required before Annex III production use)

## AI Act Annex III Evaluation

**Risk classification:** ${risk}

| Criterion | Assessment |
|-----------|-----------|
| Annex III candidate | See risk classification above |
| Human oversight gate | E1 gate mandatory (Rule 8 CLAUDE.md) |
| Audit trail | Append-only JSONL via governance-audit-trail.sh |
| Transparency | AI disclosure per SE-025 |
| Data minimisation | Processes only task-scoped context per invocation |

**Reviewer note:** This evaluation is auto-generated. For Annex III HIGH-risk deployments,
a qualified human reviewer must sign off on this card before production use.

## Data Handling

- Input: task context provided at invocation (no persistent PII stored)
- Output: structured text/code written to workspace files or stdout
- Retention: governed by docs/rules/domain/savia-enterprise/audit-retention.md
- No model fine-tuning on customer data

## Change Log

| Date | Change |
|------|--------|
| ${generated_at} | Initial auto-generated card |
CARD

  echo "  → ${out_file}"
}

# ── Argument parsing ─────────────────────────────────────────────────────────

SINGLE_AGENT=""
LIST_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)      SINGLE_AGENT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2";   shift 2 ;;
    --list)       LIST_ONLY=1;       shift ;;
    -h|--help)    usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ── Main ─────────────────────────────────────────────────────────────────────

[[ ! -d "$AGENTS_DIR" ]] && die "Agents directory not found: ${AGENTS_DIR}"

mkdir -p "$OUTPUT_DIR"

# Collect agent files
if [[ -n "$SINGLE_AGENT" ]]; then
  agent_file="${AGENTS_DIR}/${SINGLE_AGENT}.md"
  [[ ! -f "$agent_file" ]] && die "Agent not found: ${agent_file}"
  agent_files=("$agent_file")
else
  mapfile -t agent_files < <(find "$AGENTS_DIR" -name "*.md" -not -name "_*" | sort)
fi

if [[ "$LIST_ONLY" -eq 1 ]]; then
  echo "Agents to process (${#agent_files[@]}):"
  for f in "${agent_files[@]}"; do
    echo "  $(basename "$f" .md)"
  done
  exit 0
fi

echo "Generating model cards for ${#agent_files[@]} agents → ${OUTPUT_DIR}/"
generated=0
for f in "${agent_files[@]}"; do
  generate_card "$f"
  generated=$(( generated + 1 ))
done

echo ""
echo "OK: ${generated} model cards generated"
