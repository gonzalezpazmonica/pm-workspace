#!/usr/bin/env bash
# ast-quality-gate.sh — Language-agnostic code quality meta-analyzer
# Detects language, runs native linter + Semgrep, outputs unified JSON
# Usage: bash scripts/ast-quality-gate.sh <target> [--semgrep-only] [--native-only] [--advisory]
# Version: 1.0.0

set -uo pipefail

TARGET="${1:-.}"
SEMGREP_ONLY=false
NATIVE_ONLY=false
ADVISORY=false
SKILL_DIR="$(dirname "${BASH_SOURCE[0]}")/../.claude/skills/ast-quality-gate"
OUTPUT_DIR="$(dirname "${BASH_SOURCE[0]}")/../output/quality-gates"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Parse flags
for arg in "${@:2}"; do
  case "$arg" in
    --semgrep-only) SEMGREP_ONLY=true ;;
    --native-only)  NATIVE_ONLY=true ;;
    --advisory)     ADVISORY=true ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# ── Language detection ────────────────────────────────────────────────────────

detect_language() {
  local dir="$1"
  # Check for file if target is a single file
  if [[ -f "$dir" ]]; then
    case "$dir" in
      *.cs|*.csproj|*.sln) echo "csharp"; return ;;
      *.vb|*.vbproj)       echo "vbnet"; return ;;
      *.ts|*.tsx)          echo "typescript"; return ;;
      *.js|*.jsx)          echo "javascript"; return ;;
      *.py)                echo "python"; return ;;
      *.go)                echo "go"; return ;;
      *.rs)                echo "rust"; return ;;
      *.java)              echo "java"; return ;;
      *.php)               echo "php"; return ;;
      *.swift)             echo "swift"; return ;;
      *.kt|*.kts)          echo "kotlin"; return ;;
      *.rb)                echo "ruby"; return ;;
      *.tf|*.tfvars)       echo "terraform"; return ;;
      *.dart)              echo "dart"; return ;;
      *.cob|*.cbl|*.cpy)   echo "cobol"; return ;;
    esac
  fi
  # Directory detection by project files
  if find "$dir" -maxdepth 3 -name "*.csproj" 2>/dev/null | head -1 | grep -q .; then echo "csharp"; return; fi
  if find "$dir" -maxdepth 3 -name "*.vbproj" 2>/dev/null | head -1 | grep -q .; then echo "vbnet"; return; fi
  if find "$dir" -maxdepth 3 -name "angular.json" 2>/dev/null | head -1 | grep -q .; then echo "angular"; return; fi
  if find "$dir" -maxdepth 3 -name "tsconfig.json" 2>/dev/null | head -1 | grep -q .; then echo "typescript"; return; fi
  if find "$dir" -maxdepth 3 -name "pyproject.toml" -o -name "requirements.txt" 2>/dev/null | head -1 | grep -q .; then echo "python"; return; fi
  if find "$dir" -maxdepth 3 -name "go.mod" 2>/dev/null | head -1 | grep -q .; then echo "go"; return; fi
  if find "$dir" -maxdepth 3 -name "Cargo.toml" 2>/dev/null | head -1 | grep -q .; then echo "rust"; return; fi
  if find "$dir" -maxdepth 3 -name "pom.xml" -o -name "build.gradle" 2>/dev/null | head -1 | grep -q .; then echo "java"; return; fi
  if find "$dir" -maxdepth 3 -name "composer.json" 2>/dev/null | head -1 | grep -q .; then echo "php"; return; fi
  if find "$dir" -maxdepth 3 -name "Package.swift" -o -name "*.xcodeproj" 2>/dev/null | head -1 | grep -q .; then echo "swift"; return; fi
  if find "$dir" -maxdepth 3 -name "build.gradle.kts" 2>/dev/null | head -1 | grep -q .; then echo "kotlin"; return; fi
  if find "$dir" -maxdepth 3 -name "Gemfile" 2>/dev/null | head -1 | grep -q .; then echo "ruby"; return; fi
  if find "$dir" -maxdepth 3 -name "main.tf" -o -name "*.tf" 2>/dev/null | head -1 | grep -q .; then echo "terraform"; return; fi
  if find "$dir" -maxdepth 3 -name "pubspec.yaml" 2>/dev/null | head -1 | grep -q .; then echo "dart"; return; fi
  if find "$dir" -maxdepth 3 -name "*.cob" -o -name "*.cbl" 2>/dev/null | head -1 | grep -q .; then echo "cobol"; return; fi
  echo "unknown"
}

