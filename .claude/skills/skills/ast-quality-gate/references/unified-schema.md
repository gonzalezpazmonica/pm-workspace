# Unified JSON Schema — AST Quality Gate Output

## Schema

```json
{
  "meta": {
    "timestamp": "2026-03-29T14:30:22Z",
    "language": "typescript",
    "target": "src/services/AuthService.ts",
    "files_analyzed": 3,
    "tool_chain": ["eslint", "semgrep"],
    "semgrep_rules": 12,
    "duration_ms": 4200
  },
  "score": {
    "total": 72,
    "grade": "C",
    "verdict": "REVIEW",
    "by_gate": {
      "QG-01": 100,
      "QG-02": 100,
      "QG-03": 0,
      "QG-04": 70,
      "QG-05": 0,
      "QG-06": 100,
      "QG-07": 80,
      "QG-08": 100,
      "QG-09": 100,
      "QG-10": 100,
      "QG-11": 90,
      "QG-12": 100
    }
  },
  "issues": [
    {
      "gate": "QG-03",
      "severity": "error",
      "file": "src/services/AuthService.ts",
      "line": 47,
      "column": 12,
      "message": "Object 'user' is possibly 'null' or 'undefined'",
      "source_tool": "tsc",
      "rule_id": "ts2531",
      "fixable": false,
      "snippet": "const token = user.generateToken();"
    },
    {
      "gate": "QG-05",
      "severity": "error",
      "file": "src/services/AuthService.ts",
      "line": 89,
      "column": 3,
      "message": "Empty catch block silences errors",
      "source_tool": "semgrep",
      "rule_id": "llm-empty-catch",
      "fixable": true,
      "snippet": "} catch (e) { }"
    },
    {
      "gate": "QG-04",
      "severity": "warning",
      "file": "src/services/AuthService.ts",
      "line": 23,
      "column": 18,
      "message": "Magic number 3600 — extract to constant TOKEN_EXPIRY_SECONDS",
      "source_tool": "eslint",
      "rule_id": "no-magic-numbers",
      "fixable": false,
      "snippet": "const expires = Date.now() + 3600 * 1000;"
    },
    {
      "gate": "QG-07",
      "severity": "warning",
      "file": "src/services/AuthService.ts",
      "line": 45,
      "column": 1,
      "message": "Function 'validateToken' is 67 lines (max: 50)",
      "source_tool": "eslint",
      "rule_id": "max-lines-per-function",
      "fixable": false,
      "snippet": "async function validateToken(token: string) {"
    }
  ],
  "summary": {
    "errors": 2,
    "warnings": 2,
    "infos": 0,
    "fixable": 1,
    "blocker_gates": ["QG-03", "QG-05"]
  }
}
```

## Campos obligatorios

### meta
- `timestamp` — ISO 8601 UTC
- `language` — uno de los 16 lenguajes detectados
- `target` — ruta del fichero o directorio analizado
- `tool_chain` — herramientas ejecutadas (array)

### score
- `total` — 0-100
- `grade` — A/B/C/D/F
- `verdict` — PASS | PASS_WITH_WARNINGS | REVIEW | FAIL | BLOCK

### issues[]
- `gate` — QG-01..QG-12
- `severity` — error | warning | info
- `file` — ruta relativa al target
- `line` — número de línea
- `message` — descripción human-readable
- `source_tool` — herramienta que lo detectó

### summary
- `errors` — count de issues con severity=error
- `warnings` — count de issues con severity=warning
- `blocker_gates` — gates QG-01,QG-03,QG-05,QG-09,QG-12 con al menos 1 error

## Normalización desde formatos nativos

### ESLint JSON → Unified

```bash
jq '[.[] | {
  gate: (if .ruleId | test("no-magic") then "QG-04"
         elif .ruleId | test("max-lines") then "QG-07"
         elif .ruleId | test("empty-catch|@typescript-eslint/no-empty") then "QG-05"
         else "QG-11" end),
  severity: (if .severity == 2 then "error" else "warning" end),
  file: .filePath,
  line: .line,
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
  message: .message,
  source_tool: "ruff",
  rule_id: .code,
  fixable: (.fix != null)
}]' ruff-output.json
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
  message: .extra.message,
  source_tool: "semgrep",
  rule_id: .check_id,
  fixable: (.extra.fix != null)
}]' semgrep-output.json
```

## Score computation

```bash
compute_score() {
  local errors=$1
  local warnings=$2
  local infos=$3

  local penalty=$(( errors * 10 + warnings * 3 + infos * 1 ))
  if [ $penalty -gt 100 ]; then penalty=100; fi
  echo $(( 100 - penalty ))
}
```
