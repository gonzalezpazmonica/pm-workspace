# Spec: Structured Document Tooling — Patrón canónico para linter, differ y validator de documentos Context-as-Code

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Tooling reutilizable para documentos estructurados
**Sprint:**         2026-31
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     8h (2 slices × 4h)
**Estado:**         Pendiente

**Depende de:**     Rule #26 Language Boundaries
**Inspirado por:**  google-labs-code/design.md (Google Labs, mayo 2026): el patrón frontmatter normativo + prose + tooling CLI con `lint`/`diff`/`validate` y output JSON consumible por agentes. Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. Esta spec NO añade comandos slash directamente. Añade una skill canónica y una librería Python reutilizable que cualquier futuro tipo de documento estructurado en Savia (`.spec.md`, `.flow.yaml`, `.acm.md`, vault notes, `savia.manifest.yaml`, `.flow.profile.yaml`) consume para generar su propio tooling. La invocación final del tooling de cada tipo concreto de documento sigue siendo: usuario → OpenCode → modelo → tool Bash → wrapper → librería Python.

**Decisión arquitectónica registrada:**
- (D-1) NO se adopta DESIGN.md como formato. El dominio (design tokens, identidad visual) no es parte de Savia. Lo que se adopta es el **patrón estructural**: frontmatter normativo + prose explicativa + tooling CLI con lint/diff/validate.
- (D-2) El patrón se cristaliza como **librería Python reutilizable** (`scripts/lib/structured_doc/`), NO como herramienta para un único tipo de documento. Cualquier tipo nuevo de documento estructurado en Savia hereda de esta librería.
- (D-3) **Spec & Handler Pattern** (también de design.md): cada operación del tooling se separa en `spec.py` (schemas, contratos, tipos de error como discriminated union) y `handler.py` (implementación que NO lanza excepciones, retorna `Result[Success, Failure]`). Adopción del patrón en Python con `pydantic` + Result types.
- (D-4) Output siempre JSON estructurado, consumible por agentes. Texto humano-legible es opcional vía flag `--human`.
- (D-5) **MCP server** (`savia-doc-tooling`) expone las tres operaciones canónicas (`lint`, `diff`, `validate`) como tools genéricas parametrizadas por tipo de documento.
- (D-6) Reglas de linter declarables en YAML, no en Python. Esto permite que un humano añada o ajuste reglas sin tocar código (alineado con principio de configurabilidad de SPEC-AGENT-ARCHITECT).

---

## 1. Contexto y Objetivo

### 1.1 Problema

Savia tiene varios tipos de documentos estructurados que comparten estructura conceptual (frontmatter YAML + prose markdown) pero NO comparten tooling:

- `.spec.md` — specs de funcionalidad (frontmatter con metadata, prose con contenido normativo).
- `.flow.yaml` — grafos AFG (YAML puro, pero conceptualmente análogo).
- Vault notes Obsidian (frontmatter de confidencialidad + prose).
- `savia.manifest.yaml` y `savia.lock` — declaración de componentes.
- `.flow.profile.yaml` — profiles de tier-routing.
- Reglas en `docs/rules/domain/*.md` (frontmatter implícito + prose).
- ADRs futuros, agent code maps (`.acm.md`), digest notes, etc.

Cada tipo construye su propio validador a mano, repite código de parseo de frontmatter, y devuelve errores de forma incoherente. No hay forma de:

1. **Validar** un documento contra su schema de forma uniforme.
2. **Diferenciar** dos versiones detectando regresiones (campos eliminados, valores modificados, secciones omitidas).
3. **Lintar** un documento contra reglas declarativas (campos obligatorios, referencias rotas, contradicciones, longitud excesiva).
4. **Devolver findings** en un formato JSON común que cualquier agente pueda consumir.

Google Labs publicó en mayo de 2026 `design.md`, un proyecto que cristaliza este patrón con elegancia para el dominio de design tokens. El patrón estructural es generalizable y resuelve nuestro problema.

### 1.2 Objetivo

Construir `structured_doc`, una librería Python reutilizable que cualquier tipo de documento estructurado en Savia pueda usar para generar su propio tooling de validación, comparación y linting.

Tras esta spec, declarar tooling para un nuevo tipo de documento estructurado se reduce a:

