---
name: biblio-search
description: >
  Administra referencias bibliográficas con búsqueda por DOI, autor, año.
  Permite importar desde BibTeX, generar citas en múltiples formatos.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /biblio-search {proyecto} {subcommand} {args}

## Subcomandos

- `add doi {doi}` — Añade referencia consultando DOI (CrossRef)
- `add bibtex {path}` — Importa referencias desde fichero .bib
- `add manual {json}` — Añade referencia manual (JSON)
- `search {termino}` — Busca por autor, palabra clave, año
- `list [--filter]` — Lista todas las referencias con filtros opcionales
- `cite {id} {formato}` — Genera cita (APA, IEEE, Vancouver)
- `export {formato}` — Exporta todas a .bib u otro formato

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/bibliography/` si no existe
3. Crear `references.json` inicial si no existe
4. Validar JSON si fichero existe

## Ejecución

1. 🏁 Banner: `══ /biblio-search — {proyecto}/{subcommand} ══`
2. **add doi**: Consultar CrossRef con validación de formato DOI
3. **add bibtex**: Parsear fichero .bib, extraer entradas, añadir con ID único
4. **add manual**: Validar JSON, asignar ID (BIB-NNNN), almacenar
5. **search**: GREP en references.json por autor/keyword/año con score relevancia
6. **list**: Tabla con ID, autor, título, año, tipo | opciones: `--type journal|book|conference`
7. **cite**: Generar formato solicitado (APA, IEEE, Vancouver) para ID específico
8. **export**: Guardar todas las referencias en formato .bib bajo bibliography/
9. Escribir agent-note: `projects/{proyecto}/agent-notes/biblio-{accion}-{fecha}.md`
10. ✅ Banner fin con ID referencia si es add, ruta .bib si es export

## Output

```
projects/{proyecto}/bibliography/references.json
projects/{proyecto}/bibliography/references.bib (si export)
```

## Reglas

- Validar formato DOI: `\d{4,}/\S+` antes de consultar CrossRef
- Cada referencia tiene: id, doi, author, title, year, type, url, raw_bibtex
- search devuelve top 10 resultados ordenados por relevancia
- Formatos válidos para cite: APA, IEEE, Vancouver (no soportados otros)
- export SIEMPRE crea fichero nuevo con timestamp: `references-YYYYMMDD.bib`