# ── Native linter per language ────────────────────────────────────────────────

run_native_linter() {
  local lang="$1"
  local target="$2"
  local out_file="$3"

  case "$lang" in
    csharp|vbnet)
      if command -v dotnet &>/dev/null; then
        dotnet build --no-incremental 2>&1 | \
          grep -E "^.*\.(cs|vb)\([0-9]+,[0-9]+\):" | \
          jq -Rs 'split("\n") | map(select(length > 0)) |
            map({
              source_tool: "dotnet-build",
              file: (capture("^(?<f>[^(]+)").f),
              message: .,
              severity: (if test("error") then "error" elif test("warning") then "warning" else "info" end)
            })' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    typescript|angular|javascript)
      if command -v eslint &>/dev/null; then
        eslint --format json "$target" 2>/dev/null | \
          jq '[.[] | .messages[] | {
            source_tool: "eslint",
            file: .filePath,
            line: .line,
            column: .column,
            message: .message,
            rule_id: .ruleId,
            severity: (if .severity == 2 then "error" else "warning" end),
            fixable: (.fix != null)
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    python)
      if command -v ruff &>/dev/null; then
        ruff check --output-format json "$target" 2>/dev/null | \
          jq '[.[] | {
            source_tool: "ruff",
            file: .filename,
            line: .location.row,
            column: .location.column,
            message: .message,
            rule_id: .code,
            severity: "warning",
            fixable: (.fix != null)
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    go)
      if command -v golangci-lint &>/dev/null; then
        golangci-lint run --out-format json "$target/..." 2>/dev/null | \
          jq '[.Issues[] | {
            source_tool: "golangci-lint",
            file: .Pos.Filename,
            line: .Pos.Line,
            message: .Text,
            rule_id: .FromLinter,
            severity: (if .Severity == "error" then "error" else "warning" end)
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    rust)
      if command -v cargo &>/dev/null; then
        cargo clippy --message-format json 2>/dev/null | \
          jq -s '[.[] | select(.reason == "compiler-message") |
            .message | select(.level != "note") | {
              source_tool: "cargo-clippy",
              file: (.spans[0].file_name // "unknown"),
              line: (.spans[0].line_start // 0),
              message: .message,
              rule_id: (.code.code // ""),
              severity: (if .level == "error" then "error" else "warning" end)
            }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    php)
      if command -v phpstan &>/dev/null; then
        phpstan analyse --error-format=json "$target" 2>/dev/null | \
          jq '[.files | to_entries[] | .key as $f | .value.messages[] | {
            source_tool: "phpstan",
            file: $f,
            line: .line,
            message: .message,
            severity: (if .ignorable then "warning" else "error" end)
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    swift)
      if command -v swiftlint &>/dev/null; then
        swiftlint lint --reporter json "$target" 2>/dev/null | \
          jq '[.[] | {
            source_tool: "swiftlint",
            file: .file,
            line: .line,
            message: .reason,
            rule_id: .rule_id,
            severity: .severity
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    kotlin)
      if command -v detekt &>/dev/null; then
        detekt --report sarif:detekt.sarif.tmp "$target" 2>/dev/null
        if [[ -f detekt.sarif.tmp ]]; then
          jq '[.runs[].results[] | {
            source_tool: "detekt",
            file: (.locations[0].physicalLocation.artifactLocation.uri // ""),
            line: (.locations[0].physicalLocation.region.startLine // 0),
            message: .message.text,
            rule_id: .ruleId,
            severity: (if .level == "error" then "error" else "warning" end)
          }]' detekt.sarif.tmp > "$out_file" 2>/dev/null && rm -f detekt.sarif.tmp
        else
          echo "[]" > "$out_file"
        fi
      else
        echo "[]" > "$out_file"
      fi
      ;;
    ruby)
      if command -v rubocop &>/dev/null; then
        rubocop --format json "$target" 2>/dev/null | \
          jq '[.files[] | .path as $f | .offenses[] | {
            source_tool: "rubocop",
            file: $f,
            line: .location.start_line,
            message: .message,
            rule_id: .cop_name,
            severity: (if .severity == "error" or .severity == "fatal" then "error"
                      elif .severity == "warning" then "warning" else "info" end),
            fixable: (.corrected)
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    terraform)
      if command -v tflint &>/dev/null; then
        tflint --format json "$target" 2>/dev/null | \
          jq '[.issues[] | {
            source_tool: "tflint",
            file: .range.filename,
            line: .range.start.line,
            message: .message,
            rule_id: .rule.name,
            severity: .rule.severity
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    dart)
      if command -v dart &>/dev/null; then
        dart analyze --format=json "$target" 2>/dev/null | \
          jq '[.diagnostics[] | {
            source_tool: "dart-analyze",
            file: .location.file,
            line: .location.range.start.line,
            message: .problemMessage,
            rule_id: .code,
            severity: (.severity | ascii_downcase)
          }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
      else
        echo "[]" > "$out_file"
      fi
      ;;
    *)
      echo "[]" > "$out_file"
      ;;
  esac
}

