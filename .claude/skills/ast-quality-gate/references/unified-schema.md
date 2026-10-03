# Unified JSON Schema — AST Quality Gate Output

Contrato del informe que escribe `scripts/ast-quality-gate.sh` en
`output/quality-gates/`. La normalización real (jq por herramienta y asignación
de gates) vive en el script; este documento describe el resultado.

## Schema

```json
{
  "meta": {
    "timestamp": "2026-10-03T07:18:17Z",
    "language": "typescript",
    "target": "/abs/path/src/services/AuthService.ts",
    "files_analyzed": 1,
    "coverage": "partial",
    "tool_chain": [
      {"layer": "native",  "tool": "eslint",  "status": "missing", "detail": "'eslint' no está en el PATH"},
      {"layer": "semgrep", "tool": "semgrep", "status": "ok",      "detail": "exit 0"}
    ]
  },
  "score": {
    "total": 74,
    "grade": "C",
    "verdict": "BLOCK",
    "blocking_gates": ["QG-05"]
  },
  "issues": [
    {
      "gate": "QG-05",
      "severity": "error",
      "file": "src/services/AuthService.ts",
      "line": 89,
      "column": 3,
      "message": "Empty catch block silences errors",
      "source_tool": "semgrep",
      "rule_id": "…references.llm-empty-catch",
      "fixable": false,
      "snippet": "} catch (e) { }"
    }
  ],
  "summary": {"errors": 1, "warnings": 2, "infos": 0, "fixable": 0}
}
```

## Campos

### meta
- `timestamp` — ISO 8601 UTC
- `language` — lenguaje detectado (`unknown` si ninguno)
- `target` — ruta absoluta del fichero o directorio analizado
- `files_analyzed` — ficheros bajo el target (sin `.git/` ni `node_modules/`)
- `coverage` — `full` (todas las capas pedidas corrieron), `partial` (alguna no), `none` (ninguna)
- `tool_chain[]` — una entrada por capa pedida: `layer` (`native`|`semgrep`), `tool`,
  `status` (`ok`|`missing`|`failed`|`unsupported`) y `detail` (exit code o motivo)

Una capa es `ok` cuando su salida se interpreta con la forma esperada, aunque la
herramienta salga con 1 (los linters lo hacen al encontrar issues). Cuentan como
`failed`, nunca como "sin hallazgos": salida vacía o no interpretable; `cargo`
con exit distinto de 0 y sin ningún `compiler-message` (clippy ausente, manifiesto
roto); `dotnet` con exit distinto de 0 y sin diagnósticos; Semgrep con exit >= 2 o
con entradas de nivel `error` en `.errors` (regla inválida). Un `dotnet build`
limpio (exit 0, sin diagnósticos) sí es `ok`.

### score
- `total` — 0-100, o `null` si `coverage` es `none`
- `grade` — A/B/C/D/F, o `null`
- `verdict` — PASS | PASS_WITH_WARNINGS | REVIEW | FAIL | BLOCK | UNVERIFIED
- `blocking_gates` — gates bloqueantes (QG-01, 03, 05, 09, 12) con al menos un error;
  si no está vacío, `verdict` es `BLOCK`

### issues[]
- `gate` — QG-01..QG-12, o `null` si el `rule_id` nativo no se asocia a ningún gate
- `severity` — error | warning | info
- `file`, `line`, `column` — ubicación tal como la da la herramienta
- `message`, `source_tool`, `rule_id`, `fixable`; Semgrep añade `snippet`

### summary
- `errors`, `warnings`, `infos`, `fixable` — recuentos sobre `issues`

## Gates y severidad

- Semgrep: el gate sale de `metadata.gate` de la regla; `ERROR`→error, `WARNING`→warning, resto→info.
- Nativo: el gate se asigna por patrón del `rule_id` (p. ej. `no-floating-promises`→QG-01,
  `E722`/`BLE001`→QG-05, `S105-S107`→QG-09, `F401`/`*unused*`→QG-11).
- Ruff reporta todo como `warning`, así que por sí solo nunca bloquea.
- golangci-lint solo da el linter (`gosec`), no la regla: en Go, QG-09 (credenciales)
  depende únicamente de Semgrep.

## Score

```
score = max(0, 100 - errores×10 - warnings×3 - infos×1)
```

| Score | Grade | Veredicto |
|-------|-------|-----------|
| 90-100 | A | PASS |
| 75-89 | B | PASS_WITH_WARNINGS |
| 60-74 | C | REVIEW |
| 40-59 | D | FAIL |
| 0-39 | F | BLOCK |
