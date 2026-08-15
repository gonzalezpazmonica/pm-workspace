#!/usr/bin/env bash
# mutation-audit.sh — SE-035 mutation testing audit.
#
# Slice 2 (real execution): siembra N mutantes determinísticos en el fichero
# bajo test, ejecuta el test runner REAL contra una copia aislada, y reporta
# mutation-score = (mutantes matados) / (mutantes ejecutados).
#
# Guard de ejecución (checker-fail-closed): antes de mutar, corre el runner
# contra el árbol prístino (baseline) — si no devuelve 0, aborta en vez de
# fabricar un score. Cada mutante se ejecuta realmente; nunca se simula un kill.
#
# Mutadores soportados:
#   bash:     arithmetic-op-swap, comparison-boundary, conditional-negate
#   python:   same + return-value-null
#   typescript: same + return-value-null
#
# NO aplica mutaciones al repo real — opera sobre una copia aislada (git archive
# o cp) en $TMPDIR.
#
# Usage:
#   mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats
#   mutation-audit.sh --target src/Y.ts --tests test/Y.test.ts --runner "npm test"
#   mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats --mutants 10 --json
#   mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats --simulate   # Slice 1 fast path
#
# Exit codes:
#   0 — mutation score ≥ threshold (default 70%)
#   1 — mutation score below threshold (tests are weak)
#   2 — usage error
#   3 — runner/baseline error (fail-closed: no trustworthy result)
#
# Ref: SE-035, docs/propuestas/SE-035-mutation-testing-skill.md
#      docs/rules/domain/checker-fail-closed.md
# Safety: read-only on repo, write only in $TMPDIR workdir. set -uo pipefail.

set -uo pipefail

TARGET=""
TESTS=""
RUNNER=""
MUTANTS=5
THRESHOLD_PCT=70
JSON=0
SEED=42
SIMULATE=0

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
  --simulate        Slice 1 fast path — NO real runner execution (results labeled "simulated")
  --json            JSON output

Mutadores: arithmetic-op-swap, comparison-boundary, conditional-negate, return-null

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
    --simulate) SIMULATE=1; shift ;;
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

# Recursion guard: when the runner being executed re-invokes this script (the
# self-referential case), the inner invocation must NOT re-run the runner or we
# recurse forever. Force simulation on inner invocations.
[[ "${MUTATION_AUDIT_INNER:-0}" == "1" ]] && SIMULATE=1

# Detect language + runner
EXT="${TARGET##*.}"
case "$EXT" in
  sh)  LANG_ID="bash"; [[ -z "$RUNNER" ]] && RUNNER="bats $TESTS" ;;
  py)  LANG_ID="python"; [[ -z "$RUNNER" ]] && RUNNER="pytest $TESTS" ;;
  ts|js) LANG_ID="typescript"; [[ -z "$RUNNER" ]] && RUNNER="npm test -- $TESTS" ;;
  *) echo "ERROR: unsupported extension '$EXT' (bash/python/typescript only)" >&2; exit 2 ;;
esac

# Project root + repo-relative paths (for the isolated tree)
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
target_rel="$(realpath --relative-to="$PROJECT_ROOT" "$TARGET" 2>/dev/null || echo "$TARGET")"
tests_rel="$(realpath --relative-to="$PROJECT_ROOT" "$TESTS" 2>/dev/null || echo "$TESTS")"

# Mutators (Slice 1 set). Order defines the deterministic try-order in choose_mutation.
MUTATORS=(arithmetic-op-swap comparison-boundary conditional-negate return-null)

# Workspace aislado
WORKDIR=$(mktemp -d -t mutation-audit-XXXXXX)
trap 'rm -rf "$WORKDIR"' EXIT

# Deterministic mutant line selection (no RNG — reproducible across awk impls).
# Rotates the candidate list by (seed % total) and takes the next `count` lines.
select_mutant_lines() {
  local file="$1" count="$2" seed="$3"
  grep -nE '(\+|-|\*|/|==|!=|<|>|<=|>=|if |return)' "$file" 2>/dev/null | \
    awk -F: '{print $1}' | \
    awk -v n="$count" -v s="$seed" '
      { lines[NR]=$1 }
      END {
        total = NR
        if (total == 0) exit 0
        start = (s % total) + 1
        for (i = 0; i < n && i < total; i++) {
          idx = ((start - 1 + i) % total) + 1
          print lines[idx]
        }
      }'
}

