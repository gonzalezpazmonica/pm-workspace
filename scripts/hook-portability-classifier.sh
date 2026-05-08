#!/usr/bin/env bash
set -uo pipefail
# hook-portability-classifier.sh — SPEC-127 Slice 2
#
# Classifies each hook in .opencode/hooks/*.sh into one of four portability
# tiers, deterministically, based on heuristics over the hook source and
# its registration in .claude/settings.json:
#
#   TIER-1 portable        — direct equivalent in OpenCode plugin TS
#                            (`tool.execute.before|after`). Hook reads
#                            tool_input JSON from stdin and is registered
#                            for PreToolUse/PostToolUse with a tool matcher
#                            (Bash, Edit, Write, Read, Glob, Grep, ...).
#   TIER-2 git-pre-commit  — file-content validation that doesn't depend
#                            on real-time tool telemetry. Reroute to
#                            `.husky/pre-commit` (or equivalent) so it runs
#                            before `git commit`. Caveat: only catches
#                            committed changes, not in-flight edits.
#   TIER-3 ci-only         — repo-wide audit / heavy operation. Reroute to
#                            GitHub Actions / GitLab CI / Jenkins / etc.
#                            Not real-time, but runs before merge.
#   TIER-4 lost            — depends on events no other frontend exposes
#                            (TaskCreated, SubagentStart, InstructionsLoaded,
#                            ConfigChange, etc.). Cannot port — declare loss.
#
# Output:
#   - stdout: TSV table (hook, event, tier, reason, reroute_target)
#   - --markdown : output/hook-portability-classification.md (full report)
#   - --summary  : aggregate counts only
#
# This classifier is heuristic, NOT vendor-specific. The framework supports
# any frontend × any inference provider — the question is only whether the
# user's stack exposes the surface required by each hook.
#
# Reference: SPEC-127 Slice 2 AC-2.1, AC-2.4
# Reference: docs/rules/domain/provider-agnostic-env.md

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOKS_DIR="${ROOT}/.claude/hooks"
SETTINGS="${ROOT}/.claude/settings.json"
OUT_MD="${ROOT}/output/hook-portability-classification.md"
MODE="tsv"

usage() {
  cat <<USG
Usage: hook-portability-classifier.sh [--markdown | --summary | --json]

Modes:
  (default)    TSV table to stdout
  --markdown   Write full report to ${OUT_MD}
  --summary    Aggregate counts only (TIER-1/2/3/4)
  --json       JSON output (machine-readable)
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown) MODE="markdown"; shift ;;
    --summary)  MODE="summary"; shift ;;
    --json)     MODE="json"; shift ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$HOOKS_DIR" ]] || { echo "ERROR: hooks dir not found: $HOOKS_DIR" >&2; exit 3; }

# Build a quick map: hook-basename → events|matchers it is registered for
# Output: bn TAB events_csv TAB matchers_csv
build_event_map() {
  python3 - "$SETTINGS" <<'PY'
import json, os, sys, re
cfg_path = sys.argv[1]
if not os.path.isfile(cfg_path):
    sys.exit(0)
with open(cfg_path) as f:
    cfg = json.load(f)
hooks = cfg.get("hooks", {})
events_map = {}    # bn -> set(events)
matchers_map = {}  # bn -> set(matchers)
for event, entries in hooks.items():
    for entry in entries:
        matcher = entry.get("matcher", "")
        for h in entry.get("hooks", []):
            cmd = h.get("command", "")
            m = re.search(r'\.opencode/hooks/([\w-]+\.sh)', cmd)
            if m:
                bn = m.group(1)
                events_map.setdefault(bn, set()).add(event)
                if matcher:
                    matchers_map.setdefault(bn, set()).add(matcher)
all_bn = sorted(set(events_map) | set(matchers_map))
for bn in all_bn:
    events = ",".join(sorted(events_map.get(bn, [])))
    matchers = ",".join(sorted(matchers_map.get(bn, [])))
    print(f"{bn}\t{events}\t{matchers}")
PY
}

