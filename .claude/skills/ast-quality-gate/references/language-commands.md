# CLI Commands per Language — AST Quality Gate

## Comandos nativos por lenguaje

| Lenguaje | Comando de análisis | Output format | Instalación |
|----------|---------------------|---------------|-------------|
| C# / VB.NET | `dotnet build --no-incremental 2>&1` | MSBuild text | `dotnet SDK` |
| TypeScript / Angular / React | `eslint --format json <target>` | ESLint JSON | `npm install -g eslint @typescript-eslint/parser` |
| JavaScript | `eslint --format json <target>` | ESLint JSON | `npm install -g eslint` |
| Python | `ruff check --output-format json <target>` | Ruff JSON | `pip install ruff` |
| Go | `golangci-lint run --out-format json ./...` | golangci JSON | `brew install golangci-lint` |
| Rust | `cargo clippy --message-format json 2>&1` | Cargo JSON | Incluido en Rust toolchain |
| PHP | `phpstan analyse --error-format=json <target>` | PHPStan JSON | `composer global require phpstan/phpstan` |
| Swift | `swiftlint lint --reporter json <target>` | SwiftLint JSON | `brew install swiftlint` |
| Kotlin | `detekt --report sarif:detekt.sarif <target>` | SARIF | `brew install detekt` |
| Ruby | `rubocop --format json <target>` | RuboCop JSON | `gem install rubocop` |
| Java | `mvn -q spotbugs:check -Dspotbugs.xmlOutput=true` | SpotBugs XML | Maven + SpotBugs plugin |
| Dart / Flutter | `dart analyze --format=json <target>` | Dart JSON | Incluido en Dart SDK |
| Terraform | `tflint --format json <dir>` | TFLint JSON | `brew install tflint` |
| COBOL | `proleap-cobol-parser <target>` | ProLeap JSON | Ver docs ProLeap |

## Semgrep (universal, todos los lenguajes)

```bash
semgrep \
  --config .claude/skills/ast-quality-gate/references/semgrep-rules.yaml \
  --json \
  --no-git-ignore \
  "$TARGET"
```

Requisito: `pip install semgrep` (≥ 1.60.0)

## Verificar disponibilidad de herramientas

```bash
# Verificar herramientas instaladas
command -v dotnet && dotnet --version
command -v eslint && eslint --version
command -v ruff && ruff --version
command -v golangci-lint && golangci-lint --version
command -v cargo && cargo --version
command -v phpstan && phpstan --version
command -v swiftlint && swiftlint --version
command -v detekt && detekt --version
command -v rubocop && rubocop --version
command -v mvn && mvn --version
command -v dart && dart --version
command -v tflint && tflint --version
command -v semgrep && semgrep --version
command -v jq && jq --version
```

## Flags del script ast-quality-gate.sh

| Flag | Descripción |
|------|-------------|
| (ninguno) | Análisis completo: herramienta nativa + Semgrep |
| `--semgrep-only` | Solo Semgrep (multi-lenguaje, rápido, ~5s) |
| `--native-only` | Solo herramienta nativa (preciso, lento) |
| `--advisory` | Sin bloqueo — solo informe (exit 0 siempre) |

## Normalización de outputs nativos

### MSBuild (C#) → Unified

```bash
# Extraer errores y warnings de dotnet build
dotnet build --no-incremental 2>&1 | \
  grep -E "error|warning" | \
  awk '{...}' | \
  jq '[...]'
```

### ESLint JSON → Unified

```bash
jq '[.[] | .messages[] | {
  gate: (if .ruleId | test("no-magic") then "QG-04"
         elif .ruleId | test("max-lines") then "QG-07"
         elif .ruleId | test("empty-catch|no-empty") then "QG-05"
         else "QG-11" end),
  severity: (if .severity == 2 then "error" else "warning" end),
  file: .filePath,
  line: .line,
  column: .column,
  message: .message,
  source_tool: "eslint",
  rule_id: .ruleId,
  fixable: (.fix != null)
}]' eslint-output.json
```

### Ruff JSON → Unified

```bash
jq '[.[] | {
  gate: (if .code | test("^B006|^B007") then "QG-05"
         elif .code | test("^F401") then "QG-11"
         elif .code | test("^PLR2004") then "QG-04"
         else "QG-11" end),
  severity: "warning",
  file: .filename,
  line: .location.row,
  column: .location.column,
  message: .message,
  source_tool: "ruff",
  rule_id: .code,
  fixable: (.fix != null)
}]' ruff-output.json
```

### golangci-lint JSON → Unified

```bash
jq '[.Issues[] | {
  gate: (if .FromLinter | test("errcheck|govet") then "QG-03"
         elif .FromLinter | test("noctx|bodyclose") then "QG-01"
         else "QG-11" end),
  severity: (if .Severity == "error" then "error" else "warning" end),
  file: .Pos.Filename,
  line: .Pos.Line,
  column: .Pos.Column,
  message: .Text,
  source_tool: "golangci-lint",
  rule_id: .FromLinter,
  fixable: false
}]' golangci-output.json
```

### Cargo clippy JSON → Unified

```bash
jq '[select(.reason == "compiler-message") |
  .message | select(.level == "warning" or .level == "error") | {
    gate: (if .code.code | test("clippy::await_holding") then "QG-01"
           elif .code.code | test("clippy::unwrap_used") then "QG-03"
           else "QG-11" end),
    severity: .level,
    file: (.spans[0].file_name // ""),
    line: (.spans[0].line_start // 0),
    message: .message,
    source_tool: "cargo-clippy",
    rule_id: (.code.code // ""),
    fixable: (.children | length > 0)
}]' cargo-output.json
```

### SARIF (Kotlin detekt) → Unified

```bash
jq '[.runs[].results[] | {
  gate: (if .ruleId | test("EmptyCatchBlock") then "QG-05"
         elif .ruleId | test("MagicNumber") then "QG-04"
         elif .ruleId | test("LongMethod|LongFunction") then "QG-07"
         else "QG-11" end),
  severity: (if .level == "error" then "error" else "warning" end),
  file: (.locations[0].physicalLocation.artifactLocation.uri // ""),
  line: (.locations[0].physicalLocation.region.startLine // 0),
  message: .message.text,
  source_tool: "detekt",
  rule_id: .ruleId,
  fixable: false
}]' detekt.sarif
```

### Semgrep JSON → Unified

```bash
jq '[.results[] | {
  gate: .extra.metadata.gate,
  severity: (if .extra.severity == "ERROR" then "error"
             elif .extra.severity == "WARNING" then "warning"
             else "info" end),
  file: .path,
  line: .start.line,
  column: .start.col,
  message: .extra.message,
  source_tool: "semgrep",
  rule_id: .check_id,
  fixable: (.extra.fix != null)
}]' semgrep-output.json
```
