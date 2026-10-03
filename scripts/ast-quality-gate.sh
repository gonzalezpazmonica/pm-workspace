#!/usr/bin/env bash
# ast-quality-gate.sh — Language-agnostic code quality meta-analyzer
# Detects language, runs native linter + Semgrep, writes unified JSON report.
# Usage: bash scripts/ast-quality-gate.sh <target> [--semgrep-only|--native-only] [--advisory]
#
# Exit codes:
#   0  PASS / PASS_WITH_WARNINGS / REVIEW  (or any verdict with --advisory)
#   1  FAIL / BLOCK (score < 60 or an error in a blocking gate)
#   2  usage or environment error (target missing, bad flag, no jq) — no report
#   3  UNVERIFIED: no analysis layer could run (tool missing, crashed or unsupported)
#
# A layer that cannot run never counts as "no findings": it is recorded in
# meta.tool_chain with status missing|failed|unsupported and lowers meta.coverage.
# Env: AST_QG_OUTPUT_DIR (report dir), AST_QG_SEMGREP_RULES (rules file).
# Version: 2.0.0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RULES_FILE="${AST_QG_SEMGREP_RULES:-$ROOT_DIR/.claude/skills/ast-quality-gate/references/semgrep-rules.yaml}"
OUTPUT_DIR="${AST_QG_OUTPUT_DIR:-$ROOT_DIR/output/quality-gates}"
BLOCKING_GATES='["QG-01","QG-03","QG-05","QG-09","QG-12"]'

usage() { echo "Uso: ast-quality-gate.sh <target> [--semgrep-only|--native-only] [--advisory]" >&2; }
die() { echo "ast-quality-gate: $1" >&2; exit 2; }

TARGET="" SEMGREP_ONLY=false NATIVE_ONLY=false ADVISORY=false
for arg in "$@"; do
  case "$arg" in
    --semgrep-only) SEMGREP_ONLY=true ;;
    --native-only)  NATIVE_ONLY=true ;;
    --advisory)     ADVISORY=true ;;
    -h|--help)      usage; exit 0 ;;
    -*)             usage; die "flag desconocido: $arg" ;;
    *)              [[ -z "$TARGET" ]] || die "más de un target: $arg"; TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-.}"

command -v jq &>/dev/null || die "jq no está instalado; es imprescindible para normalizar resultados"
[[ "$SEMGREP_ONLY" == true && "$NATIVE_ONLY" == true ]] && die "--semgrep-only y --native-only son incompatibles"
[[ -e "$TARGET" ]] || die "el target no existe: $TARGET"

# Absolute target: the linters that need a project root run from WORK_DIR.
if [[ -d "$TARGET" ]]; then
  TARGET="$(cd "$TARGET" && pwd)"; WORK_DIR="$TARGET"
else
  WORK_DIR="$(cd "$(dirname "$TARGET")" && pwd)"; TARGET="$WORK_DIR/$(basename "$TARGET")"
fi

WORK_TMP="$(mktemp -d)"
trap 'rm -rf "$WORK_TMP"' EXIT
CHAIN="$WORK_TMP/chain.jsonl"
: > "$CHAIN"

# ── Language detection ────────────────────────────────────────────────────────

# Vendored code (node_modules) must not decide the project language.
has_file() {
  find "$1" -maxdepth 3 -name node_modules -prune -o \( "${@:2}" \) -print -quit 2>/dev/null | grep -q .
}

detect_language() {
  local t="$1"
  if [[ -f "$t" ]]; then
    case "$t" in
      *.cs|*.csproj|*.sln) echo "csharp" ;;
      *.vb|*.vbproj)       echo "vbnet" ;;
      *.ts|*.tsx)          echo "typescript" ;;
      *.js|*.jsx)          echo "javascript" ;;
      *.py)                echo "python" ;;
      *.go)                echo "go" ;;
      *.rs)                echo "rust" ;;
      *.java)              echo "java" ;;
      *.php)               echo "php" ;;
      *.swift)             echo "swift" ;;
      *.kt|*.kts)          echo "kotlin" ;;
      *.rb)                echo "ruby" ;;
      *.tf|*.tfvars)       echo "terraform" ;;
      *.dart)              echo "dart" ;;
      *.cob|*.cbl|*.cpy)   echo "cobol" ;;
      *)                   echo "unknown" ;;
    esac
    return
  fi
  if   has_file "$t" -name "*.csproj";                                   then echo "csharp"
  elif has_file "$t" -name "*.vbproj";                                   then echo "vbnet"
  elif has_file "$t" -name "angular.json";                               then echo "angular"
  elif has_file "$t" -name "tsconfig.json";                              then echo "typescript"
  elif has_file "$t" -name "pyproject.toml" -o -name "requirements.txt"; then echo "python"
  elif has_file "$t" -name "go.mod";                                     then echo "go"
  elif has_file "$t" -name "Cargo.toml";                                 then echo "rust"
  elif has_file "$t" -name "pom.xml" -o -name "build.gradle";            then echo "java"
  elif has_file "$t" -name "composer.json";                              then echo "php"
  elif has_file "$t" -name "Package.swift" -o -name "*.xcodeproj";       then echo "swift"
  elif has_file "$t" -name "build.gradle.kts";                           then echo "kotlin"
  elif has_file "$t" -name "Gemfile";                                    then echo "ruby"
  elif has_file "$t" -name "*.tf";                                       then echo "terraform"
  elif has_file "$t" -name "pubspec.yaml";                               then echo "dart"
  elif has_file "$t" -name "*.cob" -o -name "*.cbl";                     then echo "cobol"
  elif has_file "$t" -name "package.json";                               then echo "javascript"
  else echo "unknown"; fi
}