# ── Gate assignment from rule_id ──────────────────────────────────────────────

assign_gate() {
  local rule_id="$1"
  case "$rule_id" in
    *async*void*|*no-floating*|*@typescript-eslint/no-misused-promises*) echo "QG-01" ;;
    *no-await-in-loop*) echo "QG-02" ;;
    *no-non-null*|*strict-null*|*ts2531*|*ts2532*) echo "QG-03" ;;
    *no-magic*|*PLR2004*) echo "QG-04" ;;
    *no-empty*catch*|*empty-catch*|*broad-exception*) echo "QG-05" ;;
    *complexity*|*cognitive*) echo "QG-06" ;;
    *max-lines*|*function-length*) echo "QG-07" ;;
    *duplication*|*clone*) echo "QG-08" ;;
    *secret*|*credential*|*password*|*token*|*apikey*) echo "QG-09" ;;
    *console.log*|*print*|*debug*log*) echo "QG-10" ;;
    *no-unused*|*F401*|*unused-import*) echo "QG-11" ;;
    *) echo "QG-11" ;;
  esac
}

# ── Semgrep run ───────────────────────────────────────────────────────────────

run_semgrep() {
  local target="$1"
  local out_file="$2"

  if ! command -v semgrep &>/dev/null; then
    echo "[]" > "$out_file"
    echo "⚠️  semgrep not installed (pip install semgrep). Skipping Semgrep layer." >&2
    return
  fi

  local rules_file="$SKILL_DIR/references/semgrep-rules.yaml"
  if [[ ! -f "$rules_file" ]]; then
    echo "[]" > "$out_file"
    return
  fi

  semgrep --config "$rules_file" \
          --json \
          --no-git-ignore \
          --quiet \
          "$target" 2>/dev/null | \
    jq '[.results[] | {
      source_tool: "semgrep",
      gate: (.extra.metadata.gate // "QG-11"),
      file: .path,
      line: .start.line,
      column: .start.col,
      message: .extra.message,
      rule_id: .check_id,
      severity: (if .extra.severity == "ERROR" then "error"
                elif .extra.severity == "WARNING" then "warning"
                else "info" end),
      fixable: (.extra.fix != null),
      snippet: .extra.lines
    }]' > "$out_file" 2>/dev/null || echo "[]" > "$out_file"
}

# ── Score computation ─────────────────────────────────────────────────────────

compute_score() {
  local combined_json="$1"
  local errors warnings infos

  errors=$(jq '[.[] | select(.severity == "error")] | length' "$combined_json")
  warnings=$(jq '[.[] | select(.severity == "warning")] | length' "$combined_json")
  infos=$(jq '[.[] | select(.severity == "info")] | length' "$combined_json")

  local penalty=$(( errors * 10 + warnings * 3 + infos * 1 ))
  if [[ $penalty -gt 100 ]]; then penalty=100; fi
  echo $(( 100 - penalty ))
}

grade_from_score() {
  local score=$1
  if [[ $score -ge 90 ]]; then echo "A"
  elif [[ $score -ge 75 ]]; then echo "B"
  elif [[ $score -ge 60 ]]; then echo "C"
  elif [[ $score -ge 40 ]]; then echo "D"
  else echo "F"; fi
}

