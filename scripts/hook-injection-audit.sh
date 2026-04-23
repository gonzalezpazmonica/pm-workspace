#!/usr/bin/env bash
# hook-injection-audit.sh — SE-060 Slice 1 hook injection patterns audit.
#
# Audita .claude/hooks/*.sh contra patrones de inyección de comandos,
# exfiltration, silent error suppression, reverse shell, redirect a
# sockets SSH, unquoted command substitutions y rm -rf no validado.
#
# Usage:
#   hook-injection-audit.sh                     # audit all hooks
#   hook-injection-audit.sh --hook-dir PATH     # custom hooks dir
#   hook-injection-audit.sh --json
#
# Exit codes:
#   0 — no findings
#   1 — findings present
#   2 — usage error
#
# Ref: SE-060, research/agentshield-20260420.md (34 hook rules)
# Safety: read-only. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOK_DIR="$PROJECT_ROOT/.claude/hooks"
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 [--hook-dir PATH] [--json]

Options:
  --hook-dir PATH    Directory with hook scripts (default .claude/hooks)
  --json             JSON output

Audita patrones HOOK-01..HOOK-09 de inyección en hooks.
Ref: SE-060.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hook-dir) HOOK_DIR="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ ! -d "$HOOK_DIR" ]] && { echo "ERROR: hook dir not found: $HOOK_DIR" >&2; exit 2; }

FINDINGS=()

add_finding() {
  local rule="$1" sev="$2" file="$3" line="$4" detail="$5"
  FINDINGS+=("$rule|$sev|$file|$line|$detail")
}

# Parse file-level detector exemptions (SE-060 close-loop)
# Convention: hooks whose purpose is DETECTING dangerous patterns (not executing them)
# declare themselves via a top-of-file comment:
#   # hook-audit-detector: HOOK-03,HOOK-06
# Listed rules are skipped for that file. Wildcard "ALL" skips every rule.
# Only the first 20 lines are parsed to avoid treating regex strings as exemptions.
detector_exemptions() {
  local f="$1"
  head -20 "$f" 2>/dev/null | grep -oE '# hook-audit-detector:[[:space:]]*[A-Za-z0-9_,-]+' \
    | head -1 | sed -E 's/# hook-audit-detector:[[:space:]]*//'
}

is_exempt() {
  local rules="$1" rule="$2"
  [[ -z "$rules" ]] && return 1
  [[ "$rules" == *"ALL"* ]] && return 0
  [[ ",$rules," == *",$rule,"* ]]
}