# ── Tool chain bookkeeping ────────────────────────────────────────────────────

record() { # layer tool status detail
  jq -cn --arg l "$1" --arg t "$2" --arg s "$3" --arg d "$4" \
    '{layer: $l, tool: $t, status: $s, detail: $d}' >> "$CHAIN"
}

# normalize <layer> <tool> <rc> <raw> <out> <jq-filter> [jq-flags...]
# The exit code is NOT taken as failure: linters exit 1 when they find issues.
# Success = the raw output parses into an array with the expected shape.
# Empty output is never "no findings": an analyser that ran always emits JSON.
normalize() {
  local layer="$1" tool="$2" rc="$3" raw="$4" out="$5" filter="$6"; shift 6
  if grep -q '[^[:space:]]' "$raw" 2>/dev/null && jq "$@" "$filter" "$raw" > "$out" 2>/dev/null && jq -e 'type == "array"' "$out" &>/dev/null; then
    record "$layer" "$tool" ok "exit $rc"
  else
    echo "[]" > "$out"
    local why; why="$(cat "$raw" "$raw.err" 2>/dev/null | tr -s '\n ' ' ' | head -c 200)"
    record "$layer" "$tool" failed "exit $rc; salida no interpretable: ${why:-(vacía)}"
  fi
}

# ── Native linter per language ────────────────────────────────────────────────

native_tool_for() {
  case "$1" in
    csharp|vbnet)                  echo "dotnet" ;;
    typescript|angular|javascript) echo "eslint" ;;
    python)    echo "ruff" ;;
    go)        echo "golangci-lint" ;;
    rust)      echo "cargo" ;;
    php)       echo "phpstan" ;;
    swift)     echo "swiftlint" ;;
    kotlin)    echo "detekt" ;;
    ruby)      echo "rubocop" ;;
    terraform) echo "tflint" ;;
    dart)      echo "dart" ;;
    *)         echo "" ;;
  esac
}

