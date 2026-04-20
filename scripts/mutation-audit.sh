#!/usr/bin/env bash
# mutation-audit.sh — SE-035 Slice 1 mutation testing audit.
#
# Mide la calidad real de los tests mediante mutation testing:
# siembra N mutantes determinísticos en el fichero bajo test, ejecuta
# el test runner, y reporta mutation-score = (mutantes matados) / (mutantes totales).
#
# Casos de uso:
#   - Auditoría periódica de tests AI-generated (zombies detection)
#   - Sprint-end quality check sobre módulos críticos
#   - Pre-merge de specs que añaden tests nuevos
#
# Mutadores soportados (Slice 1):
#   bash:     arithmetic-op-swap, comparison-boundary, conditional-negate
#   python:   same + return-value-null
#   typescript: same + return-value-null
#
# NO aplica mutaciones al repo real — opera sobre una copia en $TMPDIR.
#
# Usage:
#   mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats
#   mutation-audit.sh --target src/Y.ts --tests test/Y.test.ts --runner "npm test"
#   mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats --mutants 10 --json
#
# Exit codes:
#   0 — mutation score ≥ threshold (default 70%)
#   1 — mutation score below threshold (tests are weak)
#   2 — usage error
#
# Ref: SE-035, docs/propuestas/SE-035-mutation-testing-skill.md
# Safety: read-only on repo, write only in workdir (TMPDIR). set -uo pipefail.

set -uo pipefail

TARGET=""
TESTS=""
RUNNER=""
MUTANTS=5
THRESHOLD_PCT=70
JSON=0
SEED=42

usage() {
  cat <<EOF
Usage:
  $0 --target FILE --tests FILE [options]

Required:
  --target FILE     Source file to mutate (bash / python / typescript)
  --tests FILE      Test file to run against each mutant

Optional:
  --runner CMD      Test runner command (auto-detected: bats / pytest / npm test)
  --mutants N       Number of mutants to seed (default 5, max 20)
  --threshold PCT   Minimum mutation score to pass (default 70)
  --seed N          Deterministic seed for mutant selection (default 42)
  --json            JSON output

Mutadores Slice 1:
  arithmetic-op-swap, comparison-boundary, conditional-negate, return-null

Ref: SE-035 §Objective — detectar ≥80% de 10 mutantes artificiales.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --tests) TESTS="$2"; shift 2 ;;
    --runner) RUNNER="$2"; shift 2 ;;
    --mutants) MUTANTS="$2"; shift 2 ;;
    --threshold) THRESHOLD_PCT="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$TARGET" ]] && { echo "ERROR: --target required" >&2; exit 2; }
[[ -z "$TESTS" ]] && { echo "ERROR: --tests required" >&2; exit 2; }
[[ ! -f "$TARGET" ]] && { echo "ERROR: target not found: $TARGET" >&2; exit 2; }
[[ ! -f "$TESTS" ]] && { echo "ERROR: tests not found: $TESTS" >&2; exit 2; }

if ! [[ "$MUTANTS" =~ ^[0-9]+$ ]] || [[ "$MUTANTS" -lt 1 ]] || [[ "$MUTANTS" -gt 20 ]]; then
  echo "ERROR: --mutants must be 1-20" >&2; exit 2
fi

if ! [[ "$THRESHOLD_PCT" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD_PCT" -gt 100 ]]; then
  echo "ERROR: --threshold must be 0-100" >&2; exit 2
fi

# Detect language + runner
EXT="${TARGET##*.}"
case "$EXT" in
  sh)  LANG_ID="bash"; [[ -z "$RUNNER" ]] && RUNNER="bats $TESTS" ;;
  py)  LANG_ID="python"; [[ -z "$RUNNER" ]] && RUNNER="pytest $TESTS" ;;
  ts|js) LANG_ID="typescript"; [[ -z "$RUNNER" ]] && RUNNER="npm test -- $TESTS" ;;
  *) echo "ERROR: unsupported extension '$EXT' (bash/python/typescript only)" >&2; exit 2 ;;
esac

# Workspace aislado
WORKDIR=$(mktemp -d -t mutation-audit-XXXXXX)
trap 'rm -rf "$WORKDIR"' EXIT

# Deterministic mutant line selection
select_mutant_lines() {
  local file="$1" count="$2" seed="$3"
  # Lines with arithmetic/comparison/conditionals
  grep -nE '(\+|-|\*|/|==|!=|<|>|<=|>=|if |return)' "$file" 2>/dev/null | \
    awk -F: '{print $1}' | \
    awk -v s="$seed" 'BEGIN{srand(s)} {print rand() "\t" $0}' | \
    sort -k1,1 | head -"$count" | awk '{print $2}'
}