# Heuristic classification for one hook file
classify_hook() {
  local hook_path="$1" events="$2" matchers="$3"
  local bn
  bn=$(basename "$hook_path")
  local content
  content=$(cat "$hook_path" 2>/dev/null) || { echo "TIER-?"$'\t'"unreadable"$'\t'"-"; return; }

  # Markers — combine hook source heuristics + settings.json matchers
  local reads_tool_input=0 reads_stdin=0 has_matcher=0 has_task_tool=0
  local agent_event=0 file_validation=0 repo_audit=0

  echo "$content" | grep -qE 'tool_input|tool_name'                && reads_tool_input=1
  echo "$content" | grep -qE 'timeout.*cat|read .*stdin|cat.*-$|jq.*tool_input'  && reads_stdin=1
  # Matcher: either declared in settings.json or referenced in source
  if [[ "$matchers" == *Bash* || "$matchers" == *Edit* || "$matchers" == *Write* \
        || "$matchers" == *Read* || "$matchers" == *Glob* || "$matchers" == *Grep* ]]; then
    has_matcher=1
  elif echo "$content" | grep -qE '"(Bash|Edit|Write|Read|Glob|Grep)"'; then
    has_matcher=1
  fi
  # Task tool: settings.json matcher OR source reference
  if [[ "$matchers" == *Task* ]] || echo "$content" | grep -qE 'tool_name.*"Task"|tool_input.*subagent'; then
    has_task_tool=1
  fi
  echo "$content" | grep -qE 'agent_id|session_id|session_metadata|InstructionsLoaded|ConfigChange' && agent_event=1
  echo "$content" | grep -qE 'git status|git diff|staged|--cached|file_path' && file_validation=1
  echo "$content" | grep -qE 'find .* -type f|repo.*scan|all hooks|all agents|all skills' && repo_audit=1

  # Event-based pre-classification
  local tier="" reason="" reroute=""
  case "$events" in
    *TaskCreated*|*TaskCompleted*|*SubagentStart*|*SubagentStop*|*InstructionsLoaded*|*ConfigChange*)
      tier="TIER-4"
      reason="depends on Claude-specific event (${events})"
      reroute="declare loss; document in PV-05 alert"
      ;;
    *PreToolUse*|*PostToolUse*|*PostToolUseFailure*)
      if [[ $reads_tool_input -eq 1 && $has_matcher -eq 1 ]]; then
        tier="TIER-1"
        reason="reads tool_input + matches tool name → portable to plugin TS tool.execute.before/after"
        reroute=".opencode/plugins/savia-critical-hooks.ts"
        if [[ $has_task_tool -eq 1 ]]; then
          tier="TIER-4"
          reason="depends on Task tool — not exposed by every provider"
          reroute="declare loss when stack lacks Task; document"
        fi
      elif [[ $file_validation -eq 1 ]]; then
        tier="TIER-2"
        reason="PreToolUse but operates on file paths — git pre-commit suitable"
        reroute=".husky/pre-commit (file-scoped)"
      else
        tier="TIER-2"
        reason="PreToolUse without strong tool_input dependency"
        reroute=".husky/pre-commit"
      fi
      ;;
    *Stop*|*SessionEnd*|*PreCompact*|*PostCompact*|*CwdChanged*)
      tier="TIER-4"
      reason="depends on session lifecycle event ($events) — not universally exposed"
      reroute="declare loss; document in PV-05 alert"
      ;;
    *SessionStart*)
      tier="TIER-2"
      reason="SessionStart — equivalent: shell rc / OpenCode init plugin"
      reroute="OpenCode plugin SessionStart hook OR shell rc"
      ;;
    *UserPromptSubmit*|*FileChanged*)
      tier="TIER-2"
      reason="prompt/file change — partial reroute via plugin TS or filesystem watcher"
      reroute="OpenCode plugin equivalent OR filewatcher (TIER-2)"
      ;;
    "")
      # Hook exists but not registered in settings.json — likely library helper
      tier="LIB"
      reason="not registered in settings.json — internal helper / library"
      reroute="N/A"
      ;;
    *)
      tier="TIER-?"
      reason="unrecognized event chain: ${events}"
      reroute="manual review required"
      ;;
  esac

  # Heavy operations override → TIER-3 (CI-only) when the cost is too high
  # for real-time. Currently we keep PreToolUse classification — Slice 2b can
  # tighten this with timing data.
  if [[ $repo_audit -eq 1 && "$tier" == "TIER-2" ]]; then
    tier="TIER-3"
    reason="full repo audit — too heavy for pre-commit, ship as CI job"
    reroute=".github/workflows/ OR equivalent CI"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$bn" "$events" "$tier" "$reason" "$reroute"
}