run_native_linter() {
  local lang="$1" target="$2" out="$3" raw="$WORK_TMP/native.raw" rc tool
  tool="$(native_tool_for "$lang")"
  echo "[]" > "$out"
  if [[ -z "$tool" ]]; then
    record native "$lang" unsupported "sin linter nativo integrado para '$lang'"
    return
  fi
  if ! command -v "$tool" &>/dev/null; then
    record native "$tool" missing "'$tool' no está en el PATH"
    return
  fi

  case "$lang" in
    csharp|vbnet)
      (cd "$WORK_DIR" && dotnet build --no-incremental) > "$raw" 2>&1; rc=$?
      grep -E '^.*\.(cs|vb)\([0-9]+,[0-9]+\): (error|warning) ' "$raw" > "$raw.diag"
      if [[ $rc -ne 0 && ! -s "$raw.diag" ]]; then
        record native dotnet failed "exit $rc sin diagnósticos: $(head -c 200 "$raw" | tr '\n' ' ')"
        return
      fi
      if [[ ! -s "$raw.diag" ]]; then    # clean build: exit 0 and nothing to report
        record native dotnet ok "exit 0, sin diagnósticos"
        return
      fi
      normalize native dotnet "$rc" "$raw.diag" "$out" \
        'split("\n") | map(select(length > 0) |
          capture("^(?<f>.*)\\((?<l>[0-9]+),(?<c>[0-9]+)\\): (?<s>error|warning) (?<id>[A-Z]+[0-9]+): ?(?<m>.*)$") |
          {source_tool: "dotnet-build", file: .f, line: (.l|tonumber), column: (.c|tonumber),
           message: .m, rule_id: .id, severity: .s})' -Rs
      ;;
    typescript|angular|javascript)
      (cd "$WORK_DIR" && eslint --format json "$target") > "$raw" 2>"$raw.err"; rc=$?
      normalize native eslint "$rc" "$raw" "$out" \
        '[.[] | .filePath as $f | .messages[] | {source_tool: "eslint", file: $f, line: .line,
          column: .column, message: .message, rule_id: .ruleId,
          severity: (if .severity == 2 then "error" else "warning" end), fixable: (.fix != null)}]'
      ;;
    python)
      ruff check --output-format json "$target" > "$raw" 2>"$raw.err"; rc=$?
      normalize native ruff "$rc" "$raw" "$out" \
        '[.[] | {source_tool: "ruff", file: .filename, line: .location.row, column: .location.column,
          message: .message, rule_id: .code, severity: "warning", fixable: (.fix != null)}]'
      ;;
    go)
      (cd "$WORK_DIR" && golangci-lint run --out-format json ./...) > "$raw" 2>"$raw.err"; rc=$?
      normalize native golangci-lint "$rc" "$raw" "$out" \
        '[(.Issues // [])[] | {source_tool: "golangci-lint", file: .Pos.Filename, line: .Pos.Line,
          message: .Text, rule_id: .FromLinter,
          severity: (if .Severity == "error" then "error" else "warning" end)}]'
      ;;
    rust)
      (cd "$WORK_DIR" && cargo clippy --message-format json) > "$raw" 2>"$raw.err"; rc=$?
      # Without clippy, or with a broken manifest, cargo exits non-zero before compiling.
      if [[ $rc -ne 0 ]] && ! grep -q '"reason":"compiler-message"' "$raw"; then
        record native cargo failed "exit $rc sin diagnósticos: $(tr -s '\n ' ' ' < "$raw.err" | head -c 200)"
        return
      fi
      normalize native cargo "$rc" "$raw" "$out" \
        '[.[] | select(.reason == "compiler-message") | .message | select(.level != "note") | {
          source_tool: "cargo-clippy", file: (.spans[0].file_name // "unknown"),
          line: (.spans[0].line_start // 0), message: .message, rule_id: (.code.code // ""),
          severity: (if .level == "error" then "error" else "warning" end)}]' -s
      ;;
    php)
      phpstan analyse --error-format=json --no-progress "$target" > "$raw" 2>"$raw.err"; rc=$?
      normalize native phpstan "$rc" "$raw" "$out" \
        '[.files | to_entries[] | .key as $f | .value.messages[] | {source_tool: "phpstan", file: $f,
          line: .line, message: .message, severity: (if .ignorable then "warning" else "error" end)}]'
      ;;
    swift)
      swiftlint lint --reporter json "$target" > "$raw" 2>"$raw.err"; rc=$?
      normalize native swiftlint "$rc" "$raw" "$out" \
        '[.[] | {source_tool: "swiftlint", file: .file, line: .line, message: .reason,
          rule_id: .rule_id, severity: (.severity | ascii_downcase)}]'
      ;;
    kotlin)
      detekt --input "$target" --report "sarif:$WORK_TMP/detekt.sarif" > "$raw" 2>&1; rc=$?
      [[ -f "$WORK_TMP/detekt.sarif" ]] && raw="$WORK_TMP/detekt.sarif"
      normalize native detekt "$rc" "$raw" "$out" \
        '[.runs[].results[] | {source_tool: "detekt",
          file: (.locations[0].physicalLocation.artifactLocation.uri // ""),
          line: (.locations[0].physicalLocation.region.startLine // 0), message: .message.text,
          rule_id: .ruleId, severity: (if .level == "error" then "error" else "warning" end)}]'
      ;;
    ruby)
      rubocop --format json "$target" > "$raw" 2>"$raw.err"; rc=$?
      normalize native rubocop "$rc" "$raw" "$out" \
        '[.files[] | .path as $f | .offenses[] | {source_tool: "rubocop", file: $f,
          line: .location.start_line, message: .message, rule_id: .cop_name,
          severity: (if .severity == "error" or .severity == "fatal" then "error"
                     elif .severity == "warning" then "warning" else "info" end),
          fixable: .corrected}]'
      ;;
    terraform)
      (cd "$WORK_DIR" && tflint --format json) > "$raw" 2>"$raw.err"; rc=$?
      normalize native tflint "$rc" "$raw" "$out" \
        '[.issues[] | {source_tool: "tflint", file: .range.filename, line: .range.start.line,
          message: .message, rule_id: .rule.name,
          severity: (.rule.severity | ascii_downcase | if . == "notice" then "info" else . end)}]'
      ;;
    dart)
      dart analyze --format=json "$target" > "$raw" 2>"$raw.err"; rc=$?
      normalize native dart "$rc" "$raw" "$out" \
        '[.diagnostics[] | {source_tool: "dart-analyze", file: .location.file,
          line: .location.range.start.line, message: .problemMessage, rule_id: .code,
          severity: (.severity | ascii_downcase)}]'
      ;;
  esac
}

