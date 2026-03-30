#!/usr/bin/env bash
# ── generate-capability-map.sh — Generate .scm index from workspace resources
# Scans commands, skills, agents, scripts. Produces INDEX.scm + category files.
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SCM_DIR="$ROOT/.scm"; CAT_DIR="$SCM_DIR/categories"; mkdir -p "$CAT_DIR"

classify() {
  local name="$1" desc="$2" combined="${1} ${2}"
  case "$name" in
    test-*|pr-*|security-*|a11y-*|qa-*|visual-*|coverage-*|perf-*) echo "quality" ;;
    spec-*|dev-*|arch-*|code-*|pipeline-*|deploy-*|dag-*|worktree-*) echo "development" ;;
    sprint-*|pbi-*|capacity-*|project-*|backlog-*|epic-*|flow-*) echo "planning" ;;
    report-*|dora-*|debt-*|risk-*|kpi-*|metric-*|trace-*|agent-*) echo "analysis" ;;
    memory-*|context-*|nl-*|session-*|compact-*|cache-*) echo "memory" ;;
    msg-*|notify-*|meeting-*|inbox-*|chat-*|slack-*|nctalk-*|savia-*) echo "communication" ;;
    compliance-*|governance-*|aepd-*|bias-*|equality-*|audit-*) echo "governance" ;;
    *) if echo "$combined" | grep -qiE 'test|review|audit|security|lint|coverage'; then echo "quality"
      elif echo "$combined" | grep -qiE 'implement|code|build|deploy|spec|design'; then echo "development"
      elif echo "$combined" | grep -qiE 'sprint|capacity|estimat|decompos|assign|backlog'; then echo "planning"
      elif echo "$combined" | grep -qiE 'trace|metric|performance|debt|risk|report'; then echo "analysis"
      elif echo "$combined" | grep -qiE 'recall|save|search|consolidat|context|memory'; then echo "memory"
      elif echo "$combined" | grep -qiE 'notify|message|digest|meeting|inbox|chat'; then echo "communication"
      elif echo "$combined" | grep -qiE 'compliance|policy|governance|equality|aepd'; then echo "governance"
      else echo "planning"; fi ;;
  esac
}

extract_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null \
    | grep -m1 "^${field}:" \
    | sed "s/^${field}:[[:space:]]*//" \
    | sed 's/^["'"'"']//;s/["'"'"']$//' \
    | head -c 120
}

extract_intents() {
  local desc="$1"
  echo "$desc" | tr '[:upper:]' '[:lower:]' \
    | grep -oE '[a-z]{4,}' \
    | grep -vE '^(para|este|esta|desde|como|cada|tiene|puede|cuando|antes|after|with|from|that|this|will|been|have|more|than|your|into|also)$' \
    | sort -u | head -5 | tr '\n' ',' | sed 's/,$//'
}
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
# ── Scan commands ─────────────────────────────────────────────────────────
for f in "$ROOT"/.claude/commands/*.md; do
  [ -f "$f" ] || continue
  name=$(extract_field "$f" "name")
  [ -z "$name" ] && name=$(basename "$f" .md)
  desc=$(extract_field "$f" "description")
  [ -z "$desc" ] && continue
  cat=$(classify "$name" "$desc")
  intents=$(extract_intents "$desc")
  rel_path=".claude/commands/$(basename "$f")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$cat" "$name" "$intents" "cmd:$rel_path" "$desc" >> "$TMP"
done
# ── Scan skills ───────────────────────────────────────────────────────────
for f in "$ROOT"/.claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  name=$(extract_field "$f" "name")
  [ -z "$name" ] && name=$(basename "$(dirname "$f")")
  desc=$(extract_field "$f" "description")
  [ -z "$desc" ] && continue
  cat=$(classify "$name" "$desc")
  intents=$(extract_intents "$desc")
  rel_path=".claude/skills/$(basename "$(dirname "$f")")/SKILL.md"
  printf '%s\t%s\t%s\t%s\t%s\n' "$cat" "$name" "$intents" "skill:$rel_path" "$desc" >> "$TMP"
done
# ── Scan agents ───────────────────────────────────────────────────────────
for f in "$ROOT"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  name=$(extract_field "$f" "name")
  [ -z "$name" ] && name=$(basename "$f" .md)
  desc=$(extract_field "$f" "description")
  [ -z "$desc" ] && continue
  cat=$(classify "$name" "$desc")
  intents=$(extract_intents "$desc")
  rel_path=".claude/agents/$(basename "$f")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$cat" "$name" "$intents" "agent:$rel_path" "$desc" >> "$TMP"
done
# ── Scan scripts ──────────────────────────────────────────────────────────
for f in "$ROOT"/scripts/*.sh; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .sh)
  desc=$(sed -n '2s/^#[[:space:]]*//p' "$f" 2>/dev/null | head -c 120)
  [ -z "$desc" ] && desc=$(sed -n '3s/^#[[:space:]]*//p' "$f" 2>/dev/null | head -c 120)
  [ -z "$desc" ] && continue
  cat=$(classify "$name" "$desc")
  intents=$(extract_intents "$desc")
  rel_path="scripts/$(basename "$f")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$cat" "$name" "$intents" "script:$rel_path" "$desc" >> "$TMP"
done
total=$(wc -l < "$TMP")
cmd_count=$(grep -c 'cmd:' "$TMP" || true)
skill_count=$(grep -c 'skill:' "$TMP" || true)
agent_count=$(grep -c 'agent:' "$TMP" || true)
script_count=$(grep -c 'script:' "$TMP" || true)
# ── Generate INDEX.scm ───────────────────────────────────────────────────
{
  echo "# Savia Capability Map — INDEX"
  echo "> generated: $(date +%Y-%m-%d) | resources: ${total}"
  echo "> ${cmd_count} commands · ${skill_count} skills · ${agent_count} agents · ${script_count} scripts"
  echo ""
  sort -t$'\t' -k1,1 -k2,2 "$TMP" | while IFS=$'\t' read -r cat name intents path _desc; do
    echo "[${cat}] ${name} — ${intents} — ${path}"
  done
} > "$SCM_DIR/INDEX.scm"
# ── Generate category files ──────────────────────────────────────────────
for cat in quality development planning analysis memory communication governance; do
  catfile="$CAT_DIR/${cat}.scm"
  {
    echo "# ${cat} — Savia Capability Map (L1)"
    echo "> $(grep -c "^${cat}" "$TMP" || echo 0) resources"
    echo ""
    grep "^${cat}" "$TMP" | sort -t$'\t' -k2,2 | while IFS=$'\t' read -r _cat name _intents path desc; do
      echo "- **${name}** (${path%%:*}): ${desc}"
    done
  } > "$catfile"
done

echo "SCM generated: ${total} resources in ${SCM_DIR}/"
echo "  ${cmd_count} commands · ${skill_count} skills · ${agent_count} agents · ${script_count} scripts"
