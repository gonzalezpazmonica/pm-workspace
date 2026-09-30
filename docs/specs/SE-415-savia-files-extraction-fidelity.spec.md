---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar ambas, PR por spec' (SE-414 y SE-415)"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L1
related_specs: [SE-413, SE-414]
origin: evaluación local del MVP de Savia Files (output/research/savia-files-mvp-evaluacion-20260930.md, huecos Q1-Q5 y E2)
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/workers/files
---

# SE-415 — Savia Files: fidelidad de extracción y cobertura honesta

## Problema

Con BM25, la recuperación sobre PDF y DOCX iguala a la de markdown (100 % en
fragmentos literales). Los fallos están en los bordes, y en dos casos la
cobertura que se declara es falsa:

| Id | Defecto medido |
|---|---|
| Q1 | Un PDF escaneado queda `READY` con 0 unidades y `skipped: []`: afirma que lo ha entendido y no tiene nada |
| Q2 | Un JSON de 200 000 claves queda `READY` con 50 000 unidades y `skipped: []`; un JSON muy anidado desborda la pila |
| Q3 | Las notas del presentador de PPTX no se extraen |
| Q4 | Las celdas XLSX se indexan sin nombre de columna ni de fila (`Inventario!D2: 4200`). La consulta "coste anual del servidor de copias" solo funciona si la hoja entera cabe en un chunk |
| Q5 | Un CSV o TXT en Windows-1252 (exportación típica de Excel en España) queda `ARCHIVE_ONLY` |
| E2 | Cada fichero lanza un worker nuevo: ~6 s de arranque por fichero. `files add` de 6 PDF tarda ~70 s, frente a 36 s en un proceso caliente |

## Solución

1. **Sin capa de texto (Q1).** El worker cuenta las páginas del PDF sin ninguna
   unidad (`skipped: page-without-text`). Regla general: si una revisión no
   extrae ninguna unidad, queda `ARCHIVE_ONLY` con los motivos (o `empty`), nunca
   `READY`.
2. **JSON (Q2).** Recorrido iterativo con profundidad máxima 64
   (`skipped: max-depth`). Todas las hojas se cuentan y las que pasan de 50 000 se
   declaran como `max-units`.
3. **Notas PPTX (Q3).** Tras Docling, python-pptx añade por diapositiva una unidad
   `kind: "notes"` con el texto de las notas (`Notas: …`) y el localizador de la
   diapositiva.
4. **Contexto XLSX (Q4).** Por hoja se detecta la cabecera: primera fila con dos o
   más celdas, todas de texto. Cada celda de datos se escribe como
   `Hoja!D2 · <cabecera de la columna> · <etiqueta de la fila>: <valor> (<fórmula>)`.
   La etiqueta de la fila es la primera celda de texto de esa fila. El localizador
   sigue siendo la celda.
5. **Windows-1252 (Q5).** Para las extensiones de texto, si los bytes no son UTF-8
   pero son Windows-1252 válido sin controles, el tipo se conserva con
   `encoding: "windows-1252"`. Se decodifica al extraer (`method: text-windows-1252`)
   y la descarga devuelve los bytes originales.
6. **Worker por lotes (E2).** `extract.py --batch` procesa varios ficheros en un
   solo proceso (JSON por línea, en orden) con timeout por fichero. `files add` y
   `FilesService.putMany` agrupan los ficheros ofimáticos en un solo worker.

## Criterios de aceptación

- **AC1** El PDF escaneado de prueba queda `ARCHIVE_ONLY` con
  `page-without-text ×1` y no aparece en RAG. Un TXT vacío queda `ARCHIVE_ONLY`
  (`empty`).
- **AC2** Un JSON de 200 000 claves declara `extracted: 50000` y
  `skipped: max-units ×150000` (`PARTIAL`). Un JSON de 200 niveles se extrae hasta
  el nivel 64 con `max-depth` (`PARTIAL`).
- **AC3** El PPTX de prueba con notas devuelve las 3 notas con su diapositiva, y
  `vault_rag` "cuánto tardó el último simulacro" cita la diapositiva 3.