# ── Semgrep ───────────────────────────────────────────────────────────────────

run_semgrep() {
  local target="$1" out="$2" raw="$WORK_TMP/semgrep.raw" rc
  echo "[]" > "$out"
  if ! command -v semgrep &>/dev/null; then
    record semgrep semgrep missing "'semgrep' no está en el PATH (pip install semgrep)"
    return
  fi
  if [[ ! -f "$RULES_FILE" ]]; then
    record semgrep semgrep failed "fichero de reglas no encontrado: $RULES_FILE"
    return
  fi
  # A clean semgrep run over a language no rule targets is not an analysis.
  local sg_lang="$DETECTED_LANG"
  [[ "$sg_lang" == "angular" ]] && sg_lang="typescript"
  if [[ "$sg_lang" != "unknown" ]] &&
     ! grep -E '^[[:space:]]*languages:' "$RULES_FILE" | grep -qE "[[ ,]${sg_lang}[],]"; then
    record semgrep semgrep unsupported "ninguna regla de $(basename "$RULES_FILE") cubre '$DETECTED_LANG'"
    return
  fi
  semgrep --config "$RULES_FILE" --json --no-git-ignore --quiet "$target" > "$raw" 2>"$raw.err"; rc=$?
  # Exit >= 2 or error-level entries in .errors (invalid rule, crash): the scan did not happen,
  # even if an empty .results is present. Warning-level entries (skipped files) are tolerated.
  local sg_err
  sg_err="$(jq -r '[.errors[]? | select(.level == "error") | (.message // .type // "error")] | first // empty' "$raw" 2>/dev/null)"
  if [[ $rc -ge 2 || -n "$sg_err" ]]; then
    record semgrep semgrep failed "exit $rc; ${sg_err:-$(tr -s '\n ' ' ' < "$raw.err" | head -c 200)}"
    return
  fi
  normalize semgrep semgrep "$rc" "$raw" "$out" \
    '[.results[] | {source_tool: "semgrep", gate: (.extra.metadata.gate // null), file: .path,
      line: .start.line, column: .start.col, message: .extra.message, rule_id: .check_id,
      severity: (if .extra.severity == "ERROR" then "error"
                 elif .extra.severity == "WARNING" then "warning" else "info" end),
      fixable: (.extra.fix != null), snippet: .extra.lines}]'
}

# ── Report: gate assignment, coverage, score, verdict ─────────────────────────
# Native findings get a gate from their rule id (semgrep rules carry their own).
# An error in a blocking gate forces BLOCK whatever the score.

