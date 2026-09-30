---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar ambas, PR por spec' (SE-414 y SE-415)"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L2
related_specs: [SE-413, SE-410]
origin: evaluación local del MVP de Savia Files (output/research/savia-files-mvp-evaluacion-20260930.md, huecos S1-S7 y E1)
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-414 — Savia Files: robustez y seguridad del MVP

## Problema

La evaluación local de SE-413 midió siete defectos de robustez y seguridad y un
problema de escala:

| Id | Defecto medido |
|---|---|
| S1 | Un DOCX de 1 MB que se descomprime a 414 MB mantiene el worker 180 s al 100 % con 1,2 GB hasta el timeout (defecto 300 s) |
| S2 | 4 `put` simultáneos lanzan 4 workers y 4,5 GB de RAM; no hay límite |
| S3 | Se aceptan nombres con caracteres invisibles o bidi (`factura‮fdp.exe` se ve como `factuaexe.pdf`) |
| S4 | `SAVIA_FILES_HOME` (y `SAVIA_RAG_HOME`) como symlink dentro de un repo git pasa la comprobación |
| S5 | El texto extraído no está ligado a su revisión: editado en disco, se sirve a RAG |
| S6 | Una escritura con otro proceso escribiendo falla al instante con `LOCKED` |
| S7 | Un manifiesto truncado deja toda la cúpula inutilizable |
| E1 | Cada operación reescribe el manifiesto entero: 5,8 ms/doc con 600 documentos y 49,6 ms/doc con 3000 (ingesta cuadrática) |

## Solución

1. **Límite de descompresión (S1).** Antes de lanzar el worker, se lee el
   directorio central del ZIP de DOCX, PPTX y XLSX. Se rechaza si:
   - la suma declarada descomprimida supera `SAVIA_FILES_MAX_UNZIPPED_BYTES` (def. 256 MiB);
   - alguna entrada de más de 1 MiB tiene una razón superior a 200;
   - hay más de 10 000 entradas;
   - el ZIP es inválido.

   El resultado es `FAILED` con `error: "decompression-limit: …"` y el worker no se
   lanza. Si las cabeceras mienten, la librería `zipfile` de Python limita la
   lectura al tamaño declarado.
2. **Límite de workers (S2).** Un semáforo por proceso para el worker Python
   (`SAVIA_FILES_WORKERS`, def. 1); las extracciones de texto no esperan.
3. **Nombres (S3).** Se rechazan también los caracteres Unicode de formato (`Cf`:
   bidi, zero-width, BOM) y los separadores de línea y párrafo.
4. **Home real (S4).** `ensureSafeHome` resuelve con `realpath` el ancestro
   existente más cercano antes de buscar `.git`. Lo usan Savia RAG y Savia Files.
5. **Extracción ligada (S5).** `extraction.digest` = SHA-256 del JSON de
   extracción, guardado en el manifiesto al escribirla y verificado al leerla
   (`INTEGRITY`). Una extracción sin digest (MVP) recibe digest en la migración.
6. **Lock con espera (S6).** La escritura reintenta el lock hasta
   `SAVIA_FILES_LOCK_WAIT_MS` (def. 10 000) con espera creciente; solo después
   devuelve `LOCKED`.
7. **Manifiesto por documento (S7, E1).**
   - `docs/<documentId>.json` (0600, escritura atómica) sustituye a `manifest.json`: una escritura toca un solo fichero.
   - `list` lee el directorio con caché por `mtime` y tamaño.
   - Un fichero de documento corrupto no afecta a los demás: `list` lo omite y lo cuenta (`corrupt`), y `get` devuelve `INTEGRITY`.
   - Migración automática y atómica bajo lock: `manifest.json` se reparte en ficheros por documento y se conserva como `manifest.json.migrated`.

## Criterios de aceptación

- **AC1** Una bomba DOCX de 1 MB que se descomprime a 414 MB queda `FAILED`
  (`decompression-limit`) en < 1 s y sin lanzar el worker. Los fixtures legítimos
  se siguen extrayendo.
- **AC2** Con `SAVIA_FILES_WORKERS=1`, 4 `put` de PDF simultáneos nunca tienen más
  de 1 worker vivo (medido) y los 4 terminan `READY`.
- **AC3** Se rechazan con `INVALID_INPUT` los nombres con U+202E, U+200B, U+2066,
  U+FEFF, U+2028 y U+2029.
- **AC4** Un home que es symlink a un directorio dentro de un repo git devuelve
  `UNSAFE_HOME` en Savia Files y en Savia RAG.
- **AC5** Una extracción editada en disco devuelve `INTEGRITY` en `text` y la
  revisión no se publica en RAG.
- **AC6** Con el lock tomado por otro proceso vivo que lo suelta a los 300 ms, la
  escritura espera y termina bien. Si no lo suelta, devuelve `LOCKED` al pasar el
  tiempo de espera.
