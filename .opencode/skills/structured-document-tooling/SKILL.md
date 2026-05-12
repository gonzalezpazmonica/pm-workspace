---
name: structured-document-tooling
description: Canonical tooling for Savia structured documents (specs, flows, rules) via scripts/lib/structured_doc/.
---

# Skill: structured-document-tooling

Tooling canonico para documentos estructurados de Savia.
Libreria: scripts/lib/structured_doc/. Spec: SPEC-STRUCTURED-DOC-TOOLING.
Guia completa: docs/structured-doc.md

## Cuando usar

- Validar documento estructurado antes de PR.
- Comparar dos versiones y detectar regresiones.
- Registrar nuevo tipo de documento.
- Integrar validacion en CI.

## Comandos CLI

  bash scripts/savia-doc.sh lint     <type> <file> [--human]
  bash scripts/savia-doc.sh diff     <type> <file_a> <file_b> [--regression-only] [--human]
  bash scripts/savia-doc.sh validate <type> <file> [--human]
  bash scripts/savia-doc.sh list-types

Sin wrapper: PYTHONPATH=scripts/lib python3 -m structured_doc lint <type> <file>

## Tipos registrados (Slice 1)

type_id    | estrategia        | schema                      | reglas
-----------|-------------------|-----------------------------|-----------------------
spec-md    | frontmatter-prose | schemas/spec-md.schema.json | rules/spec-md.lint.yaml

## Reglas spec-md

id                     | sev     | que verifica
-----------------------|---------|-----------------------------------------------
missing-required-field | error   | task_id, sprint, estado presentes
broken-spec-reference  | error   | depende_de apunta a fichero .spec.md existente
spec-too-long          | warning | no supera 500 lineas

## Codigos de salida

0 = OK
1 = errores/regresion/invalido
2 = error de uso
3 = fallo interno

## API Python

  from structured_doc import lint_document, diff_documents, validate_document
  result = lint_document("spec-md", "path/to/doc.spec.md")
  if result.ok:
      report = result.value   # FindingsReport con .summary y .findings
  else:
      print(result.error_kind, result.message)

Toda operacion devuelve Result[T]: nunca lanza excepciones.

## Registrar tipo nuevo

1. schemas/mi-tipo.schema.json
2. rules/mi-tipo.lint.yaml
3. register_type(...) en scripts/lib/structured_doc/_bootstrap.py
4. bash scripts/savia-doc.sh list-types para verificar

## Tests

  pytest tests/python/test_structured_doc_*.py -v

## No-Goals Slice 1

- MCP server: Slice 2
- Tipo flow-yaml: Slice 2
- Migracion de validadores existentes: adopcion gradual