REPORT_FILTER='
def gate_for($id):
  ($id // "" | ascii_downcase) as $r |
  if   $r | test("no-floating|no-misused-promises|async.*void") then "QG-01"
  elif $r | test("no-await-in-loop") then "QG-02"
  elif $r | test("no-non-null|strict-null|ts2531|ts2532") then "QG-03"
  elif $r | test("no-magic|plr2004") then "QG-04"
  elif $r | test("empty-catch|no-empty.*catch|broad-exception|^e722$|^ble001$") then "QG-05"
  elif $r | test("complexity|cognitive") then "QG-06"
  elif $r | test("max-lines|function-length") then "QG-07"
  elif $r | test("duplication|clone") then "QG-08"
  elif $r | test("secret|credential|password|token|apikey|^s10[5-7]$") then "QG-09"
  elif $r | test("console|print|^t201$|debug.*log") then "QG-10"
  elif $r | test("unused|^f401$") then "QG-11"
  else null end;
def grade: if . >= 90 then "A" elif . >= 75 then "B" elif . >= 60 then "C" elif . >= 40 then "D" else "F" end;
def verdict: if . >= 90 then "PASS" elif . >= 75 then "PASS_WITH_WARNINGS" elif . >= 60 then "REVIEW"
             elif . >= 40 then "FAIL" else "BLOCK" end;
($native[0] + $semgrep[0] | map(.gate = (.gate // gate_for(.rule_id)))) as $issues |
([$chain[] | select(.status == "ok")] | length) as $ok |
(if $ok == 0 then "none" elif $ok == ($chain | length) then "full" else "partial" end) as $cov |
([$issues[] | select(.severity == "error")] | length) as $e |
([$issues[] | select(.severity == "warning")] | length) as $w |
([$issues[] | select(.severity == "info")] | length) as $i |
([100 - ($e * 10 + $w * 3 + $i), 0] | max) as $score |
([$issues[] | select(.severity == "error" and (.gate as $g | $blocking | index($g))) | .gate] | unique) as $bg |
{
  meta: {timestamp: $ts, language: $lang, target: $target, files_analyzed: $files,
         coverage: $cov, tool_chain: $chain},
  score: (if $cov == "none" then {total: null, grade: null, verdict: "UNVERIFIED", blocking_gates: []}
          else {total: $score, grade: ($score | grade),
                verdict: (if ($bg | length) > 0 then "BLOCK" else ($score | verdict) end),
                blocking_gates: $bg} end),
  issues: $issues,
  summary: {errors: $e, warnings: $w, infos: $i, fixable: ([$issues[] | select(.fixable == true)] | length)}
}'

# ── Main ──────────────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AST Quality Gate — ${TARGET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Not "LANG": that is the locale every linter inherits.
DETECTED_LANG="$(detect_language "$TARGET")"
echo "Lenguaje detectado: ${DETECTED_LANG}"

NATIVE_JSON="$WORK_TMP/native.json"
SEMGREP_JSON="$WORK_TMP/semgrep.json"
echo "[]" > "$NATIVE_JSON"
echo "[]" > "$SEMGREP_JSON"

if [[ "$SEMGREP_ONLY" == false ]]; then
  echo "Ejecutando herramienta nativa..."
  run_native_linter "$DETECTED_LANG" "$TARGET" "$NATIVE_JSON"
fi
if [[ "$NATIVE_ONLY" == false ]]; then
  echo "Ejecutando Semgrep..."
  run_semgrep "$TARGET" "$SEMGREP_JSON"
fi

mkdir -p "$OUTPUT_DIR" || die "no se puede crear $OUTPUT_DIR"
# PID + RANDOM: two runs in the same second must not overwrite each other.
OUTPUT_FILE="$OUTPUT_DIR/$(date +%Y%m%d-%H%M%S)-${DETECTED_LANG}-$$-${RANDOM}.json"
FILES_COUNT=$(find "$TARGET" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')

jq -n \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg lang "$DETECTED_LANG" \
  --arg target "$TARGET" \
  --argjson files "$FILES_COUNT" \
  --argjson blocking "$BLOCKING_GATES" \
  --slurpfile chain "$CHAIN" \
  --slurpfile native "$NATIVE_JSON" \
  --slurpfile semgrep "$SEMGREP_JSON" \
  "$REPORT_FILTER" > "$OUTPUT_FILE" || die "no se pudo generar el informe JSON"

VERDICT=$(jq -r '.score.verdict' "$OUTPUT_FILE")
COVERAGE=$(jq -r '.meta.coverage' "$OUTPUT_FILE")

echo ""
jq -r '.meta.tool_chain[] | select(.status != "ok") | "AVISO \(.layer)/\(.tool): \(.status) — \(.detail)"' "$OUTPUT_FILE" >&2
if [[ "$VERDICT" == "UNVERIFIED" ]]; then
  echo "Veredicto: UNVERIFIED — ninguna capa de análisis pudo ejecutarse; el código NO está verificado."
else
  jq -r '.score | "Score: \(.total)/100 (\(.grade)) — \(.verdict)" +
    (if (.blocking_gates | length) > 0 then " [gates bloqueantes: \(.blocking_gates | join(", "))]" else "" end)' "$OUTPUT_FILE"
  if [[ "$COVERAGE" == "partial" ]]; then
    echo "Cobertura parcial: alguna capa no se ejecutó (ver AVISO); el score solo refleja las capas que corrieron."
  fi
  echo ""
  jq -r '.issues[] | select(.severity != "info") |
    "\(.gate // "??") [\(.severity)] \(.file // ""):\(.line // 0) — \(.message)"' "$OUTPUT_FILE" | head -20
fi

echo ""
echo "Detalle: ${OUTPUT_FILE}"

[[ "$ADVISORY" == true ]] && exit 0
case "$VERDICT" in
  PASS|PASS_WITH_WARNINGS|REVIEW) exit 0 ;;
  FAIL|BLOCK)                     exit 1 ;;
  *)                              exit 3 ;;
esac