# Main: iterate hooks, emit rows
emit_rows() {
  local map_file
  map_file=$(mktemp)
  build_event_map > "$map_file"
  for hook in "$HOOKS_DIR"/*.sh; do
    [[ -f "$hook" ]] || continue
    local bn events matchers
    bn=$(basename "$hook")
    events=$(awk -F'\t' -v k="$bn" '$1==k {print $2}' "$map_file")
    matchers=$(awk -F'\t' -v k="$bn" '$1==k {print $3}' "$map_file")
    classify_hook "$hook" "$events" "$matchers"
  done
  rm -f "$map_file"
}

ROWS=$(emit_rows)

case "$MODE" in
  tsv)
    printf 'hook\tevents\ttier\treason\treroute\n'
    printf '%s\n' "$ROWS"
    ;;

  summary)
    printf '%s\n' "$ROWS" | awk -F'\t' '
      { tiers[$3]++ }
      END {
        for (t in tiers) printf "%-10s %d\n", t, tiers[t]
      }
    ' | sort
    ;;

  json)
    printf '%s\n' "$ROWS" | python3 -c '
import json, sys
rows = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line: continue
    parts = line.split("\t")
    if len(parts) < 5: continue
    rows.append({"hook": parts[0], "events": parts[1], "tier": parts[2], "reason": parts[3], "reroute": parts[4]})
print(json.dumps({"hooks": rows, "count": len(rows)}, indent=2))
'
    ;;

  markdown)
    mkdir -p "$(dirname "$OUT_MD")"
    {
      echo "# Hook portability classification (SPEC-127 Slice 2)"
      echo ""
      echo "> Auto-generated by \`scripts/hook-portability-classifier.sh\`. Do not edit by hand."
      echo "> Run \`bash scripts/hook-portability-classifier.sh --markdown\` to regenerate."
      echo ""
      echo "## Tier definitions"
      echo ""
      echo "- **TIER-1 portable**: direct equivalent in OpenCode plugin TS (\`tool.execute.before|after\`). Real-time enforcement preserved."
      echo "- **TIER-2 git-pre-commit**: reroute to \`.husky/pre-commit\` or equivalent. Catches committed changes, not in-flight edits."
      echo "- **TIER-3 ci-only**: too heavy for real-time. Run as CI job (GitHub Actions / GitLab CI / Jenkins / etc.)."
      echo "- **TIER-4 lost**: depends on events no other frontend exposes (Task tool, SubagentStart, session lifecycle). Declare loss explicitly per PV-05."
      echo "- **LIB**: not registered as a hook — internal library / helper. Out of scope."
      echo ""
      echo "## Summary"
      echo ""
      echo "\`\`\`"
      printf '%s\n' "$ROWS" | awk -F'\t' '{ tiers[$3]++ } END { for (t in tiers) printf "%-10s %d\n", t, tiers[t] }' | sort
      echo "\`\`\`"
      echo ""
      echo "## Per-hook classification"
      echo ""
      echo "| Hook | Events | Tier | Reason | Reroute target |"
      echo "|---|---|---|---|---|"
      printf '%s\n' "$ROWS" | awk -F'\t' '{ printf "| `%s` | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }'
      echo ""
      echo "## Safety-critical coverage check (PV-02)"
      echo ""
      echo "The following hooks are safety-critical and MUST be in TIER-1 or TIER-2:"
      echo ""
      for crit in block-credential-leak block-gitignored-references prompt-injection-guard; do
        row=$(printf '%s\n' "$ROWS" | awk -F'\t' -v h="${crit}.sh" '$1==h {print}')
        if [[ -n "$row" ]]; then
          tier=$(echo "$row" | awk -F'\t' '{print $3}')
          if [[ "$tier" == "TIER-1" || "$tier" == "TIER-2" ]]; then
            echo "- ✅ \`${crit}.sh\` → ${tier}"
          else
            echo "- ⚠️  \`${crit}.sh\` → ${tier} (PV-02 violation if shipped)"
          fi
        else
          echo "- ⚠️  \`${crit}.sh\` not found in workspace"
        fi
      done
      echo ""
      echo "## Spec ref"
      echo ""
      echo "- SPEC-127 Slice 2 AC-2.1, AC-2.4"
      echo "- \`docs/rules/domain/provider-agnostic-env.md\`"
    } > "$OUT_MD"
    echo "wrote ${OUT_MD} ($(wc -l < "$OUT_MD") lines)"
    ;;
esac
