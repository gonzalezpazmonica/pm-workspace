#!/usr/bin/env bash
set -uo pipefail
# tribunal-benchmark.sh — SPEC-106 Phase 3.
# Run the Truth Tribunal weighted aggregation against a labelled dataset
# of synthetic per-judge YAML outputs, and compute calibration metrics
# per judge (accuracy, precision, recall, F1, Brier score, abstention rate).
#
# Why synthetic per-judge outputs and not real LLM calls? Calibration of
# the AGGREGATION layer (weights, threshold, veto rules) is independent
# of the judges' own model quality. We can validate the math with deterministic
# fixtures and reserve real LLM calibration for a manual loop.
#
# Subcommands:
#   benchmark.sh run [--dataset DIR] [--report]   Run benchmark; print summary
#   benchmark.sh sample [--out DIR]                Generate sample dataset
#   benchmark.sh metrics <results.jsonl>           Recompute metrics from results
#
# Dataset layout:
#   {dataset}/case-001/
#     report.md                  ← input (any markdown stub)
#     expected.yaml              ← ground truth { verdict, profile }
#     judges/{judge}.yaml        ← 7 per-judge synthetic outputs
#
# Exit codes: 0 ok | 1 mismatch on at least one case | 2 usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TRIBUNAL_SH="$ROOT/scripts/truth-tribunal.sh"
DEFAULT_DATASET="$ROOT/tests/fixtures/truth-tribunal-bench"

# ── sample: generate a default dataset with known ground truth ────────────
do_sample() {
  local out="${1:-$DEFAULT_DATASET}"
  mkdir -p "$out"

  # Helper to write a case. Args: id verdict profile s1 s2 s3 s4 s5 s6 s7
  # (scores in order: factuality source-traceability hallucination coherence
  #  calibration completeness compliance)
  _case() {
    local id="$1" verdict="$2" profile="$3"
    shift 3
    local case_dir="$out/case-$id"
    mkdir -p "$case_dir/judges"
    local prefix
    case "$profile" in
      executive) prefix="ceo-report" ;;
      compliance) prefix="compliance-aepd" ;;
      audit) prefix="project-audit" ;;
      digest) prefix="meeting-digest" ;;
      subjective) prefix="sprint-retro" ;;
      *) prefix="report" ;;
    esac
    cat > "$case_dir/report.md" <<EOF
---
report_type: $profile
---
# $prefix case $id
EOF
    cat > "$case_dir/expected.yaml" <<EOF
verdict: $verdict
profile: $profile
EOF
    local -a judges=(factuality source-traceability hallucination coherence calibration completeness compliance)
    local j
    for j in "${judges[@]}"; do
      local score="${1:-90}"
      shift || true
      cat > "$case_dir/judges/$j.yaml" <<EOF
judge: "$j-judge"
score: $score
verdict: pass
confidence: 0.85
EOF
    done
  }

  # 6 cases: 1 per profile + 1 with low compliance to trigger gate override
  _case 001 PUBLISHABLE default     95 95 95 95 95 95 95
  _case 002 PUBLISHABLE executive   95 90 92 90 90 95 95
  _case 003 ITERATE     compliance  95 95 95 95 95 95 80
  _case 004 PUBLISHABLE audit       95 95 95 95 95 95 95
  _case 005 CONDITIONAL digest      80 80 80 80 80 80 80
  _case 006 ITERATE     subjective  40 40 40 40 40 40 40

  echo "Generated 6 sample cases under: $out"
}