1. Definir su schema YAML (estructura del frontmatter).
2. Definir sus reglas de linter (en YAML declarativo).
3. Registrar el tipo en el registry: `structured_doc.register("flow", FlowSchema, FlowLintRules)`.
4. Invocar: `structured_doc lint flow my-flow.yaml`.

### 1.3 No-Goals

- ❌ NO se construye un CLI nuevo de Savia. Las operaciones se exponen vía wrapper bash + comandos slash de cada tipo de documento concreto, NO como `savia-doc lint ...` global.
- ❌ NO se reescribe ninguno de los validadores existentes en este slice. La librería se crea; los validadores existentes migran cuando se tocan por otra razón (igual que con la deuda de Rule #26).
- ❌ NO se adopta el formato DESIGN.md ni los design tokens. Si en el futuro Savia necesita gestión de identidad visual, se evalúa entonces.
- ❌ NO se construye en TypeScript. Stack Python (Rule #26).
- ❌ NO se cubren documentos no-estructurados (markdown sin frontmatter, código fuente).

---

## 2. Requisitos Funcionales

### 2.1 Estructura de la librería

```
scripts/lib/structured_doc/
├── __init__.py
├── registry.py           # Registry de tipos de documento
├── parser/
│   ├── spec.py           # Schemas Pydantic, tipos de error
│   └── handler.py        # Parsea frontmatter + prose → AST
├── linter/
│   ├── spec.py
│   ├── handler.py        # Aplica reglas, devuelve findings
│   └── rules/            # Reglas reutilizables (missing-fields, broken-refs, ...)
├── differ/
│   ├── spec.py
│   └── handler.py        # Compara dos documentos, detecta regresiones
├── validator/
│   ├── spec.py
│   └── handler.py        # Valida contra JSON Schema
├── result.py             # Tipo Result[Success, Failure]
├── findings.py           # Tipo Finding canónico
├── cli.py                # Punto de entrada
├── mcp_server.py         # MCP server
└── requirements.txt
```

### 2.2 Tipo Finding canónico

```python
class Finding:
    severity: Literal["error", "warning", "info"]
    rule_id: str                    # ej. "missing-required-field"
    path: str                       # ruta dentro del documento (ej. "frontmatter.title")
    message: str                    # texto humano
    evidence: str | None            # cita textual del documento
    suggestion: str | None          # propuesta de corrección, si aplica
```

Output JSON canónico (compatible con el patrón de design.md):

```json
{
  "findings": [
    {
      "severity": "error",
      "rule_id": "broken-reference",
      "path": "frontmatter.depends_on",
      "message": "Reference 'SPEC-999' does not exist",
      "evidence": "depends_on: SPEC-999",
      "suggestion": null
    }
  ],
  "summary": { "errors": 1, "warnings": 0, "info": 0 }
}
```

### 2.3 Spec & Handler Pattern (D-3)

Cada operación se separa en dos ficheros:

**`spec.py`** — define el contrato:
- Input schema con Pydantic.
- Output schema.
- Discriminated union de errores (cada error es un tipo concreto, no `Exception` genérico).
- `Result = Success | Failure`.

**`handler.py`** — implementa el contrato:
- Implementa la interfaz declarada en spec.
- NO lanza excepciones. Captura y mapea a `Result.Failure`.
- Side-effects (lectura de ficheros, red) explícitos.

Esto es el patrón "Spec & Handler" de design.md adaptado a Python. Tests separados: tests del spec validan que el contrato es coherente; tests del handler validan implementación.

### 2.4 Reglas declarativas en YAML

```yaml
# rules/spec-md.lint.yaml
rules:
  - id: missing-required-field
    severity: error
    applies_to: spec-md
    check: required_field
    config:
      fields: [task_id, sprint, status]

  - id: broken-spec-reference
    severity: error
    applies_to: spec-md
    check: reference_exists
    config:
      pattern: "^SPEC-[A-Z0-9-]+$"
      registry: docs/specs/

  - id: spec-too-long
    severity: warning
    applies_to: spec-md
    check: line_count
    config:
      max_lines: 500
```

Cada `check` es una función pura registrada en `rules/registry.py`. Añadir un check nuevo es escribir una función Python que recibe el AST y devuelve `list[Finding]`.

### 2.5 Tres operaciones canónicas

**`lint`**
```bash
python3 -m structured_doc lint <type> <file> [--rules <yaml>] [--human]
```
Aplica reglas de linter al documento. Output JSON con findings.

**`diff`**
```bash
python3 -m structured_doc diff <type> <file1> <file2> [--regression-only]
```
Compara dos documentos del mismo tipo. Detecta:
- Campos añadidos / eliminados / modificados en frontmatter.
- Secciones añadidas / eliminadas en prose.
- Referencias internas modificadas.

Output JSON con cambios estructurados. Flag `regression: true` si hay eliminaciones o cambios incompatibles.

**`validate`**
```bash
python3 -m structured_doc validate <type> <file>
```
Valida estructura del documento contra JSON Schema. Más estricto que `lint` (estructural, no semántico).

### 2.6 Registry de tipos de documento

```python
# scripts/lib/structured_doc/registry.py
from structured_doc import register_type

register_type(
    type_id="spec-md",
    schema_path="schemas/spec-md.schema.json",
    lint_rules_path="rules/spec-md.lint.yaml",
    parser="frontmatter-prose",  # estrategia de parseo
)

register_type(
    type_id="flow-yaml",
    schema_path="schemas/flow.schema.json",
    lint_rules_path="rules/flow.lint.yaml",
    parser="yaml-only",
)
```

### 2.7 MCP server `savia-doc-tooling`

Expone las tres operaciones como tools MCP:
- `lint(doc_type, file_path) → findings`
- `diff(doc_type, file_a_path, file_b_path) → diff_result`
- `validate(doc_type, file_path) → validation_result`
- `list_doc_types() → registered_types`

Cualquier frontend MCP-compatible invoca el tooling sin pasar por OpenCode.

### 2.8 Adopción gradual

La librería se crea; los validadores existentes NO se migran de golpe. Cada validador existente se reescribe usando `structured_doc` cuando se toca por otra razón. Se documenta en `docs/structured-doc.md` cómo migrar.

---

## 3. No se modifica

- Ningún documento existente.
- Validadores actuales del repo (siguen funcionando hasta migración voluntaria).
- Schemas existentes (se reutilizan; no se reescriben).
- Comandos slash existentes.
- SPEC-AGENTIC-FLOW-GRAPH, SPEC-SAVIA-MANIFEST, SPEC-AFG-COMPOSE, SPEC-AGENT-ARCHITECT, SPEC-FLOW-OBSERVABILITY (futuros usuarios de la librería, no se modifican).

---

## 4. Criterios de Aceptación

**Slice 1 — Librería core + tipo `spec-md`:**
- [ ] Estructura `scripts/lib/structured_doc/` con módulos separados.
- [ ] Spec & Handler Pattern aplicado a las tres operaciones.
- [ ] Tipo `Result` y `Finding` canónicos implementados.
- [ ] Tipo `spec-md` registrado y funcional.
- [ ] `lint`, `diff`, `validate` funcionan sobre `.spec.md` reales del repo.
- [ ] 3 reglas de linter declaradas en YAML para `spec-md`: `missing-required-field`, `broken-spec-reference`, `spec-too-long`.
- [ ] Tests pytest: 25 casos.
- [ ] Output JSON conforme a la sección 2.2.
- [ ] `--human` produce output legible para la terminal.

**Slice 2 — MCP server + segundo tipo (`flow-yaml`):**
- [ ] MCP server `savia-doc-tooling` funcional.
- [ ] Tipo `flow-yaml` registrado, valida `.flow.yaml` reales.
- [ ] Documentación: `docs/structured-doc.md` con guía paso a paso para añadir un tipo nuevo.
- [ ] Demo: `lint`, `diff` y `validate` ejecutados sobre los dos tipos.
- [ ] Tests pytest: 15 casos adicionales.

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — librería):**
- `scripts/lib/structured_doc/__init__.py`
- `scripts/lib/structured_doc/registry.py`
- `scripts/lib/structured_doc/result.py`
- `scripts/lib/structured_doc/findings.py`
- `scripts/lib/structured_doc/parser/spec.py`
- `scripts/lib/structured_doc/parser/handler.py`
- `scripts/lib/structured_doc/linter/spec.py`
- `scripts/lib/structured_doc/linter/handler.py`
- `scripts/lib/structured_doc/linter/rules/registry.py`
- `scripts/lib/structured_doc/linter/rules/required_field.py`
- `scripts/lib/structured_doc/linter/rules/reference_exists.py`
- `scripts/lib/structured_doc/linter/rules/line_count.py`
- `scripts/lib/structured_doc/differ/spec.py`
- `scripts/lib/structured_doc/differ/handler.py`
- `scripts/lib/structured_doc/validator/spec.py`
- `scripts/lib/structured_doc/validator/handler.py`
- `scripts/lib/structured_doc/cli.py`
- `scripts/lib/structured_doc/mcp_server.py`
- `scripts/lib/structured_doc/requirements.txt` (`pydantic`, `pyyaml`, `jsonschema`, MCP SDK)
- `tests/python/test_structured_doc_parser.py`
- `tests/python/test_structured_doc_linter.py`
- `tests/python/test_structured_doc_differ.py`
- `tests/python/test_structured_doc_validator.py`
- `tests/python/test_structured_doc_mcp.py`
- `tests/python/fixtures/structured_doc/`

**Crear (datos):**
- `rules/spec-md.lint.yaml`
- `rules/flow-yaml.lint.yaml`
- `schemas/spec-md.schema.json`
- (`schemas/flow.schema.json` ya existe en SPEC-AFG)

**Crear (Bash — envoltorio mínimo):**
- `scripts/savia-doc.sh` (≤ 15 líneas, invoca `python3 -m structured_doc`)

**Crear (skill — guía para el modelo):**
- `.opencode/skills/structured-document-tooling/SKILL.md`

**Crear (docs):**
- `docs/structured-doc.md`

**Modificar:**
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:** Python ≥ 3.10, `pydantic`, `pyyaml`, `jsonschema`, MCP SDK Python.

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Sobre-ingeniería: librería más compleja que sus consumidores.** Construir un framework genérico antes de tener varios consumidores reales puede generar abstracciones equivocadas. | Slice 1 implementa el tipo `spec-md` para validar la abstracción contra un caso real. Slice 2 añade `flow-yaml` para forzar generalidad. Si tras dos tipos la API es incoherente, se reescribe antes de promoverla a más tipos. |
| **Reglas declarativas insuficientemente expresivas.** Una regla compleja no se puede expresar en YAML y exige código. | Cada `check` es un nombre que apunta a una función Python. La complejidad vive en Python; el YAML solo configura. Si una regla es muy específica, se acepta como código Python registrado. |
| **Adopción lenta.** La librería existe pero los validadores antiguos siguen vivos durante meses. | Aceptado conscientemente. La migración reactiva (al tocar) es coherente con Rule #26. La librería aporta valor desde el primer tipo nuevo, no desde la migración total. |
| **Confusión con Spec-Driven Development de Savia.** Llamar a esto "Spec & Handler" podría confundir con SDD. | Documentar en `docs/structured-doc.md` la distinción: SDD es un metaproceso (escribir specs antes de código). Spec & Handler es un patrón arquitectónico (separar contrato de implementación). Son ortogonales y compatibles. |
| **Acoplamiento a Pydantic.** Si Pydantic v3 rompe compatibilidad, la librería entera necesita migración. | Versión pineada en `requirements.txt`. Tests cubren el comportamiento, no la versión específica. Migración controlada cuando llegue. |

---

## 7. Impacto en Roadmap

- **Toda spec futura que defina un nuevo tipo de documento estructurado tiene tooling gratis.** Crear un nuevo tipo de PBI, ADR, digest, code map, etc., se reduce a: schema + reglas + registro.
- **Coherencia de findings.** Cualquier agente que consuma findings de cualquier tipo de documento usa el mismo formato. El indexado por intención puede agregar findings cross-tipo.
- **Compatibilidad cross-frontend vía MCP.** El tooling está disponible para cualquier frontend MCP-compatible.
- **Validación cruzada.** Cuando una spec referencia otra (`depends_on: SPEC-X`), el linter puede validar que la spec referenciada existe y está en estado coherente. Esto antes era imposible sin código ad-hoc.
- **Refuerza Rule #26.** Un caso más donde Python aporta lo que bash no puede: parseo, validación, comparación estructural.
- **Posible adopción del patrón DESIGN.md más adelante.** Si en el futuro Savia necesita gestión de identidad visual (por ejemplo, para un Savia Web público), `design.md` se podría adoptar registrando un nuevo tipo `design-md` en la librería. Cero código nuevo.
- **Slices futuros opcionales:**
  - Auto-fix de reglas con `--fix` (cuando una regla tiene `suggestion`).
  - Formato unificado de reportes cross-tipo (`savia-doc lint-all`).
  - Integración con CI vía `verify-all-docs.yml`.