# Audit a single hook file
audit_hook() {
  local f="$1"
  local rel=${f#$PROJECT_ROOT/}
  local exempt
  exempt=$(detector_exemptions "$f")

  # HOOK-01: eval with non-quoted variable
  if ! is_exempt "$exempt" "HOOK-01"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno content
      lineno="${ln%%:*}"
      content="${ln#*:}"
      add_finding "HOOK-01" "CRITICAL" "$rel" "$lineno" "eval with unquoted variable"
    done < <(grep -nE 'eval\s+[^"$][^|]*\$[A-Za-z_]' "$f" 2>/dev/null | head -5)
  fi

  # HOOK-02: curl POST with variable interpolation (exfil pattern)
  if ! is_exempt "$exempt" "HOOK-02"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      add_finding "HOOK-02" "HIGH" "$rel" "$lineno" "curl POST with variable interpolation (exfil pattern)"
    done < <(grep -nE 'curl.*-X[[:space:]]*POST.*\$[A-Za-z_]' "$f" 2>/dev/null | head -5)
  fi

  # HOOK-03: curl | bash or bash <(curl)
  if ! is_exempt "$exempt" "HOOK-03"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      add_finding "HOOK-03" "CRITICAL" "$rel" "$lineno" "Pipe to shell from curl/wget"
    done < <(grep -nE '(curl|wget)[^|]*\|[[:space:]]*(bash|sh)|bash[[:space:]]*<\(curl' "$f" 2>/dev/null | head -5)
  fi

  # HOOK-04: silent suppression on critical logic (|| : or || true after risky ops)
  # Heuristic: redirect to /dev/null AND failure-swallow on same line with network/eval
  if ! is_exempt "$exempt" "HOOK-04"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      add_finding "HOOK-04" "MEDIUM" "$rel" "$lineno" "Silent error suppression on risky op"
    done < <(grep -nE '(curl|wget|eval|source).*2>/dev/null[[:space:]]*(\|\||;)' "$f" 2>/dev/null | head -3)
  fi

  # HOOK-05: reverse shell pattern /dev/tcp
  if ! is_exempt "$exempt" "HOOK-05"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      add_finding "HOOK-05" "CRITICAL" "$rel" "$lineno" "Reverse shell pattern (/dev/tcp)"
    done < <(grep -nE '/dev/(tcp|udp)/' "$f" 2>/dev/null | head -3)
  fi

  # HOOK-06: sudo without -n flag (interactive prompt in hook = bad)
  if ! is_exempt "$exempt" "HOOK-06"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      local content="${ln#*:}"
      # Skip if -n flag present
      [[ "$content" == *"sudo -n"* ]] && continue
      add_finding "HOOK-06" "HIGH" "$rel" "$lineno" "sudo without -n flag"
    done < <(grep -nE '(^|[[:space:]])sudo[[:space:]]' "$f" 2>/dev/null | head -3)
  fi

  # HOOK-07: redirect to SSH/auth files
  if ! is_exempt "$exempt" "HOOK-07"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      add_finding "HOOK-07" "CRITICAL" "$rel" "$lineno" "Redirect to SSH/auth credential files"
    done < <(grep -nE '>[[:space:]]*(\$HOME|~)/\.(ssh|aws|gnupg)' "$f" 2>/dev/null | head -3)
  fi

  # HOOK-08: unquoted command substitution in critical commands
  # Pattern: `$(...)` or backticks in `rm`, `eval`, `source`, `exec` without quotes
  if ! is_exempt "$exempt" "HOOK-08"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      add_finding "HOOK-08" "HIGH" "$rel" "$lineno" "Unquoted command substitution in critical command"
    done < <(grep -nE '\b(rm|eval|source|exec)[[:space:]]+[^"]*\$\(' "$f" 2>/dev/null | head -3)
  fi

  # HOOK-09: rm -rf $VAR without validation (no prior [ -n "$VAR" ] check)
  if ! is_exempt "$exempt" "HOOK-09"; then
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      local lineno="${ln%%:*}"
      local content="${ln#*:}"
      # Skip if contains obvious safe constructs
      [[ "$content" == *'"${VAR:-default}"'* ]] && continue
      add_finding "HOOK-09" "HIGH" "$rel" "$lineno" "rm with variable without validation"
    done < <(grep -nE '\brm[[:space:]]+(-[rf]+[[:space:]]+)+\$[A-Za-z_]+([^"]|$)' "$f" 2>/dev/null | head -3)
  fi
}

# Collect hook files
HOOK_FILES=()
while IFS= read -r f; do
  [[ -f "$f" ]] && HOOK_FILES+=("$f")
done < <(find "$HOOK_DIR" -maxdepth 2 -name "*.sh" -type f 2>/dev/null | sort)

for f in "${HOOK_FILES[@]}"; do
  audit_hook "$f"
done

count_sev() {
  local s="$1" c=0
  for f in "${FINDINGS[@]}"; do
    [[ "$f" == *"|$s|"* ]] && c=$((c + 1))
  done
  echo "$c"
}

CRIT=$(count_sev "CRITICAL")
HIGH=$(count_sev "HIGH")
MED=$(count_sev "MEDIUM")

EXIT_CODE=0
[[ ${#FINDINGS[@]} -gt 0 ]] && EXIT_CODE=1

if [[ "$JSON" -eq 1 ]]; then
  findings_json=""
  for f in "${FINDINGS[@]}"; do
    IFS='|' read -r rule sev file line detail <<< "$f"
    detail_esc=$(echo "$detail" | sed 's/"/\\"/g')
    findings_json+="{\"rule\":\"$rule\",\"severity\":\"$sev\",\"file\":\"$file\",\"line\":$line,\"detail\":\"$detail_esc\"},"
  done
  findings_json="[${findings_json%,}]"
  cat <<JSON
{"verdict":"$([ $EXIT_CODE -eq 0 ] && echo PASS || echo FAIL)","hooks_audited":${#HOOK_FILES[@]},"findings_count":${#FINDINGS[@]},"critical":$CRIT,"high":$HIGH,"medium":$MED,"findings":$findings_json}
JSON
else
  echo "=== SE-060 Hook Injection Audit ==="
  echo ""
  echo "Hooks audited:   ${#HOOK_FILES[@]}"
  echo "Findings:        ${#FINDINGS[@]} (crit=$CRIT high=$HIGH med=$MED)"
  echo ""
  if [[ ${#FINDINGS[@]} -gt 0 ]]; then
    echo "Findings:"
    for f in "${FINDINGS[@]}"; do
      IFS='|' read -r rule sev file line detail <<< "$f"
      printf "  [%s] %-9s %s:%s\n" "$rule" "$sev" "$file" "$line"
      printf "            %s\n" "$detail"
    done
    echo ""
  fi
  echo "VERDICT: $([ $EXIT_CODE -eq 0 ] && echo PASS || echo FAIL)"
fi

exit $EXIT_CODE
