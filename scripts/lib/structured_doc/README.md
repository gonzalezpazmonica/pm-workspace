# structured_doc

Librería Python reutilizable para parsear, lintear, comparar y validar documentos
estructurados de Savia (specs, rules, flows). Implementa el patrón **Spec & Handler**:
sin excepciones, toda operación devuelve `Result[T]`.

Spec: `SPEC-STRUCTURED-DOC-TOOLING` · Rule #26 (Python para lógica, Bash solo invoca).

---

## Empezar en 5 minutos

### Requisitos

```bash
pip install -r scripts/lib/structured_doc/requirements.txt
# pydantic>=2, pyyaml>=6, jsonschema>=4
```

### CLI (uso directo)

```bash
# Usar el wrapper recomendado (activa venv automáticamente)
bash scripts/savia-doc.sh lint   spec-md path/to/my.spec.md --human
bash scripts/savia-doc.sh diff   spec-md old.spec.md new.spec.md --human
bash scripts/savia-doc.sh validate spec-md path/to/my.spec.md --human
bash scripts/savia-doc.sh list-types
```

O directamente con Python:

```bash
PYTHONPATH=scripts/lib python3 -m structured_doc lint spec-md my.spec.md
```

### API Python

```python
from structured_doc import (
    parse_document, lint_document, diff_documents, validate_document,
)

# Parsear (base de todas las operaciones)
result = parse_document("spec-md", "path/to/my.spec.md")
if result.ok:
    doc = result.value             # ParsedDocument
    print(doc.frontmatter)         # dict con campos YAML
    print(doc.sections)            # list[ParsedSection]

# Lint
result = lint_document("spec-md", "path/to/my.spec.md")
if result.ok:
    report = result.value          # FindingsReport
    print(report.summary)
    for f in report.findings:
        print(f.severity, f.message)
else:
    print(result.error_kind, result.message)

# Diff estructural entre dos versiones
result = diff_documents("spec-md", "old.spec.md", "new.spec.md")
if result.ok:
    diff = result.value            # DiffResult
    print(diff.regression)         # True si hubo regresión
    for change in diff.changes:
        print(change.kind, change.path)

# Validar frontmatter contra JSON Schema
result = validate_document("spec-md", "my.spec.md")
if result.ok:
    print(result.value.valid)      # True / False
    for err in result.value.errors:
        print(err.path, err.message)
```

---

## Estructura

```
scripts/lib/structured_doc/
├── __init__.py          # API pública (8 símbolos exportados)
├── __main__.py          # Punto de entrada: python3 -m structured_doc
├── _bootstrap.py        # Registra tipos canónicos de Savia (spec-md, …)
├── cli.py               # Parser argparse + comandos lint/diff/validate/list-types
├── registry.py          # Registro global de DocType
├── result.py            # Result[T] = Success[T] | Failure (nunca lanza)
├── findings.py          # Finding, FindingsReport, Severity
├── parser/
│   ├── spec.py          # ParsedDocument, ParsedSection (contratos Pydantic)
│   └── handler.py       # parse_document() — soporta frontmatter-prose y yaml-only
├── linter/
│   ├── spec.py          # LintRule, LintRuleset
│   ├── handler.py       # lint_document()
│   └── rules/
│       ├── registry.py          # registro de funciones de check
│       ├── required_field.py    # check: campo frontmatter obligatorio
│       ├── line_count.py        # check: límite de líneas
│       └── reference_exists.py # check: referencia existe en disco
├── differ/
│   ├── spec.py          # Change, DiffResult
│   └── handler.py       # diff_documents()
├── validator/
│   ├── spec.py          # ValidationResult, ValidationError
│   └── handler.py       # validate_document() — Draft 2020-12
└── requirements.txt
```

---

## Tipos de documento registrados

| `type_id` | Estrategia de parser | Schema | Reglas de lint |
|---|---|---|---|
| `spec-md` | `frontmatter-prose` | `schemas/spec-md.schema.json` | `rules/spec-md.lint.yaml` |

