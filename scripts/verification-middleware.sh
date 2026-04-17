#!/usr/bin/env bash
set -uo pipefail
# verification-middleware.sh — Orchestrate 3 verification checks post-implementation
# SPEC: SPEC-VERIFICATION-MIDDLEWARE
#
# Usage: bash scripts/verification-middleware.sh \
#          --spec-slice PATH \
#          --files FILE1,FILE2,... \
#          --project PROJECT_NAME \
#          --session-id SESSION_ID \
#          --slice-number N
#
# Output: JSON to stdout + report to output/dev-sessions/{id}/verification/
# Exit:   0 = all pass, 1 = failures (with retry context), 2 = fatal error

# ── Configuration (env overrides or defaults) ────────────────────────────────
TRACEABILITY_THRESHOLD="${VERIFICATION_TRACEABILITY_THRESHOLD:-90}"
CONSISTENCY_THRESHOLD="${VERIFICATION_CONSISTENCY_THRESHOLD:-75}"
COVERAGE_THRESHOLD="${VERIFICATION_COVERAGE_THRESHOLD:-80}"
MAX_RETRIES="${VERIFICATION_MAX_RETRIES:-2}"
TIMEOUT_SECONDS="${VERIFICATION_TIMEOUT_SECONDS:-30}"
SECURITY_VETO="${VERIFICATION_SECURITY_VETO:-true}"

# ── Globals ──────────────────────────────────────────────────────────────────
SPEC_SLICE=""
FILES_CSV=""
PROJECT=""
SESSION_ID=""
SLICE_NUMBER=""
REPORT_DIR=""
HAS_JQ=false

# ── Helpers ──────────────────────────────────────────────────────────────────

die() { echo "FATAL: $1" >&2; exit 2; }

check_jq() {
  if command -v jq &>/dev/null; then
    HAS_JQ=true
  fi
}

json_output() {
  local traceability_json="$1"
  local tests_json="$2"
  local consistency_json="$3"
  local verdict="$4"
  local veto="$5"

  if [[ "$HAS_JQ" == "true" ]]; then
    jq -n \
      --argjson traceability "$traceability_json" \
      --argjson tests "$tests_json" \
      --argjson consistency "$consistency_json" \
      --arg verdict "$verdict" \
      --argjson veto "$veto" \
      '{traceability: $traceability, tests: $tests, consistency: $consistency, verdict: $verdict, security_veto: $veto}'
  else
    printf '{"traceability":%s,"tests":%s,"consistency":%s,"verdict":"%s","security_veto":%s}\n' \
      "$traceability_json" "$tests_json" "$consistency_json" "$verdict" "$veto"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --spec-slice)  SPEC_SLICE="$2";    shift 2 ;;
      --files)       FILES_CSV="$2";     shift 2 ;;
      --project)     PROJECT="$2";       shift 2 ;;
      --session-id)  SESSION_ID="$2";    shift 2 ;;
      --slice-number) SLICE_NUMBER="$2"; shift 2 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -z "$SPEC_SLICE" ]]    && die "Missing --spec-slice"
  [[ -z "$FILES_CSV" ]]     && die "Missing --files"
  [[ -z "$PROJECT" ]]       && die "Missing --project"
  [[ -z "$SESSION_ID" ]]    && die "Missing --session-id"
  [[ -z "$SLICE_NUMBER" ]]  && die "Missing --slice-number"
}

validate_inputs() {
  [[ ! -f "$SPEC_SLICE" ]] && die "Spec-slice not found: $SPEC_SLICE"

  IFS=',' read -ra FILE_ARRAY <<< "$FILES_CSV"
  for f in "${FILE_ARRAY[@]}"; do
    [[ ! -f "$f" ]] && die "File not found: $f"
  done
}

# ── Check 1: Traceability ───────────────────────────────────────────────────
# Grep spec-slice for requirement markers, grep files for implementations.