- **AC7** Con un fichero de documento corrupto, el resto de la cúpula se lista,
  descarga e indexa; `list` informa `corrupt: 1`.
- **AC8** Un almacén MVP (`manifest.json`) se migra al primer acceso sin perder
  documentos, revisiones ni extracciones, y se conserva `manifest.json.migrated`.
- **AC9** Guardar y extraer un TXT con 3000 documentos en la cúpula cuesta menos de
  8 ms por documento (hoy 49,6 ms), y el coste no crece con N (±50 % entre 600 y 3000).
- **AC10** La suite existente sigue en verde.

## Entregables (rutas)

- Código: `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/extract.ts`,
  `projects/savia-vaults/src/files/types.ts`, `projects/savia-vaults/src/files/zip-guard.ts`,
  `projects/savia-vaults/src/files/service.ts`, `projects/savia-vaults/src/files/rag-source.ts`,
  `projects/savia-vaults/src/rag/store.ts`, `projects/savia-vaults/src/cli/files.ts`.
- Tests: `projects/savia-vaults/tests/unit/files/store.test.ts`, `projects/savia-vaults/tests/unit/files/extract.test.ts`,
  `projects/savia-vaults/tests/unit/files/zip-guard.test.ts`, `projects/savia-vaults/tests/unit/files/service.test.ts`,
  `projects/savia-vaults/tests/unit/files/rag-source.test.ts`, `projects/savia-vaults/tests/unit/rag/store.test.ts`,
  `projects/savia-vaults/tests/integration/files/rag-files.test.ts`, `projects/savia-vaults/tests/e2e/mcp-files.test.ts`,
  `projects/savia-vaults/tests/unit/files/craft-zip.ts`.
- Documentación: `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`,
  `CHANGELOG.d/se414-savia-files-hardening.md`, `docs/propuestas/planning-state.json`,
  `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

Suite de savia-vaults: 546 tests en verde (529 antes); `tsc` y `eslint` limpios.
Medido con la batería de la evaluación (`output/research/savia-files-mvp-evaluacion-20260930.md`):

| AC | Estado | Evidencia |
|---|---|---|
| AC1 | Cumple | La bomba real (DOCX de 1 MB → 414 MB) queda `FAILED` en 3 ms sin worker (antes 180 s y 1,2 GB); los fixtures pasan |
| AC2 | Cumple | Test con worker falso: pico de 1 worker vivo. Real: 4 PDF simultáneos, 1 worker y 1,15 GB (antes 4 y 4,5 GB); tiempo total 17 s → 39 s por la serialización |
| AC3 | Cumple | U+202E, U+200B, U+2066, U+FEFF, U+2028 y U+2029 rechazados |
| AC4 | Cumple | Symlink a un directorio dentro de git ⇒ `UNSAFE_HOME` en Files y en RAG |
| AC5 | Cumple | `INTEGRITY` en `text`; en RAG la fuente se omite y el resto de la cúpula se indexa |
| AC6 | Cumple | Espera a un lock que se suelta a los 300 ms; `LOCKED` al agotar la espera |
| AC7 | Cumple | `list` con un documento corrupto devuelve los demás y `corrupt: 1` |
| AC8 | Cumple | Migración de un almacén MVP con blob, extracción y digest calculado; `manifest.json.migrated` |
| AC9 | Tope sí; «no crece con N» solo en operación aislada | Guardar + extraer con 3000 documentos: 49,6 → **2,2 ms/doc**. Por operación aislada, la extracción cuesta 0,40 ms con 0 documentos y 0,32 ms con 3000, y el alta 0,35 ms con 3000. En una ingesta continua de 3000 en un proceso la media sube 1,0 → 2,2 ms (+124 %), fuera del ±50 %. No crece por el almacén, que es plano aislado; la causa exacta no está medida |
| AC10 | Cumple | Suite completa en verde |

Hallazgos durante la implementación:

- El congelado de los documentos cacheados destapó una mutación de un objeto
  compartido (`docOfRevision` sin `documentId`); ahora devuelve una copia.
- Una extracción manipulada lanzaba dentro del sync de RAG y habría tumbado la
  sincronización de toda la cúpula; ahora se omite solo esa fuente.
- Coste por consulta `vault_rag` con 3000 ficheros: 35 ms → 43 ms p50 (se lee un
  manifiesto por documento con caché por `stat`).

## Esfuerzo

Agente 4 h · humano 45 min.

## Dependencias

SE-413 (MVP). Sin dependencias nuevas.

## Fuera de alcance

Cifrado en reposo, journal durable y manifiestos en git privado (siguientes delta-specs de L33).
Límite de workers entre procesos distintos.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files`, `vault_rag`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files` | bash | idéntico |

### Verification protocol

- [ ] `vault_files list` devuelve `corrupt` en ambos frontends

### Portability classification

- [x] **PURE_NODE**