# Apply a single mutator to a line of content. Emits the mutated line on stdout
# (equal to the input when the mutator does not apply to this line).
mutate_line() {
  local content="$1" mutator="$2" mutated="$1"
  case "$mutator" in
    arithmetic-op-swap)
      mutated=$(printf '%s' "$content" | sed 's/+/-/')
      [[ "$mutated" == "$content" ]] && mutated=$(printf '%s' "$content" | sed 's/\*/\//')
      ;;
    comparison-boundary)
      mutated=$(printf '%s' "$content" | sed 's/<=/</g; s/>=/>/g; s/</<=/g; s/>/>=/g')
      ;;
    conditional-negate)
      mutated=$(printf '%s' "$content" | sed 's/==/!=/g')
      ;;
    return-null)
      [[ "$content" =~ return ]] && mutated=$(printf '%s' "$content" | sed 's/return.*$/return/')
      ;;
  esac
  printf '%s' "$mutated"
}

# Emit the full file with line `line` replaced by `newline`.
mutate_file() {
  local file="$1" line="$2" newline="$3"
  awk -v ln="$line" -v new="$newline" 'NR==ln{print new; next} {print}' "$file"
}

# Try mutators in order until one actually changes the line. Emits
# "<mutator>\t<mutated_line>" or nothing if no mutator applies.
choose_mutation() {
  local content="$1" i m mline
  for i in 0 1 2 3; do
    m="${MUTATORS[$i]}"
    mline=$(mutate_line "$content" "$m")
    if [[ "$mline" != "$content" ]]; then
      printf '%s\t%s' "$m" "$mline"
      return 0
    fi
  done
  return 1
}

# ── Real execution path ─────────────────────────────────────────────────────

build_isolated_tree() {
  local workdir="$1"
  local used_git=0
  # Copy tracked files from the WORKING TREE (git ls-files reads current content,
  # so uncommitted modifications are included; .git/node_modules/.venv are skipped
  # because they are untracked/ignored).
  if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if (cd "$PROJECT_ROOT" && git ls-files -z | tar --null -T - -cf - 2>/dev/null | tar -xf - -C "$workdir" 2>/dev/null); then
      used_git=1
    fi
  fi
  # Belt-and-suspenders: ensure target + test exist in the workdir (covers
  # untracked fixtures that git ls-files skips).
  if [[ ! -e "$workdir/$target_rel" ]]; then
    mkdir -p "$(dirname "$workdir/$target_rel")" && cp -a "$PROJECT_ROOT/$target_rel" "$workdir/$target_rel"
  fi
  if [[ ! -e "$workdir/$tests_rel" ]]; then
    mkdir -p "$(dirname "$workdir/$tests_rel")" && cp -a "$PROJECT_ROOT/$tests_rel" "$workdir/$tests_rel"
  fi
  if [[ "$used_git" -eq 0 ]]; then
    # Non-git fallback: copy the target/test trees.
    mkdir -p "$(dirname "$workdir/$target_rel")" && cp -a "$PROJECT_ROOT/$target_rel" "$workdir/$target_rel" 2>/dev/null || true
    mkdir -p "$(dirname "$workdir/$tests_rel")" && cp -a "$PROJECT_ROOT/$tests_rel" "$workdir/$tests_rel" 2>/dev/null || true
  fi
}

# Rebase the runner command to point at the workdir copy of the test file.
rebased_runner() {
  printf '%s' "$RUNNER" | sed "s|$TESTS|$WORKDIR/$tests_rel|g"
}

clear_bytecode_cache() {
  find "$WORKDIR" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null
  find "$WORKDIR" -type f -name '*.pyc' -delete 2>/dev/null
}