verdict_from_score() {
  local score=$1
  if [[ $score -ge 90 ]]; then echo "PASS"
  elif [[ $score -ge 75 ]]; then echo "PASS_WITH_WARNINGS"
  elif [[ $score -ge 60 ]]; then echo "REVIEW"
  elif [[ $score -ge 40 ]]; then echo "FAIL"
  else echo "BLOCK"; fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 AST Quality Gate — ${TARGET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LANG=$(detect_language "$TARGET")
echo "Lenguaje detectado: ${LANG}"

NATIVE_TMP=$(mktemp /tmp/ast-native-XXXXXX.json)
SEMGREP_TMP=$(mktemp /tmp/ast-semgrep-XXXXXX.json)
COMBINED_TMP=$(mktemp /tmp/ast-combined-XXXXXX.json)

# Run layers
if [[ "$SEMGREP_ONLY" == "false" ]]; then
  echo "Ejecutando herramienta nativa..."
  run_native_linter "$LANG" "$TARGET" "$NATIVE_TMP"
fi

if [[ "$NATIVE_ONLY" == "false" ]]; then
  echo "Ejecutando Semgrep..."
  run_semgrep "$TARGET" "$SEMGREP_TMP"
fi

# Combine results
if [[ "$SEMGREP_ONLY" == "true" ]]; then
  cp "$SEMGREP_TMP" "$COMBINED_TMP"
elif [[ "$NATIVE_ONLY" == "true" ]]; then
  cp "$NATIVE_TMP" "$COMBINED_TMP"
else
  jq -s 'add' "$NATIVE_TMP" "$SEMGREP_TMP" > "$COMBINED_TMP"
fi

# Compute score
SCORE=$(compute_score "$COMBINED_TMP")
GRADE=$(grade_from_score "$SCORE")
VERDICT=$(verdict_from_score "$SCORE")

ERRORS=$(jq '[.[] | select(.severity == "error")] | length' "$COMBINED_TMP")
WARNINGS=$(jq '[.[] | select(.severity == "warning")] | length' "$COMBINED_TMP")
INFOS=$(jq '[.[] | select(.severity == "info")] | length' "$COMBINED_TMP")

# Build unified output
OUTPUT_FILE="${OUTPUT_DIR}/${TIMESTAMP}-${LANG}.json"
FILES_COUNT=$(find "$TARGET" -type f -name "*.[a-z]*" 2>/dev/null | wc -l | tr -d ' ')

jq -n \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg lang "$LANG" \
  --arg target "$TARGET" \
  --argjson files "$FILES_COUNT" \
  --argjson score "$SCORE" \
  --arg grade "$GRADE" \
  --arg verdict "$VERDICT" \
  --slurpfile issues "$COMBINED_TMP" \
  --argjson errors "$ERRORS" \
  --argjson warnings "$WARNINGS" \
  --argjson infos "$INFOS" \
  '{
    meta: {
      timestamp: $ts,
      language: $lang,
      target: $target,
      files_analyzed: $files,
      tool_chain: []
    },
    score: {
      total: $score,
      grade: $grade,
      verdict: $verdict
    },
    issues: ($issues[0] // []),
    summary: {
      errors: $errors,
      warnings: $warnings,
      infos: $infos,
      fixable: ([$issues[0][] | select(.fixable == true)] | length)
    }
  }' > "$OUTPUT_FILE"

# Print report
echo ""
echo "Score: ${SCORE}/100 (${GRADE}) — ${VERDICT}"
echo ""

if [[ $ERRORS -gt 0 ]]; then
  jq -r '.issues[] | select(.severity == "error") |
    "🔴 \(.gate // "??") [error] \(.file // ""):\(.line // 0) — \(.message)"' "$OUTPUT_FILE" | head -10
fi

if [[ $WARNINGS -gt 0 ]]; then
  jq -r '.issues[] | select(.severity == "warning") |
    "🟡 \(.gate // "??") [warning] \(.file // ""):\(.line // 0) — \(.message)"' "$OUTPUT_FILE" | head -10
fi

echo ""
echo "📄 Detalle: ${OUTPUT_FILE}"

# Cleanup
rm -f "$NATIVE_TMP" "$SEMGREP_TMP" "$COMBINED_TMP"

# Exit code
if [[ "$ADVISORY" == "true" ]]; then
  exit 0
fi

case "$VERDICT" in
  PASS|PASS_WITH_WARNINGS) exit 0 ;;
  REVIEW)                  exit 0 ;;
  FAIL|BLOCK)              exit 1 ;;
esac
