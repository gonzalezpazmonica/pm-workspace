---
layer: peripheral
name: ast-quality-gate
description: Usar cuando se verifica la calidad de código generado por IA antes de merge.
allowed-tools: [Bash, Read, Glob, Grep, Write]
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.agent: code-reviewer
  savia.maturity: beta
  savia.category: quality
  savia.context: fork
  savia.priority: high
  savia.summary: "Meta-analizador: detecta 16 lenguajes, linter nativo en 14 (no Java ni COBOL) + Semgrep en 10 para patrones LLM (async sin await, N+1, null deref, magic numbers, catch vacio). Informe JSON con score 0-100, gates QG-01..QG-12 y cobertura; sin herramientas da UNVERIFIED, nunca PASS."
  savia.tags: "ast, static-analysis, quality-gates, llm-patterns, sdd"
---

# AST Quality Gate — Verificación de Calidad Multi-Lenguaje

Sistema de quality gates para verificar código generado por IA. Detecta 16
lenguajes; linter nativo en 14 y reglas Semgrep en 10. Busca los 5 patrones
de error más comunes en código LLM-generado y 7 criterios universales más.

## Cuándo usar

- Post-implementación SDD: verificar código antes de PR
- Pre-commit hook: bloquear patrones críticos
- `/ast-quality-gate {fichero-o-directorio}` — bajo demanda
- `PostToolUse` hook async tras `Edit|Write` en SDD sessions

## Arquitectura de 3 Capas

```
Capa 1: Herramienta nativa del lenguaje (máxima precisión)
  → eslint/ruff/golangci-lint/cargo clippy/dotnet build/phpstan/...
  → Output: JSON nativo normalizado

Capa 2: Semgrep (patrones LLM)
  → references/semgrep-rules.yaml (10 lenguajes)
  → Output: semgrep JSON normalizado

Capa 3: LSP Claude Code (semántica real-time)
  → diagnósticos del editor; el script NO la ejecuta
```

Una capa que no puede correr (herramienta ausente, caída o sin soporte) queda
en `meta.tool_chain` con `status` `missing|failed|unsupported` y nunca cuenta
como "sin hallazgos". Java y COBOL no tienen linter nativo integrado; las reglas
Semgrep cubren TS/JS, Python, Go, Java, Ruby, PHP, C#, Kotlin y Rust (Swift,
Dart, Terraform, VB.NET y COBOL: Semgrep `unsupported`).

## 12 Quality Gates

| Gate | Patrón | Severidad |
|------|--------|-----------|
| QG-01 | Async/concurrencia sin manejo de errores | error |
| QG-02 | N+1 queries / acceso DB en loop | error |
| QG-03 | Null/nil/None dereference sin check | error |
| QG-04 | Magic numbers/strings sin nombre | warning |
| QG-05 | Exception handling vacío o excesivamente amplio | error |
| QG-06 | Complejidad ciclomática > 15 | warning |
| QG-07 | Función/método > 50 líneas | warning |
| QG-08 | Duplicación de código > 15% | warning |
| QG-09 | Credenciales/secrets hardcodeados | error |
| QG-10 | Logging excesivo en producción | warning |
| QG-11 | Código muerto / imports no usados | info |
| QG-12 | Lógica nueva sin tests | error |

Detectores reales: Semgrep cubre QG-01..05, QG-09 y QG-10. QG-06, 07, 08 y 11
solo aparecen si el linter nativo los reporta (gate asignado por `rule_id`).
QG-12 no tiene detector todavía.

## Pipeline de Ejecución

### Paso 1: Detectar lenguaje

`scripts/ast-quality-gate.sh` detecta por extensión/fichero de proyecto (16 lenguajes).

### Paso 2: Ejecutar herramienta nativa

Ver comandos por lenguaje en `references/language-commands.md`.

### Paso 3: Ejecutar Semgrep (patrones LLM)

```bash
semgrep --config .claude/skills/ast-quality-gate/references/semgrep-rules.yaml \
        --json --no-git-ignore "$TARGET"
```

### Paso 4: Normalizar a JSON unificado

Ver `references/unified-schema.md` para el schema completo.
Output en `output/quality-gates/YYYYMMDD-HHMMSS-{lenguaje}-{pid}-{n}.json`
(`AST_QG_OUTPUT_DIR` lo cambia).

### Paso 5: Calcular score y veredicto

```
score = 100 - (errores × 10) - (warnings × 3) - (infos × 1)  [min 0]
```

| Score | Grade | Veredicto |
|-------|-------|-----------|
| 90-100 | A | PASS: listo para PR |
| 75-89 | B | PASS_WITH_WARNINGS: PR con advisory |
| 60-74 | C | REVIEW: requiere revisión human |
| 40-59 | D | FAIL: corregir antes de PR |
| 0-39 | F | BLOCK: bloquear commit |

Un error en un gate bloqueante fuerza `BLOCK` sea cual sea el score.
Si ninguna capa corrió: `UNVERIFIED`, `score.total: null`, `meta.coverage: none`.
Si corrió solo una: `meta.coverage: partial` y aviso en la salida.

## Integración SDD

### PostToolUse hook (async)

`.opencode/hooks/ast-quality-gate-hook.sh` (matcher `Edit|Write`, `async: true`)
corre el gate con `--advisory` y copia el informe a `output/quality-gates/latest.json`.

### Umbral de bloqueo

Gates QG-01, QG-03, QG-05, QG-09, QG-12 son **bloqueantes**: un issue de
severidad error en ellos da `BLOCK` (exit 1). El resto son **advisory**.

Exit: 0 PASS/PASS_WITH_WARNINGS/REVIEW · 1 FAIL/BLOCK · 2 uso o entorno
(target inexistente, flag desconocido, sin jq; no genera informe) ·
3 UNVERIFIED. `--advisory` convierte 1 y 3 en 0; el informe conserva el veredicto.

## Uso manual

```bash
bash scripts/ast-quality-gate.sh src/               # completo
bash scripts/ast-quality-gate.sh src/ --semgrep-only # solo Semgrep
bash scripts/ast-quality-gate.sh src/ --native-only  # solo nativo
bash scripts/ast-quality-gate.sh src/ --advisory     # sin bloqueo
```

## Prerequisitos

- `semgrep` ≥ 1.60.0 (`pip install semgrep`)
- Herramienta nativa del lenguaje instalada (ver `references/language-commands.md`)
- `jq` para normalización JSON (sin jq: exit 2)

## Esquemas y referencias

- `references/unified-schema.md` — Schema JSON unificado
- `references/semgrep-rules.yaml` — 22 reglas Semgrep por lenguaje
- `references/language-commands.md` — Comandos CLI por lenguaje