execute_real() {
  build_isolated_tree "$WORKDIR"

  local wtarget="$WORKDIR/$target_rel"
  local pristine="$WORKDIR/.pristine-target"
  cp -a "$PROJECT_ROOT/$target_rel" "$pristine" 2>/dev/null || cp -a "$TARGET" "$pristine"

  local rrunner
  rrunner=$(rebased_runner)

  # ── Baseline gate (fail-closed) ──────────────────────────────────────
  # Prove the runner works against the pristine isolated tree BEFORE trusting
  # any mutant result. A non-zero baseline means the runner/tree is broken,
  # not that a mutant was caught.
  (cd "$WORKDIR" && export MUTATION_AUDIT_INNER=1 && eval "$rrunner" >/dev/null 2>&1)
  local baseline=$?
  if [[ "$baseline" -ne 0 ]]; then
    echo "ERROR: baseline runner failed (exit $baseline). Runner '$RUNNER' may be missing or broken against the isolated tree. Install the runner or pass --runner / --simulate. Aborting (fail-closed)." >&2
    return 3
  fi

  local killed=0 survived=0 equivalent=0 executed=0
  SURVIVOR_DETAILS=()
  local line mutator mutated_line orig_content chosen idx=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))

    orig_content=$(sed -n "${line}p" "$TARGET")
    chosen=$(choose_mutation "$orig_content") || {
      equivalent=$((equivalent + 1))
      SURVIVOR_DETAILS+=("line=$line mutator=none status=equivalent")
      continue
    }
    mutator="${chosen%%$'\t'*}"
    mutated_line="${chosen#*$'\t'}"

    # Write the mutated target into the isolated tree.
    mutate_file "$TARGET" "$line" "$mutated_line" > "$wtarget"

    # Guard: mutation actually applied? Identical → equivalent mutant, not a kill.
    if cmp -s "$wtarget" "$pristine"; then
      equivalent=$((equivalent + 1))
      SURVIVOR_DETAILS+=("line=$line mutator=$mutator status=equivalent")
      cp -a "$pristine" "$wtarget"
      continue
    fi

    # Guard: defeat bytecode-cache reuse (python) + pin a distinct mtime.
    clear_bytecode_cache
    touch -d "@$(( 1000000000 + idx ))" "$wtarget" 2>/dev/null

    (cd "$WORKDIR" && export MUTATION_AUDIT_INNER=1 && eval "$rrunner" >/dev/null 2>&1)
    local rc=$?

    executed=$((executed + 1))
    if [[ "$rc" -ne 0 ]]; then
      killed=$((killed + 1))
    else
      survived=$((survived + 1))
      SURVIVOR_DETAILS+=("line=$line mutator=$mutator status=survived")
    fi

    # Restore pristine target (mutant isolation).
    cp -a "$pristine" "$wtarget"
  done <<< "$(select_mutant_lines "$TARGET" "$MUTANTS" "$SEED")"

  KILLED=$killed
  SURVIVED=$survived
  EQUIVALENT=$equivalent
  EXECUTED=$executed
  EXEC_MODE="real"
  return 0
}

# ── Simulation path (Slice 1, explicitly labeled) ───────────────────────────

execute_simulate() {
  local killed=0 survived=0 equivalent=0 idx=0
  SURVIVOR_DETAILS=()
  local line mutator mutated_line orig_content chosen target_copy

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))

    orig_content=$(sed -n "${line}p" "$TARGET")
    chosen=$(choose_mutation "$orig_content") || {
      equivalent=$((equivalent + 1))
      SURVIVOR_DETAILS+=("line=$line mutator=none status=equivalent")
      continue
    }
    mutator="${chosen%%$'\t'*}"
    mutated_line="${chosen#*$'\t'}"

    target_copy="$WORKDIR/$(basename "$TARGET").mutated"
    mutate_file "$TARGET" "$line" "$mutated_line" > "$target_copy"

    if diff -q "$target_copy" "$TARGET" >/dev/null 2>&1; then
      equivalent=$((equivalent + 1))
      SURVIVOR_DETAILS+=("line=$line mutator=$mutator status=equivalent")
    else
      survived=$((survived + 1))
      SURVIVOR_DETAILS+=("line=$line mutator=$mutator status=not-executed")
    fi
  done <<< "$(select_mutant_lines "$TARGET" "$MUTANTS" "$SEED")"

  KILLED=$killed
  SURVIVED=$survived
  EQUIVALENT=$equivalent
  EXECUTED=0
  EXEC_MODE="simulated"
  return 0
}

# ── Dispatch ────────────────────────────────────────────────────────────────

if [[ "$SIMULATE" -eq 1 ]]; then
  execute_simulate
else
  execute_real
  rc=$?
  [[ "$rc" -ne 0 ]] && exit $rc
fi

total=$((KILLED + SURVIVED + EQUIVALENT))
effective=$((KILLED + SURVIVED))
if [[ "$effective" -eq 0 ]]; then
  score=0
else
  score=$(( (KILLED * 100) / effective ))
fi

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
{"verdict":"$VERDICT","execution":"$EXEC_MODE","target":"$TARGET","tests":"$TESTS","language":"$LANG_ID","mutants_total":$total,"executed":$EXECUTED,"killed":$KILLED,"survived":$SURVIVED,"equivalent":$EQUIVALENT,"score_pct":$score,"threshold_pct":$THRESHOLD_PCT,"survivors":[$survivors_json]}
JSON
else
  echo "=== SE-035 Mutation Audit ==="
  echo ""
  echo "Target:     $TARGET"
  echo "Tests:      $TESTS"
  echo "Language:   $LANG_ID"
  echo "Mode:       $EXEC_MODE"
  [[ "$EXEC_MODE" == "simulated" ]] && echo "WARNING:    SIMULATION MODE — results are NOT from a real test run."
  echo "Mutants:    $total (killed=$KILLED, survived=$SURVIVED, equivalent=$EQUIVALENT, executed=$EXECUTED)"
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
