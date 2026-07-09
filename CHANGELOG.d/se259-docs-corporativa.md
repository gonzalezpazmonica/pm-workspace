---
spec: SE-259
---

## SE-259 — Documentacion corporativa (5 slices)

### Slice 1 — Guia de estilo documental y lint

STYLE-GUIDE.md (111 lineas, 8 reglas). docs-lint.py/bash con deteccion de:
emojis (R1), exclamaciones (R2), vocabulario informal (R3), imagenes
embebidas (R4), cifras hardcodeadas (R5), enlaces rotos (R7).

### Slice 2 — Eliminacion de imagenes

4 PNG eliminados de images/. 14 referencias retiradas de README y docs.
Purga de historia via filter-repo (-4 MB del .git).

### Slice 3 — README multilingues sincronizados

6 README (es, en, ca, gl, eu, it) a paridad de contenido con banners
de cortesia. readme-drift-check.sh en scripts/.

### Slice 4 — Correccion de contenido

62 enlaces rotos corregidos. Conteos fosiles reemplazados por prosa
generica. AGENTS.md con frontmatter lang:es. Idiomas mezclados resueltos.

### Slice 5 — Reescritura de tono

Emojis eliminados del corpus documental (docs/, README, projects/).
Vocabulario informal reemplazado por registro formal. Procesado via
script deterministico docs-tone-rewrite.py.