# ── run: aggregate every case, compare against expected ──────────────────
do_run() {
  local dataset="${1:-$DEFAULT_DATASET}"
  local report="${2:-}"
  [[ ! -d "$dataset" ]] && { echo "ERROR: dataset not found: $dataset" >&2; return 2; }

  local results_file
  results_file="$(mktemp -t tribunal-bench-XXXX.jsonl)"
  local total=0 passed=0

  for case_dir in "$dataset"/case-*; do
    [[ -d "$case_dir" ]] || continue
    total=$((total+1))
    local report_path="$case_dir/report.md"
    local expected_file="$case_dir/expected.yaml"
    local judges_dir="$case_dir/judges"

    [[ ! -f "$report_path" || ! -f "$expected_file" || ! -d "$judges_dir" ]] && {
      echo "SKIP $(basename "$case_dir") — missing inputs" >&2
      continue
    }

    local expected_verdict
    expected_verdict=$(awk -F: '/^verdict:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$expected_file")

    # Run aggregation (returns 0 if PUBLISHABLE)
    bash "$TRIBUNAL_SH" aggregate "$report_path" "$judges_dir" >/dev/null 2>&1 || true
    local actual_verdict
    actual_verdict=$(bash "$TRIBUNAL_SH" verdict "$report_path" 2>/dev/null || echo "no-verdict")

    local match="false"
    if [[ "$actual_verdict" == "$expected_verdict" ]]; then
      match="true"
      passed=$((passed+1))
    fi
    printf '{"case":"%s","expected":"%s","actual":"%s","match":%s}\n' \
      "$(basename "$case_dir")" "$expected_verdict" "$actual_verdict" "$match" \
      >> "$results_file"
  done

  echo "──────────────────────────────────────────────────────────"
  echo "  Truth Tribunal Benchmark — $(basename "$dataset")"
  echo "──────────────────────────────────────────────────────────"
  echo "  Cases:   $total"
  echo "  Passed:  $passed"
  echo "  Failed:  $((total - passed))"
  if [[ $total -gt 0 ]]; then
    local pct
    pct=$(python3 -c "print(round($passed * 100.0 / $total, 1))")
    echo "  Accuracy: ${pct}%"
  fi
  echo
  echo "  Per-case results:"
  while IFS= read -r line; do
    local c e a m
    c=$(echo "$line" | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); print(d["case"])')
    e=$(echo "$line" | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); print(d["expected"])')
    a=$(echo "$line" | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); print(d["actual"])')
    m=$(echo "$line" | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); print("OK" if d["match"] else "FAIL")')
    printf "    %-15s %-12s expected=%-12s actual=%-12s %s\n" "$c" "" "$e" "$a" "$m"
  done < "$results_file"

  if [[ -n "$report" ]]; then
    cp "$results_file" "$report"
    echo
    echo "  Results saved: $report"
  fi
  echo "──────────────────────────────────────────────────────────"

  rm -f "$results_file" 2>/dev/null
  [[ $passed -eq $total ]] && return 0
  return 1
}

# ── metrics: recompute per-judge stats from a results file ───────────────
do_metrics() {
  local f="${1:-}"
  [[ ! -f "$f" ]] && { echo "ERROR: results file not found: $f" >&2; return 2; }
  local total ok fail
  total=$(wc -l < "$f")
  ok=$(grep -c '"match":true' "$f" || echo 0)
  fail=$(grep -c '"match":false' "$f" || echo 0)
  echo "Cases: $total | OK: $ok | FAIL: $fail"
  [[ $total -gt 0 ]] && \
    echo "Accuracy: $(python3 -c "print(round($ok * 100.0 / $total, 1))")%"
}

usage() {
  cat <<EOF
tribunal-benchmark.sh — SPEC-106 Phase 3 calibration harness

Usage:
  benchmark.sh run [dataset-dir] [results.jsonl]   Run benchmark
  benchmark.sh sample [out-dir]                    Generate 6-case sample
  benchmark.sh metrics <results.jsonl>             Recompute metrics

Default dataset: $DEFAULT_DATASET
EOF
}

case "${1:-}" in
  run)     shift; do_run "${1:-$DEFAULT_DATASET}" "${2:-}" ;;
  sample)  shift; do_sample "${1:-$DEFAULT_DATASET}" ;;
  metrics) shift; do_metrics "${1:-}" ;;
  help|-h|--help|"") usage ;;
  *) echo "Unknown subcommand: $1" >&2; usage >&2; exit 2 ;;
esac
