---
lang: es
---

# SE-259 — Documentacion corporativa

**Status:** PROPOSED
**Fecha:** 2026-07-08
**Area:** Documentation
**Branch:** agent/se259-docs-corporativa
**Estimacion:** ~26h (5 slices)

## Origen

Auditoria documental 2026-07-08. Corpus: 1637 .md (1206 es, 421 en, 10 mixtos).
Hallazgos: 4 PNG (4 MB), 2509 emojis, 573 fosiles, 72 enlaces rotos,
6 README desincronizados, 10 docs con idioma mezclado.

## Slices

### Slice 1 — Guia de estilo y lint (3h)
- `docs/STYLE-GUIDE.md`: norma documental (registro formal, sin emojis,
  sin imagenes, un idioma por doc, sin cifras hardcodeadas)
- `scripts/docs-lint.py`: detector de 7 tipos de hallazgo
- `scripts/docs-lint.sh`: wrapper bash

### Slice 2 — Eliminacion de imagenes (3h)
- 47 referencias retiradas de 11 documentos
- `images/` eliminado (-4 MB)
- Purga de historia via filter-repo

### Slice 3 — Estrategia multilingue (4h)
- 6 README a paridad con banner de cortesia
- `scripts/readme-drift-check.sh`

### Slice 4 — Correccion de contenido (6h)
- Enlaces rotos: 62 corregidos
- Fosiles: conteos hardcodeados reemplazados por prosa
- AGENTS.md: frontmatter `lang: es`

### Slice 5 — Reescritura de tono (10h)
- Emojis: 2509 eliminados del corpus
- Vocabulario informal: corregido
- 1536 archivos procesados via script deterministico