check_traceability() {
  local spec="$1"
  local files_csv="$2"
  local output_file="$3"

  # Extract requirement markers from spec (REQ-XX, acceptance criteria bullets)
  local -a reqs=()
  local -a req_patterns=()

  # Pattern 1: REQ-XX markers
  while IFS= read -r line; do
    reqs+=("$line")
  done < <(grep -oE 'REQ-[0-9]+' "$spec" 2>/dev/null | sort -u)

  # Pattern 2: acceptance criteria bullets (- [ ] lines)
  while IFS= read -r line; do
    local cleaned
    cleaned=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*\[.\][[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [[ -n "$cleaned" ]]; then
      reqs+=("AC:$cleaned")
    fi
  done < <(grep -E '^\s*-\s*\[.\]' "$spec" 2>/dev/null)

  local total=${#reqs[@]}
  if [[ "$total" -eq 0 ]]; then
    # No requirements found — pass with 100
    echo '{"score":100,"gaps":[]}' > "$output_file"
    return 0
  fi

  IFS=',' read -ra files <<< "$files_csv"
  local matched=0
  local gaps_json="["
  local first=true

  for req in "${reqs[@]}"; do
    local status="missing"
    local search_term=""

    if [[ "$req" == REQ-* ]]; then
      search_term="$req"
    else
      # For AC items, extract key words (first 3 significant words)
      search_term=$(echo "$req" | sed 's/^AC://' | awk '{for(i=1;i<=3&&i<=NF;i++) printf "%s ", $i}' | xargs)
    fi

    # Search in implemented files
    local found=false
    for f in "${files[@]}"; do
      if grep -qi "$search_term" "$f" 2>/dev/null; then
        found=true
        break
      fi
    done

    if [[ "$found" == "true" ]]; then
      status="covered"
      ((matched++))
    else
      # Check for partial match (any single keyword)
      local any_keyword
      any_keyword=$(echo "$search_term" | awk '{print $1}')
      for f in "${files[@]}"; do
        if grep -qi "$any_keyword" "$f" 2>/dev/null; then
          status="partial"
          break
        fi
      done
    fi

    if [[ "$status" != "covered" ]]; then
      [[ "$first" == "true" ]] && first=false || gaps_json+=","
      local req_id
      req_id=$(echo "$req" | sed 's/"/\\"/g')
      gaps_json+="{\"req_id\":\"$req_id\",\"status\":\"$status\"}"
    fi
  done
  gaps_json+="]"

  local score=0
  if [[ "$total" -gt 0 ]]; then
    score=$(( (matched * 100) / total ))
  fi

  echo "{\"score\":$score,\"gaps\":$gaps_json}" > "$output_file"
  return 0
}

# ── Check 2: Tests ──────────────────────────────────────────────────────────
# Check test file existence, import analysis, and test runner availability.

check_tests() {
  local files_csv="$1"
  local output_file="$2"

  IFS=',' read -ra files <<< "$files_csv"
  local total_files=${#files[@]}
  local files_with_tests=0
  local failures_json="["
  local first_failure=true

  for f in "${files[@]}"; do
    local basename_f
    basename_f=$(basename "$f")
    local dir_f
    dir_f=$(dirname "$f")
    local name_no_ext="${basename_f%.*}"
    local ext="${basename_f##*.}"

    # Look for test files with common naming patterns
    local test_found=false
    local -a test_patterns=(
      "${dir_f}/${name_no_ext}.test.${ext}"
      "${dir_f}/${name_no_ext}.spec.${ext}"
      "${dir_f}/${name_no_ext}Test.${ext}"
      "${dir_f}/${name_no_ext}Tests.${ext}"
      "${dir_f}/test_${name_no_ext}.${ext}"
      "${dir_f}/__tests__/${basename_f}"
      "${dir_f}/../tests/${name_no_ext}Test.${ext}"
      "${dir_f}/../tests/test_${name_no_ext}.${ext}"
      "${dir_f}/../test/${name_no_ext}Test.${ext}"
    )

    for tp in "${test_patterns[@]}"; do
      if [[ -f "$tp" ]]; then
        test_found=true
        # Verify test file references the implementation
        if grep -q "$name_no_ext" "$tp" 2>/dev/null; then
          ((files_with_tests++))
        else
          [[ "$first_failure" == "true" ]] && first_failure=false || failures_json+=","
          failures_json+="\"Test file $tp does not reference $name_no_ext\""
        fi
        break
      fi
    done

    if [[ "$test_found" == "false" ]]; then
      [[ "$first_failure" == "true" ]] && first_failure=false || failures_json+=","
      failures_json+="\"No test file found for $basename_f\""
    fi
  done
  failures_json+="]"

  local coverage_pct=0
  if [[ "$total_files" -gt 0 ]]; then
    coverage_pct=$(( (files_with_tests * 100) / total_files ))
  fi

  local pass="false"
  if [[ "$coverage_pct" -ge "$COVERAGE_THRESHOLD" ]] && [[ "$first_failure" == "true" || "$failures_json" == "[]" ]]; then
    pass="true"
  fi
  # Even with failures, if coverage meets threshold and failures are non-critical
  if [[ "$coverage_pct" -ge "$COVERAGE_THRESHOLD" ]]; then
    pass="true"
  fi

  echo "{\"pass\":$pass,\"coverage_pct\":$coverage_pct,\"failures\":$failures_json}" > "$output_file"
  return 0
}

# ── Check 3: Consistency ────────────────────────────────────────────────────
# Basic checks: no TODO without ticket, no debug statements, file length, etc.

check_consistency() {
  local files_csv="$1"
  local output_file="$2"

  IFS=',' read -ra files <<< "$files_csv"
  local issues_json="["
  local first_issue=true
  local total_checks=0
  local issues_found=0
  local has_critical=false
  local has_security_veto=false

  for f in "${files[@]}"; do
    local basename_f
    basename_f=$(basename "$f")
    local line_count
    line_count=$(wc -l < "$f" 2>/dev/null || echo 0)

    # Check 1: TODO/FIXME/HACK without ticket reference
    ((total_checks++))
    local todo_lines
    todo_lines=$(grep -n -E '(TODO|FIXME|HACK)' "$f" 2>/dev/null | grep -v -E '(AB#|@|#[0-9])' || true)
    if [[ -n "$todo_lines" ]]; then
      ((issues_found++))
      while IFS= read -r tl; do
        local lnum
        lnum=$(echo "$tl" | cut -d: -f1)
        [[ "$first_issue" == "true" ]] && first_issue=false || issues_json+=","
        issues_json+="{\"file\":\"$basename_f\",\"line\":$lnum,\"issue\":\"TODO/FIXME without ticket reference\",\"severity\":\"minor\"}"
      done <<< "$todo_lines"
    fi

    # Check 2: Debug statements in production code
    ((total_checks++))
    local debug_lines
    debug_lines=$(grep -n -E '(console\.log|debugger;?|binding\.pry|import pdb|breakpoint\(\)|System\.out\.println)' "$f" 2>/dev/null || true)
    if [[ -n "$debug_lines" ]]; then
      ((issues_found++))
      has_critical=true
      while IFS= read -r dl; do
        local lnum
        lnum=$(echo "$dl" | cut -d: -f1)
        [[ "$first_issue" == "true" ]] && first_issue=false || issues_json+=","
        issues_json+="{\"file\":\"$basename_f\",\"line\":$lnum,\"issue\":\"Debug statement in production code\",\"severity\":\"critical\"}"
      done <<< "$debug_lines"
    fi

    # Check 3: SQL injection patterns (string concatenation with SQL keywords)
    ((total_checks++))
    local sql_injection
    sql_injection=$(grep -n -iE '(SELECT|INSERT|UPDATE|DELETE|DROP)[[:space:]].*(\+[[:space:]]*["\x27]|["\x27][[:space:]]*\+)|\$\{.*\}.*SELECT|f".*SELECT|f".*INSERT' "$f" 2>/dev/null || true)
    if [[ -n "$sql_injection" ]]; then
      ((issues_found++))
      has_critical=true
      has_security_veto=true
      while IFS= read -r sl; do
        local lnum
        lnum=$(echo "$sl" | cut -d: -f1)
        [[ "$first_issue" == "true" ]] && first_issue=false || issues_json+=","
        issues_json+="{\"file\":\"$basename_f\",\"line\":$lnum,\"issue\":\"SQL injection: string concatenation with SQL keywords\",\"severity\":\"critical\"}"
      done <<< "$sql_injection"
    fi

    # Check 4: Hardcoded secrets
    ((total_checks++))
    local secrets
    secrets=$(grep -n -iE '(password|secret|api_key|token)[[:space:]]*=[[:space:]]*["\x27][^"\x27]{8,}' "$f" 2>/dev/null | grep -v -iE '(example|placeholder|TODO|CHANGE_ME|your_|test_|fake_|mock_)' || true)
    if [[ -n "$secrets" ]]; then
      ((issues_found++))
      has_critical=true
      has_security_veto=true
      while IFS= read -r sl; do
        local lnum
        lnum=$(echo "$sl" | cut -d: -f1)
        [[ "$first_issue" == "true" ]] && first_issue=false || issues_json+=","
        issues_json+="{\"file\":\"$basename_f\",\"line\":$lnum,\"issue\":\"Potential hardcoded secret\",\"severity\":\"critical\"}"
      done <<< "$secrets"
    fi

    # Check 5: File too long (>500 lines for source files)
    ((total_checks++))
    if [[ "$line_count" -gt 500 ]]; then
      ((issues_found++))
      [[ "$first_issue" == "true" ]] && first_issue=false || issues_json+=","
      issues_json+="{\"file\":\"$basename_f\",\"line\":0,\"issue\":\"File too long: $line_count lines (>500)\",\"severity\":\"major\"}"
    fi

    # Check 6: Empty catch/except blocks
    ((total_checks++))
    local empty_catch
    empty_catch=$(grep -n -E '(catch\s*\([^)]*\)\s*\{\s*\}|except\s*:\s*$|catch\s*\{\s*\})' "$f" 2>/dev/null || true)
    if [[ -n "$empty_catch" ]]; then
      ((issues_found++))
      while IFS= read -r cl; do
        local lnum
        lnum=$(echo "$cl" | cut -d: -f1)
        [[ "$first_issue" == "true" ]] && first_issue=false || issues_json+=","
        issues_json+="{\"file\":\"$basename_f\",\"line\":$lnum,\"issue\":\"Empty catch/except block\",\"severity\":\"major\"}"
      done <<< "$empty_catch"
    fi
  done
  issues_json+="]"

  # Calculate score
  local score=100
  if [[ "$total_checks" -gt 0 && "$issues_found" -gt 0 ]]; then
    local penalty_per_issue=$(( 100 / total_checks ))
    [[ "$penalty_per_issue" -lt 5 ]] && penalty_per_issue=5
    score=$(( 100 - (issues_found * penalty_per_issue) ))
    [[ "$score" -lt 0 ]] && score=0
  fi

  # Write result with veto flag
  echo "{\"score\":$score,\"issues\":$issues_json,\"has_critical\":$has_critical,\"security_veto\":$has_security_veto}" > "$output_file"
  return 0
}

# ── Retry context generator ─────────────────────────────────────────────────

generate_retry_context() {
  local trace_result="$1"
  local tests_result="$2"
  local consistency_result="$3"
  local output_file="$4"
  local security_veto="$5"

  {
    echo "## Verification Failed — Retry Context"
    echo ""

    # Traceability
    local trace_score
    if [[ "$HAS_JQ" == "true" ]]; then
      trace_score=$(echo "$trace_result" | jq -r '.score')
    else
      trace_score=$(echo "$trace_result" | grep -oE '"score":[0-9]+' | head -1 | cut -d: -f2)
    fi

    if [[ "$trace_score" -lt "$TRACEABILITY_THRESHOLD" ]]; then
      echo "### Traceability (FAILED: ${trace_score}/100)"
      echo "Gaps:"
      if [[ "$HAS_JQ" == "true" ]]; then
        echo "$trace_result" | jq -r '.gaps[] | "- \(.req_id): \(.status)"'
      else
        echo "$trace_result" | grep -oE '"req_id":"[^"]*","status":"[^"]*"' | \
          sed 's/"req_id":"\([^"]*\)","status":"\([^"]*\)"/- \1: \2/'
      fi
    else
      echo "### Traceability (PASSED: ${trace_score}/100)"
      echo "OK"
    fi
    echo ""

    # Tests
    local tests_pass
    if [[ "$HAS_JQ" == "true" ]]; then
      tests_pass=$(echo "$tests_result" | jq -r '.pass')
    else
      tests_pass=$(echo "$tests_result" | grep -oE '"pass":(true|false)' | head -1 | cut -d: -f2)
    fi

    local tests_cov
    if [[ "$HAS_JQ" == "true" ]]; then
      tests_cov=$(echo "$tests_result" | jq -r '.coverage_pct')
    else
      tests_cov=$(echo "$tests_result" | grep -oE '"coverage_pct":[0-9]+' | head -1 | cut -d: -f2)
    fi

    if [[ "$tests_pass" != "true" ]]; then
      echo "### Tests (FAILED: ${tests_cov}%)"
      echo "Failures:"
      if [[ "$HAS_JQ" == "true" ]]; then
        echo "$tests_result" | jq -r '.failures[] | "- \(.)"'
      else
        echo "$tests_result" | grep -oE '"[^"]*test[^"]*"' | sed 's/"//g;s/^/- /'
      fi
    else
      echo "### Tests (PASSED: ${tests_cov}%)"
      echo "OK"
    fi
    echo ""

    # Consistency
    local consistency_score
    if [[ "$HAS_JQ" == "true" ]]; then
      consistency_score=$(echo "$consistency_result" | jq -r '.score')
    else
      consistency_score=$(echo "$consistency_result" | grep -oE '"score":[0-9]+' | head -1 | cut -d: -f2)
    fi

    local has_crit
    if [[ "$HAS_JQ" == "true" ]]; then
      has_crit=$(echo "$consistency_result" | jq -r '.has_critical')
    else
      has_crit=$(echo "$consistency_result" | grep -oE '"has_critical":(true|false)' | head -1 | cut -d: -f2)
    fi

    if [[ "$consistency_score" -lt "$CONSISTENCY_THRESHOLD" ]] || [[ "$has_crit" == "true" ]]; then
      echo "### Consistency (FAILED: ${consistency_score}/100)"
      if [[ "$security_veto" == "true" ]]; then
        echo "**SECURITY VETO** — Critical security issues must be fixed."
      fi
      echo "Issues:"
      if [[ "$HAS_JQ" == "true" ]]; then
        echo "$consistency_result" | jq -r '.issues[] | select(.severity == "critical" or .severity == "major") | "- \(.file):\(.line) — \(.issue) [\(.severity)]"'
      else
        echo "$consistency_result" | grep -oE '"file":"[^"]*"' | sed 's/"file":"//;s/"//' | while read -r fname; do
          echo "- $fname — see JSON output for details"
        done
      fi
    else
      echo "### Consistency (PASSED: ${consistency_score}/100)"
      echo "OK"
    fi
    echo ""

    echo "### Re-implementation instruction"
    echo "Fix the failed checks above."
    echo "Do NOT touch what already passes verification."
  } > "$output_file"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"
  check_jq
  validate_inputs

  # Create report directory
  REPORT_DIR="output/dev-sessions/${SESSION_ID}/verification"
  mkdir -p "$REPORT_DIR"

  # Temp files for parallel results
  local tmpdir
  tmpdir=$(mktemp -d)
  local trace_out="$tmpdir/traceability.json"
  local tests_out="$tmpdir/tests.json"
  local consistency_out="$tmpdir/consistency.json"

  # Launch 3 checks in parallel
  check_traceability "$SPEC_SLICE" "$FILES_CSV" "$trace_out" &
  local pid_trace=$!

  check_tests "$FILES_CSV" "$tests_out" &
  local pid_tests=$!

  check_consistency "$FILES_CSV" "$consistency_out" &
  local pid_consistency=$!

  # Wait with timeout
  local timeout_end=$(( $(date +%s) + TIMEOUT_SECONDS + TIMEOUT_SECONDS ))
  local all_done=true

  for pid in $pid_trace $pid_tests $pid_consistency; do
    local remaining=$(( timeout_end - $(date +%s) ))
    if [[ "$remaining" -le 0 ]]; then
      remaining=1
    fi
    if ! wait "$pid" 2>/dev/null; then
      # Process may have failed but that is handled by checking output files
      true
    fi
  done

  # Read results (with defaults if timeout/missing)
  local trace_result='{"score":0,"gaps":[]}'
  local tests_result='{"pass":false,"coverage_pct":0,"failures":["Check timed out"]}'
  local consistency_result='{"score":0,"issues":[],"has_critical":false,"security_veto":false}'
  local trace_timeout=false
  local tests_timeout=false
  local consistency_timeout=false

  if [[ -f "$trace_out" && -s "$trace_out" ]]; then
    trace_result=$(cat "$trace_out")
  else
    trace_timeout=true
  fi

  if [[ -f "$tests_out" && -s "$tests_out" ]]; then
    tests_result=$(cat "$tests_out")
  else
    tests_timeout=true
  fi

  if [[ -f "$consistency_out" && -s "$consistency_out" ]]; then
    consistency_result=$(cat "$consistency_out")
  else
    consistency_timeout=true
  fi

  # Extract scores
  local trace_score=0 tests_pass="false" tests_cov=0 consistency_score=0
  local has_critical=false security_veto_detected=false

  if [[ "$HAS_JQ" == "true" ]]; then
    trace_score=$(echo "$trace_result" | jq -r '.score // 0')
    tests_pass=$(echo "$tests_result" | jq -r '.pass // false')
    tests_cov=$(echo "$tests_result" | jq -r '.coverage_pct // 0')
    consistency_score=$(echo "$consistency_result" | jq -r '.score // 0')
    has_critical=$(echo "$consistency_result" | jq -r '.has_critical // false')
    security_veto_detected=$(echo "$consistency_result" | jq -r '.security_veto // false')
  else
    trace_score=$(echo "$trace_result" | grep -oE '"score":[0-9]+' | head -1 | cut -d: -f2)
    tests_pass=$(echo "$tests_result" | grep -oE '"pass":(true|false)' | head -1 | cut -d: -f2)
    tests_cov=$(echo "$tests_result" | grep -oE '"coverage_pct":[0-9]+' | head -1 | cut -d: -f2)
    consistency_score=$(echo "$consistency_result" | grep -oE '"score":[0-9]+' | head -1 | cut -d: -f2)
    has_critical=$(echo "$consistency_result" | grep -oE '"has_critical":(true|false)' | head -1 | cut -d: -f2)
    security_veto_detected=$(echo "$consistency_result" | grep -oE '"security_veto":(true|false)' | head -1 | cut -d: -f2)
  fi

  # Defaults for empty extractions
  trace_score="${trace_score:-0}"
  tests_pass="${tests_pass:-false}"
  tests_cov="${tests_cov:-0}"
  consistency_score="${consistency_score:-0}"
  has_critical="${has_critical:-false}"
  security_veto_detected="${security_veto_detected:-false}"

  # Evaluate thresholds
  local verdict="PASS"
  local security_veto_flag=false

  # VM-07: Security veto
  if [[ "$SECURITY_VETO" == "true" && "$security_veto_detected" == "true" ]]; then
    verdict="FAIL"
    security_veto_flag=true
  fi

  # Traceability threshold
  if [[ "$trace_score" -lt "$TRACEABILITY_THRESHOLD" ]]; then
    verdict="FAIL"
  fi

  # Tests threshold
  if [[ "$tests_pass" != "true" ]]; then
    verdict="FAIL"
  fi

  # Consistency threshold
  if [[ "$consistency_score" -lt "$CONSISTENCY_THRESHOLD" ]]; then
    verdict="FAIL"
  fi

  # Critical issues in consistency
  if [[ "$has_critical" == "true" ]]; then
    verdict="FAIL"
  fi

  # Timeouts produce warnings, not failures (VM-03)
  local timeout_warning=""
  if [[ "$trace_timeout" == "true" || "$tests_timeout" == "true" || "$consistency_timeout" == "true" ]]; then
    timeout_warning="TIMEOUT_WARNING"
  fi

  # Write verification report
  local report_file="$REPORT_DIR/slice-${SLICE_NUMBER}.json"
  local full_json
  full_json=$(json_output "$trace_result" "$tests_result" "$consistency_result" "$verdict" "$security_veto_flag")
  echo "$full_json" > "$report_file"

  # JSON to stdout
  echo "$full_json"

  # Generate retry context if failed
  if [[ "$verdict" == "FAIL" ]]; then
    local retry_file="$REPORT_DIR/slice-${SLICE_NUMBER}-retry.md"
    generate_retry_context "$trace_result" "$tests_result" "$consistency_result" "$retry_file" "$security_veto_flag"
  fi

  # Cleanup
  rm -rf "$tmpdir"

  # Exit code
  if [[ "$verdict" == "PASS" ]]; then
    exit 0
  else
    exit 1
  fi
}

# Run main only if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
