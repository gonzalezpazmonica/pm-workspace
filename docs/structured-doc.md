# structured_doc — Guía operativa

> Librería Python reutilizable para parsear, lintear, comparar y validar documentos
> estructurados de Savia. Spec: `SPEC-STRUCTURED-DOC-TOOLING`.

---

## Índice

1. [Qué resuelve](#qué-resuelve)
2. [Instalación](#instalación)
3. [Uso rápido (CLI)](#uso-rápido-cli)
4. [Referencia de comandos](#referencia-de-comandos)
5. [API Python](#api-python)
6. [Tipos de documento registrados](#tipos-de-documento-registrados)
7. [Cómo añadir un tipo nuevo](#cómo-añadir-un-tipo-nuevo)
8. [Cómo añadir un check de lint](#cómo-añadir-un-check-de-lint)
9. [Migrar un validador existente](#migrar-un-validador-existente)
10. [Aclaración: Spec & Handler vs SDD](#aclaración-spec--handler-vs-sdd)

---

## Qué resuelve

Savia tiene varios tipos de documentos estructurados (`.spec.md`, reglas de dominio,
vault notes, manifiestos YAML) que hasta ahora construían su propio validador a mano.
`structured_doc` centraliza cuatro operaciones que todos comparten:

| Operación | Qué hace |
|---|---|
| `parse` | Extrae frontmatter + secciones de prosa de cualquier documento registrado |
| `lint` | Aplica reglas declarativas YAML y devuelve findings |
| `diff` | Detecta cambios estructurales entre dos versiones; marca regresiones |
| `validate` | Valida frontmatter contra JSON Schema (Draft 2020-12) |

Toda operación devuelve `Result[T]` — nunca lanza excepciones. El output por
defecto es JSON, consumible por agentes.

---

## Instalación

```bash
pip install -r scripts/lib/structured_doc/requirements.txt
# pydantic>=2.0,<3.0  pyyaml>=6.0  jsonschema>=4.0
```

Si el repo tiene `.venv/`, el wrapper `scripts/savia-doc.sh` lo activa automáticamente.

---

## Uso rápido (CLI)

El wrapper recomendado desde la raíz del repo:

```bash
# Lint de un spec
bash scripts/savia-doc.sh lint spec-md docs/specs/MI-FEATURE.spec.md --human

# Diff entre dos versiones
bash scripts/savia-doc.sh diff spec-md docs/specs/MI-FEATURE.spec.md.bak docs/specs/MI-FEATURE.spec.md --human

# Validar frontmatter contra JSON Schema
bash scripts/savia-doc.sh validate spec-md docs/specs/MI-FEATURE.spec.md --human

# Ver tipos registrados
bash scripts/savia-doc.sh list-types
```

Sin wrapper (con PYTHONPATH explícito):

```bash
PYTHONPATH=scripts/lib python3 -m structured_doc lint spec-md docs/specs/MI-FEATURE.spec.md
```

---

## Referencia de comandos

### `lint <type> <file> [--rules <yaml>] [--human]`

Aplica las reglas declarativas YAML asociadas al tipo. Devuelve `FindingsReport`.

```bash
bash scripts/savia-doc.sh lint spec-md docs/specs/MI-FEATURE.spec.md
```

Salida JSON (por defecto):

```json
{
  "findings": [
    {
      "severity": "error",
      "rule_id": "missing-required-field",
      "path": "frontmatter.sprint",
      "message": "Missing required field: sprint",
      "evidence": null,
      "suggestion": "Add `sprint:` to the frontmatter"
    }
  ],
  "summary": { "errors": 1, "warnings": 0, "info": 0 }
}
```

Salida `--human` (terminal):

```
[E] missing-required-field @ frontmatter.sprint: Missing required field: sprint
-- errors=1 warnings=0 info=0
```

Flag `--rules /otra/ruta.lint.yaml` sobreescribe las reglas registradas para ese tipo.

**Códigos de salida:** `0` sin errores · `1` hay errores · `3` fallo interno.

---

### `diff <type> <file_a> <file_b> [--regression-only] [--human]`

Compara frontmatter y secciones entre dos documentos. Detecta regresiones
(campos eliminados/modificados, secciones eliminadas).

```bash
git show main:docs/specs/MI-FEATURE.spec.md > /tmp/old.spec.md
bash scripts/savia-doc.sh diff spec-md /tmp/old.spec.md docs/specs/MI-FEATURE.spec.md
```

Salida JSON:

```json
{
  "type_id": "spec-md",
  "file_a": "/tmp/old.spec.md",
  "file_b": "docs/specs/MI-FEATURE.spec.md",
  "changes": [
    { "kind": "frontmatter-modified", "path": "frontmatter.sprint",
      "before": "2026-30", "after": "2026-31" }
  ],
  "regression": false
}
```

`regression: true` cuando hay `frontmatter-removed`, `frontmatter-modified`
o `section-removed`. Flag `--regression-only` suprime el output cuando
`regression` es `false`.

**Códigos de salida:** `0` sin regresión · `1` hay regresión · `3` fallo interno.

---

### `validate <type> <file> [--human]`

Valida el frontmatter del documento contra el JSON Schema registrado para su tipo.

```bash
bash scripts/savia-doc.sh validate spec-md docs/specs/MI-FEATURE.spec.md
```

Salida JSON:

```json
{
  "valid": true,
  "errors": []
}
```

Cuando falla:

```json
{
  "valid": false,
  "errors": [
    { "path": "frontmatter.task_id", "message": "'' is too short" }
  ]
}
```

**Códigos de salida:** `0` válido · `1` inválido · `3` fallo interno.

---

### `list-types [--human]`

Lista los tipos de documento registrados en la sesión actual.

```bash
bash scripts/savia-doc.sh list-types
# {"types": ["spec-md"]}
```

---

## API Python

```python
from structured_doc import (
    register_type,
    parse_document, lint_document, diff_documents, validate_document,
    Result, Success, Failure,
    Finding, FindingsReport,
)

# --- parse ---
result = parse_document("spec-md", "docs/specs/MI-FEATURE.spec.md")
if result.ok:
    doc = result.value          # ParsedDocument
    doc.frontmatter             # dict — campos YAML (o inferidos de **Campo:** valor)
    doc.sections                # list[ParsedSection] — headings con body y line_start
    doc.total_lines             # int
else:
    print(result.error_kind)    # "file-not-found" | "unknown-type" | "invalid-yaml" | …
    print(result.message)

# --- lint ---
result = lint_document("spec-md", "docs/specs/MI-FEATURE.spec.md")
if result.ok:
    report = result.value       # FindingsReport
    report.summary.errors       # int
    report.summary.warnings     # int
    for f in report.findings:
        f.severity              # "error" | "warning" | "info"
        f.rule_id               # str — e.g. "missing-required-field"
        f.path                  # str — e.g. "frontmatter.sprint"
        f.message               # str
        f.suggestion            # str | None

# --- diff ---
result = diff_documents("spec-md", "old.spec.md", "new.spec.md")
if result.ok:
    diff = result.value         # DiffResult
    diff.regression             # bool
    for change in diff.changes:
        change.kind             # "frontmatter-added" | "frontmatter-removed" |
                                # "frontmatter-modified" | "section-added" | "section-removed"
        change.path             # str — e.g. "frontmatter.sprint"
        change.before           # Any | None
        change.after            # Any | None

# --- validate ---
result = validate_document("spec-md", "docs/specs/MI-FEATURE.spec.md")
if result.ok:
    vr = result.value           # ValidationResult
    vr.valid                    # bool
    for err in vr.errors:
        err.path                # str — e.g. "frontmatter.task_id"
        err.message             # str
```

### Patrón Result

Todos los handlers siguen el contrato: **nunca lanzan excepciones**, siempre devuelven `Result[T]`.

```python
from structured_doc import Result, Success, Failure

result: Result = some_handler(...)
if result.ok:            # True  → Success, accede a result.value
    use(result.value)
else:                    # False → Failure
    print(result.error_kind)   # discriminated union tag
    print(result.message)
    print(result.detail)       # dict | None con contexto adicional
```

Tipos de `error_kind` comunes:

| `error_kind` | Origen |
|---|---|
| `"unknown-type"` | `type_id` no registrado |
| `"file-not-found"` | Fichero no existe o no es fichero |
| `"empty-document"` | Contenido vacío |
| `"invalid-yaml"` | Error de parseo YAML |
| `"rules-file-not-found"` | Fichero de reglas no localizado |
| `"invalid-rules-yaml"` | Reglas mal formadas |
| `"unknown-check"` | Nombre de check no registrado |
| `"schema-not-found"` | Schema JSON no localizado |
| `"invalid-schema"` | Schema JSON mal formado |

---

## Tipos de documento registrados

Los tipos se registran automáticamente al importar `_bootstrap.py` (que `cli.py` importa
siempre al arrancar). Los schemas y reglas resuelven rutas relativas a la raíz del repo.

| `type_id` | Parser | Schema | Reglas |
|---|---|---|---|
| `spec-md` | `frontmatter-prose` | `schemas/spec-md.schema.json` | `rules/spec-md.lint.yaml` |

### Estrategias de parser

**`frontmatter-prose`** — Documentos Markdown con bloque YAML entre `---`.
Si no hay bloque `---`, extrae frontmatter implícito de líneas `**Campo:** valor`
en las primeras 60 líneas (el formato que usan las specs de Savia).

**`yaml-only`** — Documento YAML puro sin sección de prosa.
El YAML completo se expone como `frontmatter`; `sections` es lista vacía.

### Reglas de lint para `spec-md`

Definidas en `rules/spec-md.lint.yaml`:

| `id` | `check` | Severidad | Qué verifica |
|---|---|---|---|
| `missing-required-field` | `required_field` | error | Campos `task_id`, `sprint`, `estado` presentes y no vacíos |
| `broken-spec-reference` | `reference_exists` | error | `depende_de` apunta a un fichero `.spec.md` que existe en `docs/specs/` |
| `spec-too-long` | `line_count` | warning | Documento no supera 500 líneas |

---

## Cómo añadir un tipo nuevo

**Paso 1 — Schema JSON** (opcional pero recomendado):

Crea `schemas/mi-tipo.schema.json` con JSON Schema Draft 2020-12 para el frontmatter:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "mi-tipo frontmatter",
  "type": "object",
  "required": ["id", "version"],
  "properties": {
    "id": { "type": "string", "minLength": 1 },
    "version": { "type": "string" }
  },
  "additionalProperties": true
}
```

**Paso 2 — Reglas de lint** (opcional):

Crea `rules/mi-tipo.lint.yaml`:

```yaml
rules:
  - id: missing-id
    severity: error
    applies_to: mi-tipo
    check: required_field
    config:
      fields: [id, version]

  - id: too-long
    severity: warning
    applies_to: mi-tipo
    check: line_count
    config:
      max_lines: 200
```

Cada `check` referencia una función registrada (ver [checks integrados](#cómo-añadir-un-check-de-lint)).

**Paso 3 — Registro**:

Añade en `scripts/lib/structured_doc/_bootstrap.py`:

```python
register_type(
    type_id="mi-tipo",
    parser="frontmatter-prose",          # o "yaml-only"
    schema_path=_REPO_ROOT / "schemas" / "mi-tipo.schema.json",
    lint_rules_path=_REPO_ROOT / "rules" / "mi-tipo.lint.yaml",
)
```

**Paso 4 — Verificar**:

```bash
bash scripts/savia-doc.sh list-types
# {"types": ["mi-tipo", "spec-md"]}

bash scripts/savia-doc.sh lint mi-tipo ruta/al/documento.md --human
bash scripts/savia-doc.sh validate mi-tipo ruta/al/documento.md --human
```

---

## Cómo añadir un check de lint

Un check es una función Python pura que recibe un `ParsedDocument` y un `LintRule`
y devuelve `list[Finding]`.

```python
# scripts/lib/structured_doc/linter/rules/mi_check.py
from __future__ import annotations
from ..spec import LintRule
from ...findings import Finding
from ...parser.spec import ParsedDocument
from .registry import register_check


def _check(parsed: ParsedDocument, rule: LintRule) -> list[Finding]:
    # Accede a parsed.frontmatter, parsed.sections, parsed.total_lines, etc.
    umbral = rule.config.get("umbral", 10)
    if len(parsed.sections) > umbral:
        return [Finding(
            severity=rule.severity,
            rule_id=rule.id,
            path="sections",
            message=f"Demasiadas secciones: {len(parsed.sections)} (máx {umbral})",
        )]
    return []


register_check("mi_check", _check)
```

Importa el módulo en `linter/rules/__init__.py` o en `_bootstrap.py` para asegurarte
de que `register_check` se ejecuta antes de invocar el linter. Luego úsalo en YAML:

```yaml
- id: demasiadas-secciones
  severity: warning
  applies_to: mi-tipo
  check: mi_check
  config:
    umbral: 8
```

### Checks integrados

| Nombre | Config requerida | Descripción |
|---|---|---|
| `required_field` | `fields: [campo, …]` | Verifica que cada campo del frontmatter esté presente y no vacío |
| `line_count` | `max_lines: N` | Error/warning si el documento supera N líneas |
| `reference_exists` | `field`, `pattern`, `registry`, `suffix` | El valor del campo coincide con el patrón y el fichero `{registry}/{token}{suffix}` existe |

---

## Migrar un validador existente

La adopción es gradual: **los validadores existentes no se tocan** hasta que
se modifiquen por otra razón (compatible con Rule #26 y con la política de deuda técnica).

Cuando llegue el momento de migrar un validador ad-hoc a `structured_doc`:

1. Define su schema JSON en `schemas/`.
2. Define sus reglas en `rules/`.
3. Registra el tipo en `_bootstrap.py`.
4. Elimina el código de parseo/validación ad-hoc y llama a `lint_document` / `validate_document`.
5. Asegúrate de que los tests existentes siguen pasando con el nuevo output.

La ventaja inmediata: el output JSON es homogéneo, cualquier agente puede consumirlo
sin adaptar su parser para cada tipo de documento.

---

## Aclaración: Spec & Handler vs SDD

Estos dos conceptos son ortogonales y compatibles:

| Concepto | Qué es |
|---|---|
| **SDD (Spec-Driven Development)** | Metaproceso: escribir specs ejecutables antes de código. Workflow de trabajo de Savia. |
| **Spec & Handler Pattern** | Patrón arquitectónico interno de `structured_doc`: separar el contrato (`spec.py`) de la implementación (`handler.py`). No lanza excepciones. |

El patrón Spec & Handler es una convención de diseño dentro de esta librería.
No guarda relación con el proceso SDD salvo que comparten el término "spec".

---

## Integración CI

```bash
# Gate de lint — sale 1 si hay errores de lint
bash scripts/savia-doc.sh lint spec-md docs/specs/MI-FEATURE.spec.md
[ $? -eq 0 ] && echo "OK" || echo "LINT ERRORS"

# Detectar regresiones entre PR y main
git show main:docs/specs/MI-FEATURE.spec.md > /tmp/old.spec.md
bash scripts/savia-doc.sh diff spec-md /tmp/old.spec.md docs/specs/MI-FEATURE.spec.md --regression-only
[ $? -eq 0 ] && echo "No regresión" || echo "REGRESIÓN DETECTADA"
```

Exit codes: `0` OK · `1` errores/regresión · `2` uso incorrecto · `3` fallo interno.

---

## Referencia de tests

```bash
# Suite completa
pytest tests/python/test_structured_doc_*.py -v

# Smoke test end-to-end del wrapper bash
bats tests/savia-doc-wrapper.bats
```

Fixtures en `tests/python/fixtures/structured_doc/`.

---

## Ver también

- `scripts/lib/structured_doc/README.md` — referencia rápida del módulo
- `rules/spec-md.lint.yaml` — reglas declarativas para `.spec.md`
- `schemas/spec-md.schema.json` — JSON Schema del frontmatter de specs
- `scripts/savia-doc.sh` — wrapper bash (≤ 15 líneas, Rule #26)
- `SPEC-STRUCTURED-DOC-TOOLING.spec.md` — spec de diseño completa
