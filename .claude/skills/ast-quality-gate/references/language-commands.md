# CLI Commands per Language — AST Quality Gate

## Comandos nativos por lenguaje

| Lenguaje | Comando de análisis | Output format | Instalación |
|----------|---------------------|---------------|-------------|
| C# / VB.NET | `dotnet build --no-incremental 2>&1` (cwd = proyecto) | MSBuild text | `dotnet SDK` |
| TypeScript / Angular / React | `eslint --format json <target>` (cwd = proyecto) | ESLint JSON | `npm install -g eslint @typescript-eslint/parser` |
| JavaScript (`package.json` sin `tsconfig.json`) | `eslint --format json <target>` (cwd = proyecto) | ESLint JSON | `npm install -g eslint` |
| Python | `ruff check --output-format json <target>` | Ruff JSON | `pip install ruff` |
| Go | `golangci-lint run --out-format json ./...` (cwd = proyecto; flag de v1) | golangci JSON | `brew install golangci-lint` |
| Rust | `cargo clippy --message-format json` (cwd = proyecto) | Cargo JSON | Incluido en Rust toolchain |
| PHP | `phpstan analyse --error-format=json --no-progress <target>` | PHPStan JSON | `composer global require phpstan/phpstan` |
| Swift | `swiftlint lint --reporter json <target>` | SwiftLint JSON | `brew install swiftlint` |
| Kotlin | `detekt --input <target> --report sarif:<tmp>` | SARIF | `brew install detekt` |
| Ruby | `rubocop --format json <target>` | RuboCop JSON | `gem install rubocop` |
| Java | **no integrado** (`unsupported`; solo Semgrep) | — | — |
| Dart / Flutter | `dart analyze --format=json <target>` | Dart JSON | Incluido en Dart SDK |
| Terraform | `tflint --format json` (cwd = proyecto) | TFLint JSON | `brew install tflint` |
| COBOL | **no integrado** (`unsupported`; Semgrep no tiene reglas COBOL) | — | — |

## Semgrep (patrones LLM)

Las reglas cubren TypeScript/JavaScript (y Angular), Python, Go, Java, Ruby, PHP,
C#, Kotlin y Rust. Para Swift, Dart, Terraform, VB.NET y COBOL el script no
ejecuta Semgrep y lo marca `unsupported`: una pasada limpia sin reglas
aplicables no es un análisis.

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
| `--advisory` | Sin bloqueo — exit 0 salvo error de uso (2); el informe conserva el veredicto |

`--semgrep-only` y `--native-only` juntos son un error de uso (exit 2).

## Herramienta ausente o rota

Si la herramienta no está en el PATH → `status: missing`. Si su salida no se
interpreta (crash, config inválida, flag no soportado por la versión) →
`status: failed` con el motivo en `detail`. Ninguno de los dos cuenta como
"sin hallazgos": sin capas `ok` el veredicto es `UNVERIFIED` (exit 3).

## Normalización de outputs nativos

Los filtros jq por herramienta y la asignación de gates por `rule_id` viven en
`scripts/ast-quality-gate.sh` (fuente única). El resultado está descrito en
`unified-schema.md`.