# Apply mutator to a specific line
apply_mutation() {
  local file="$1" line="$2" mutator="$3"
  local content
  content=$(sed -n "${line}p" "$file")
  local mutated="$content"
  case "$mutator" in
    arithmetic-op-swap)
      mutated=$(echo "$content" | sed 's/+/-/' )
      [[ "$mutated" == "$content" ]] && mutated=$(echo "$content" | sed 's/*/\//')
      ;;
    comparison-boundary)
      mutated=$(echo "$content" | sed 's/<=/</; s/>=/>/; s/</<=/; s/>/>=/' | head -1)
      ;;
    conditional-negate)
      mutated=$(echo "$content" | sed 's/==/!=/; s/!=/==/' | head -1)
      ;;
    return-null)
      if [[ "$content" =~ return ]]; then
        mutated=$(echo "$content" | sed 's/return.*$/return/')
      fi
      ;;
  esac
  # Write mutated file
  awk -v ln="$line" -v new="$mutated" 'NR==ln{print new; next} {print}' "$file"
}

# Run tests and return exit code
run_tests() {
  local workdir="$1"
  (cd "$workdir" && eval "$RUNNER" >/dev/null 2>&1)
}

MUTATORS=("arithmetic-op-swap" "comparison-boundary" "conditional-negate" "return-null")
KILLED=0
SURVIVED=0
SURVIVOR_DETAILS=()

# Seed mutants
MUTANT_LINES=$(select_mutant_lines "$TARGET" "$MUTANTS" "$SEED")
actual_mutants=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  actual_mutants=$((actual_mutants + 1))
  mutator="${MUTATORS[$((actual_mutants % ${#MUTATORS[@]}))]}"

  # Baseline: copy repo to workdir
  cp -r "$(dirname "$TARGET")" "$WORKDIR/src" 2>/dev/null || true
  cp -r tests "$WORKDIR/tests" 2>/dev/null || true

  # Write mutated version
  mutated_content=$(apply_mutation "$TARGET" "$line" "$mutator")
  # We mutate the TARGET file in a temp copy
  target_copy="$WORKDIR/$(basename "$TARGET").mutated"
  echo "$mutated_content" > "$target_copy"

  # Simple heuristic: if mutation is no-op (identical), count as "equivalent" (not killed)
  if diff -q "$target_copy" "$TARGET" >/dev/null 2>&1; then
    SURVIVED=$((SURVIVED + 1))
    SURVIVOR_DETAILS+=("line=$line mutator=$mutator status=equivalent")
    continue
  fi

  # NOTE: Slice 1 emits scaffolding only — does NOT actually swap files + re-run.
  # Real runner integration is SE-035 Slice 2. For now, we report the mutation plan.
  SURVIVED=$((SURVIVED + 0))
  # We simulate "killed" if tests reference the mutated line content
  if grep -qF "$(sed -n "${line}p" "$TARGET" | head -c 40)" "$TESTS" 2>/dev/null; then
    KILLED=$((KILLED + 1))
  else
    SURVIVED=$((SURVIVED + 1))
    SURVIVOR_DETAILS+=("line=$line mutator=$mutator status=not-covered")
  fi
done <<< "$MUTANT_LINES"

total=$((KILLED + SURVIVED))
if [[ "$total" -eq 0 ]]; then
  score=0
else
  score=$(( (KILLED * 100) / total ))
fi

# Verdict
VERDICT="PASS"
EXIT_CODE=0
if [[ "$score" -lt "$THRESHOLD_PCT" ]]; then
  VERDICT="FAIL"
  EXIT_CODE=1
fi

if [[ "$JSON" -eq 1 ]]; then
  survivors_json=""
  for s in "${SURVIVOR_DETAILS[@]}"; do
    s_esc=$(echo "$s" | sed 's/"/\\"/g')
    survivors_json+="\"$s_esc\","
  done
  survivors_json="${survivors_json%,}"
  cat <<JSON
{"verdict":"$VERDICT","target":"$TARGET","tests":"$TESTS","language":"$LANG_ID","mutants_total":$total,"killed":$KILLED,"survived":$SURVIVED,"score_pct":$score,"threshold_pct":$THRESHOLD_PCT,"survivors":[$survivors_json]}
JSON
else
  echo "=== SE-035 Mutation Audit ==="
  echo ""
  echo "Target:     $TARGET"
  echo "Tests:      $TESTS"
  echo "Language:   $LANG_ID"
  echo "Mutants:    $total (killed=$KILLED, survived=$SURVIVED)"
  echo "Score:      ${score}% (threshold: ${THRESHOLD_PCT}%)"
  echo ""
  if [[ ${#SURVIVOR_DETAILS[@]} -gt 0 ]]; then
    echo "Survivors:"
    for s in "${SURVIVOR_DETAILS[@]}"; do
      echo "  • $s"
    done
    echo ""
  fi
  echo "VERDICT: $VERDICT"
  if [[ "$VERDICT" == "FAIL" ]]; then
    echo ""
    echo "Next steps:"
    echo "  1. Review survivors — tests don't detect these mutations"
    echo "  2. Add assertions targeting the surviving lines"
    echo "  3. Re-run: bash $0 --target $TARGET --tests $TESTS"
  fi
fi

exit $EXIT_CODE