- **AC4** En una hoja de 400 filas, "coste anual del servidor de copias" devuelve
  como primer hit el chunk que contiene la celda `D2` con su cabecera. La unidad
  `D2` contiene "Coste anual" y "Servidor de copias".
- **AC5** Un CSV en Windows-1252 con `Peña` queda `READY` con el texto correcto; la
  descarga es idéntica byte a byte.
- **AC6** `files add` de los 6 PDF del corpus lanza un solo worker y tarda al
  menos un 35 % menos que hoy (medido en la misma máquina).
- **AC7** La calidad del corpus de la evaluación no empeora (bm25: doc@1, chunk@1 y
  page@1 = 1,0 en PDF y DOCX). La suite existente sigue en verde.

## Entregables (rutas)

- Código: `projects/savia-vaults/workers/files/extract.py`, `projects/savia-vaults/src/files/extract.ts`,
  `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/types.ts`,
  `projects/savia-vaults/src/files/service.ts`, `projects/savia-vaults/src/cli/files.ts`.
- Tests: `projects/savia-vaults/tests/unit/files/extract.test.ts`, `projects/savia-vaults/tests/unit/files/store.test.ts`,
  `projects/savia-vaults/tests/unit/files/service.test.ts`, `projects/savia-vaults/tests/integration/files/rag-files.test.ts`,
  `projects/savia-vaults/tests/e2e/files.test.ts`, `projects/savia-vaults/tests/fixtures/files/continuidad.pptx`,
  `projects/savia-vaults/tests/fixtures/files/escaneado.pdf`, `projects/savia-vaults/tests/fixtures/files/inventario.xlsx`.
- Documentación: `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`,
  `CHANGELOG.d/se415-savia-files-extraction-fidelity.md`, `docs/propuestas/planning-state.json`,
  `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

Suite de savia-vaults: 561 tests en verde (546 con SE-414); `tsc` y `eslint` limpios.

| AC | Estado | Evidencia |
|---|---|---|
| AC1 | Cumple | PDF escaneado → `ARCHIVE_ONLY`, `page-without-text ×1`, fuera de RAG; TXT vacío → `ARCHIVE_ONLY` (`empty`) |
| AC2 | Cumple | 200 000 claves → 50 000 unidades + `max-units ×150000` (`PARTIAL`); 200 niveles → hasta el 64 + `max-depth ×1` |
| AC3 | Cumple | 3 notas con su diapositiva; `vault_rag` "cuánto tardó el último simulacro" cita la diapositiva 3 |
| AC4 | Cumple | Hoja de 400 filas: primer hit con `Inventario!D2 · Coste anual · Servidor de copias: 4200` |
| AC5 | Cumple | CSV Windows-1252 `READY` con `Peña`; descarga idéntica byte a byte |
| AC6 | Cumple | `files add` de los 6 PDF: 73,8 s → 37,1 s (−50 %), un solo worker, mismas unidades por fichero |
| AC7 | Cumple | Corpus en bm25: doc@1, chunk@1 y page@1 = 1,0 en PDF y DOCX (igual que antes) |

Hallazgos durante la implementación:

- El fixture de notas ya empezaba por "Notas:" y salía duplicado; el prefijo solo
  se añade si falta.
- En un lote que muere a mitad, los ficheros ya devueltos se guardan y el resto
  queda `FAILED` (test con worker falso).

## Esfuerzo

Agente 4 h · humano 45 min.

## Dependencias

SE-414 (mismo módulo; se implementa después, en PR aparte). Sin dependencias nuevas: python-pptx ya está en el venv.

## Fuera de alcance

OCR de documentos escaneados (seguirán `ARCHIVE_ONLY` hasta una spec de OCR). Worker persistente en el servidor MCP.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files add` | bash | idéntico |

### Verification protocol

- [ ] `vault_files put` de un PDF escaneado devuelve `ARCHIVE_ONLY` en ambos frontends

### Portability classification

- [x] **PURE_NODE** (+ worker Python opcional, fuera del frontend)
