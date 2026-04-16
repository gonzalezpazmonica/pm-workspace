#!/usr/bin/env bash
set -uo pipefail
# generate-context-index.sh — Generate context index files for workspace and projects
# Usage: generate-context-index.sh [--workspace] [--project NAME] [ROOT]

ROOT="${BASH_SOURCE[0]%/*}/.."; ROOT="$(cd "$ROOT" && pwd)"
MODE="all"; PROJECT_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) MODE="workspace"; shift ;;
    --project) MODE="project"; PROJECT_NAME="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    *) ROOT="$1"; shift ;;
  esac
done
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

count_items() { [[ -d "$1" ]] && find "$1" -maxdepth "${3:-1}" -name "$2" | wc -l || echo 0; }
count_dirs() { [[ -d "$1" ]] && find "$1" -mindepth 1 -maxdepth 1 -type d | wc -l || echo 0; }

generate_workspace() {
  local idx_dir="$ROOT/.context-index" idx_file="$ROOT/.context-index/WORKSPACE.ctx"
  mkdir -p "$idx_dir"
  local rc=$(count_items "$ROOT/docs/rules/domain" '*.md')
  local ac=$(count_items "$ROOT/.claude/agents" '*.md')
  local sc=$(count_dirs "$ROOT/.claude/skills")
  local cc=$(count_items "$ROOT/.claude/commands" '*.md')
  local hc=$(count_items "$ROOT/.claude/hooks" '*.sh')
  # NOTE: project names are N2 (private) — never list them in tracked files.
  # Reference CLAUDE.local.md instead, which is gitignored.
  local plist="listed in CLAUDE.local.md (N2, private)"
  cat > "$idx_file" <<WIDX
# Workspace Context Index
# counts: rules=$rc agents=$ac skills=$sc commands=$cc hooks=$hc
> Where to find and store information at workspace level (N1 public)

## Rules & Governance
[location] docs/rules/domain/ — $rc domain rules loaded on demand via @
[location] docs/rules/languages/ — language conventions (auto-load by file type)
[intent: "what are the rules for X"] → scan docs/rules/domain/ by keyword

## Agents
[location] .claude/agents/ — $ac agent definitions
[intent: "which agent handles X"] → agents-catalog.md or assignment-matrix.md

## Skills & Commands
[location] .claude/skills/ — $sc skills with SKILL.md + DOMAIN.md
[location] .claude/commands/ — $cc slash command definitions
[intent: "how to do X"] → scan skills by name/description
[intent: "what command does X"] → command-catalog.md or /help

## Profiles & Identity
[location] .claude/profiles/savia.md — Savia personality
[location] .claude/profiles/users/{slug}/ — user profiles (N3)

## Agent Memory (3 levels)
[location] public-agent-memory/{agent}/ — shared best practices (N1)
[location] private-agent-memory/{agent}/ — org-specific patterns (N2, gitignored)
[location] projects/{p}/agent-memory/{agent}/ — project-specific (N4)
[digest-target] Generic best practice → public-agent-memory/
[digest-target] Project-specific knowledge → projects/{p}/agent-memory/

## Memory & Docs
[location] ~/.claude/projects/*/memory/ — auto-memory per project context
[location] docs/ — workspace documentation
[location] docs/propuestas/ — SPEC proposals
[intent: "what do we know about X"] → memory-store search or /memory-recall

## Projects
[location] projects/ — active projects: $plist

## Output, Scripts, Tests
[location] output/ — generated reports, audits, dev-sessions
[location] scripts/ — automation scripts
[location] .claude/hooks/ — $hc lifecycle hooks
[location] tests/ — BATS test suites
[digest-target] Generated reports → output/
WIDX
  echo "Generated: $idx_file (workspace)"
}

loc_or_opt() {
  local pdir="$1" path="$2" desc="$3"
  if [[ -e "$pdir/$path" ]]; then echo "[location] $path — $desc"
  else echo "[optional] $path — $desc (not yet created)"; fi
}

generate_project() {
  local name="$1"; local pdir="$ROOT/projects/$name"
  if [[ ! -d "$pdir" ]]; then echo "SKIP: project '$name' not found" >&2; return 1; fi
  local idx_dir="$pdir/.context-index" idx_file="$pdir/.context-index/PROJECT.ctx"
  mkdir -p "$idx_dir"
  cat > "$idx_file" <<PIDX
# Project Context Index: $name
# generated: $NOW
> Where to find and store project-specific information (N4)

## Configuration
$(loc_or_opt "$pdir" "CLAUDE.md" "project config, stack, environments")

## Business Rules
$(loc_or_opt "$pdir" "reglas-negocio.md" "business rules with RN-XXX codes")
$(loc_or_opt "$pdir" "business-rules/" "detailed rule documents")
[intent: "what are the business rules"] → reglas-negocio.md
[digest-target] When extracting rules from meetings/docs → reglas-negocio.md

## Team & Stakeholders
$(loc_or_opt "$pdir" "team/TEAM.md" "team composition and roles")
$(loc_or_opt "$pdir" "equipo.md" "team structure")
[digest-target] When extracting people info → team/

## Meetings & Decisions
$(loc_or_opt "$pdir" "meetings/" "meeting digests and transcripts")
$(loc_or_opt "$pdir" "decision-log.md" "architectural and business decisions")
$(loc_or_opt "$pdir" "_digest-log.md" "digest traceability log")
[digest-target] When processing meeting transcripts → meetings/
[digest-target] When extracting decisions → decision-log.md

## Architecture & Technical
$(loc_or_opt "$pdir" "ARCHITECTURE.md" "system architecture overview")
$(loc_or_opt "$pdir" "specs/" "SDD specifications")
$(loc_or_opt "$pdir" "adrs/" "architecture decision records")

## Analysis, Backlog & Glossary
$(loc_or_opt "$pdir" "analysis/" "business analysis outputs")
$(loc_or_opt "$pdir" "security/" "security audit results")
$(loc_or_opt "$pdir" "backlog/" "Savia Flow backlog items")
$(loc_or_opt "$pdir" "GLOSSARY.md" "project terminology and acronyms")
[digest-target] When extracting domain terms → GLOSSARY.md

## Agent Memory
$(loc_or_opt "$pdir" "agent-memory/" "project-specific agent knowledge")
[digest-target] When agent learns project pattern → agent-memory/{agent}/
PIDX
  echo "Generated: $idx_file (project: $name)"
}

case "$MODE" in
  workspace) generate_workspace ;;
  project) [[ -z "$PROJECT_NAME" ]] && { echo "ERROR: --project requires NAME" >&2; exit 1; }
    generate_project "$PROJECT_NAME" ;;
  all) generate_workspace
    for pdir in "$ROOT/projects"/*/; do
      [[ -d "$pdir" ]] || continue; pname=$(basename "$pdir")
      [[ "$pname" == "node_modules" ]] && continue; generate_project "$pname"
    done ;;
esac