> Rutas relativas a la raíz del repositorio (`scripts/lib/structured_doc/_bootstrap.py`
> resuelve `REPO_ROOT` subiendo 3 niveles desde su ubicación).

Para registrar un tipo nuevo:

```python
from pathlib import Path
from structured_doc import register_type

REPO_ROOT = Path(__file__).resolve().parents[3]  # ajustar según profundidad

register_type(
    type_id="my-doc",
    parser="frontmatter-prose",                          # o "yaml-only"
    schema_path=REPO_ROOT / "schemas" / "my-doc.schema.json",
    lint_rules_path=REPO_ROOT / "rules" / "my-doc.lint.yaml",
)
```

El lugar canónico para hacerlo es `_bootstrap.py`: se importa automáticamente por `cli.py`
y por los tests a través de `conftest_structured_doc.py`.

---

## Estrategias de parser

| Estrategia | Qué parsea |
|---|---|
| `frontmatter-prose` | YAML entre `---` + cuerpo Markdown. Si no hay bloque `---`, extrae frontmatter implícito de líneas `**Campo:** valor` (primeras 60 líneas). |
| `yaml-only` | Documento YAML puro, sin sección de prosa. |

---

## Reglas de lint integradas

| `check` | Config requerida | Qué verifica |
|---|---|---|
| `required_field` | `fields: [campo1, …]` | Campos de frontmatter presentes y no vacíos |
| `line_count` | `max_lines: N` | Documento no supera N líneas |
| `reference_exists` | `field`, `pattern`, `registry`, `suffix` | Token en frontmatter existe como fichero en `registry/` |

Para añadir un check propio:

```python
from structured_doc.linter.rules.registry import register_check
from structured_doc.findings import Finding

def my_check(parsed, rule) -> list[Finding]:
    ...

register_check("my_check", my_check)
```

---

## Códigos de salida (CLI)

| Código | Significado |
|---|---|
| `0` | OK (sin errores; `diff` sin regresión) |
| `1` | Findings con errores (`lint`) · regresión detectada (`diff`) · frontmatter inválido (`validate`) |
| `2` | Error de uso (argumentos incorrectos) |
| `3` | Fallo interno (fichero no encontrado, YAML inválido, etc.) |

---

## Tests

```bash
# Todos los tests de la librería
pytest tests/python/test_structured_doc_*.py -v

# Con el wrapper bats (smoke end-to-end)
bats tests/savia-doc-wrapper.bats
```

Los tests usan fixtures en `tests/python/fixtures/structured_doc/`.
El conftest se carga desde `tests/python/conftest_structured_doc.py`.

---

## Integración CI

```bash
# Lint de un spec como gate de CI (sale 1 si hay errores)
bash scripts/savia-doc.sh lint spec-md docs/specs/MY.spec.md
echo "Exit: $?"

# Diff para detectar regresiones entre PR y main
git show main:docs/specs/MY.spec.md > /tmp/old.spec.md
bash scripts/savia-doc.sh diff spec-md /tmp/old.spec.md docs/specs/MY.spec.md
echo "Regresion: $?"  # 1 si regresión
```

El wrapper `scripts/savia-doc.sh` activa el venv Python si existe en `$SAVIA_VENV`
y añade `scripts/lib` al `PYTHONPATH` automáticamente.

---

## Extender la librería

1. **Nuevo tipo de documento**: añadir `register_type(...)` en `_bootstrap.py`.
2. **Nuevo check de lint**: crear módulo en `linter/rules/`, implementar `_check(parsed, rule)`, llamar `register_check(name, _check)`, e importar en `linter/rules/registry.py`.
3. **Nueva estrategia de parser**: añadir rama en `parser/handler.py::parse_document` y actualizar `ParserStrategy` en `registry.py`.

Todos los handlers siguen el contrato: **nunca lanzan, siempre devuelven `Result[T]`**.
