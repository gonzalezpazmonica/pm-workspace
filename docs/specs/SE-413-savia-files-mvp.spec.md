---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): alcance 'MVP recortado'; dependencias autorizadas: venv Python con docling + openpyxl (ClamAV lo instala la operadora); PRs en Draft para su revisión"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L2
related_specs: [SE-410, SE-411, SE-412, SE-291]
origin: línea de investigación de Savia Labs (privada); este documento es la versión mínima aprobada para implementar
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-413 — Savia Files (MVP): ficheros como fuente de conocimiento en las cúpulas

## Problema

Las cúpulas solo entienden markdown. Un contrato en PDF, un presupuesto en XLSX o
una presentación en PPTX no se pueden guardar en una cúpula de forma controlada ni
consultar con Savia RAG: hay que convertirlos a mano, se pierde la referencia a la
página o celda de origen y no hay forma limpia de sustituirlos o borrarlos.

## Solución (MVP)

Un módulo `src/files/` en savia-vaults que:

1. **Guarda el original íntegro** por cúpula en `$SAVIA_FILES_HOME`
   (def. `~/.savia-vaults/files/<dome>/`), fuera de cualquier repo git, con hash
   SHA-256, directorios `0700` y ficheros `0600`. Sustituir crea una revisión nueva;
   el original nunca se reescribe.
2. **Extrae el contenido con localizador**: PDF por página, PPTX por diapositiva,
   DOCX por elemento, XLSX por hoja y celda (valor y fórmula, sin ejecutar macros
   ni recalcular), TXT/MD por líneas, CSV por fila, JSON por clave. La extracción
   declara cobertura (unidades extraídas / omitidas y por qué).
3. **Publica el contenido en Savia RAG** como fuente adicional de la cúpula: los
   hits de un fichero llevan documento, revisión y localizador para citar y abrir
   el original en la página o celda.
4. **Borra de verdad**: borrar un documento elimina bytes, extracciones y, en el
   siguiente sync, sus chunks del índice RAG.

Fuera del MVP (siguen en la investigación de Labs): cifrado en reposo, subida
reanudable (tus), OCR, audio/vídeo, backend S3, digestión LLM, grafo de claims,
visor web, restauración verificada y conectores.

## Contrato técnico

### Almacén (`src/files/store.ts`)

```
$SAVIA_FILES_HOME/<dome>/
  manifest.json            # autoridad: documentos y revisiones (escritura atómica)
  blobs/<sha256>           # originales inmutables (0400 tras escribir)
  extract/<revisionId>.json # unidades + cobertura de cada revisión
  files.lock               # lock de escritura entre procesos
```

```ts
interface FileRevision {
  id: string; sha256: string; size: number; mime: string; type: FileType; createdAt: string;
  extraction: { status: 'PENDING' | 'READY' | 'PARTIAL' | 'FAILED' | 'ARCHIVE_ONLY' | 'QUARANTINED';
                method: string; units: number; extracted: number;
                skipped: { reason: string; count: number }[]; error?: string };
}
interface FileDocument {
  id: string; name: string; tags: string[]; confidentiality?: 'N1'|'N2'|'N3'|'N4';
  createdAt: string; updatedAt: string; currentRevision: string; revisions: FileRevision[];
}
type Locator =
  | { type: 'page'; page: number } | { type: 'slide'; slide: number }
  | { type: 'element'; index: number } | { type: 'cell'; sheet: string; cell: string }
  | { type: 'lines'; from: number; to: number } | { type: 'row'; row: number }
  | { type: 'key'; path: string };
interface ExtractUnit { locator: Locator; kind: string; text: string; formula?: string }
```

`PENDING` es el estado entre guardar y extraer. El tipo se decide por extensión y se
confirma con la firma de los bytes (`%PDF-`, ZIP con la parte OOXML esperada, UTF-8
válido sin NUL para texto); si no casan, `unknown` ⇒ `ARCHIVE_ONLY`. Los blobs se
direccionan por SHA-256: dos documentos con los mismos bytes comparten blob y el
borrado solo lo elimina cuando nadie más lo referencia.

Límites MVP (configurables por env): 100 MiB por fichero, 10 000 documentos por
cúpula, 300 s de extracción, 20 MiB por transferencia MCP en base64. Nombre de
fichero ≤ 255 bytes, sin rutas; la ruta física nunca viene del cliente.

### Extracción (`src/files/extract.ts` + `workers/files/extract.py`)

- TXT/MD/CSV/JSON: TypeScript, sin dependencias.
- PDF/DOCX/PPTX: Docling (sin OCR) en un proceso Python aparte
  (`$SAVIA_FILES_PYTHON`, def. `~/.savia-vaults/files-venv/bin/python`), con
  timeout, salida acotada y entorno reducido.
- XLSX: openpyxl en el mismo worker; valores y fórmulas por celda, sin macros.
- Formato no soportado o worker ausente: se guarda como `ARCHIVE_ONLY`
  (descargable, sin conocimiento) y lo dice; nunca `READY` sin extracción.
- El contenido extraído es dato no confiable: nunca se ejecuta ni se interpreta.

### Escaneo opcional (`src/files/scan.ts`)

Bloque `files.scan` de la cúpula: `auto` (def.; escanea si `clamscan` existe),
`required` (sin escáner, rechaza) u `off`. Infectado ⇒ `QUARANTINED`: bytes
borrados, registro conservado, nunca en RAG.

### Savia RAG (`src/rag/indexer.ts`)

Los documentos activos de la cúpula entran al indexer como fuentes virtuales
`files/<documentId>`; el hash de la fuente combina SHA-256 de la revisión y
versión del troceado, así que solo se re-embeben ficheros cambiados. Cada chunk
agrupa unidades consecutivas hasta `chunkChars` y conserva su rango de
localizadores. `RagHit.source = { kind: 'file', documentId, revisionId, name, locator }`
viaja también en la respuesta `lean`. Un documento borrado o sustituido deja de
servir la revisión anterior tras el siguiente sync (disparadores de SE-410).

### Superficies

- MCP: una sola tool `vault_files` con `action`:
  `put` (base64 ≤ 20 MiB, `replaces` para nueva revisión) · `list` · `get` ·
  `text` (unidades por localizador, acotado por `maxChars`) · `download`
  (base64 ≤ 20 MiB) · `delete` · `reprocess`. Permisos: `put`/`delete`/`reprocess`
  exigen `write` en la cúpula; el resto `read`. Una nota con confidencialidad
  superior a la cúpula se rechaza (CRIT-001).
- CLI: `savia-vaults files add|list|show|text|get|rm|reprocess --dome <nombre>`
  (módulo propio en el dispatcher).
- Configuración por cúpula: bloque `files` en `savia-vaults.domes.json`
  (`enabled`, `scan`); desactivado por defecto.

### Entregables (rutas)

- Código: `projects/savia-vaults/src/files/*.ts`, `projects/savia-vaults/workers/files/extract.py`,
  `projects/savia-vaults/src/cli/files.ts`, `projects/savia-vaults/src/cli/index.ts`,
  `projects/savia-vaults/src/server/mcp.ts`, `projects/savia-vaults/src/registry/domes.ts`,
  `projects/savia-vaults/src/rag/*.ts`.
- Tests: `projects/savia-vaults/tests/unit/files/*.test.ts`,
  `projects/savia-vaults/tests/integration/files/*.test.ts`, `projects/savia-vaults/tests/e2e/mcp-files.test.ts`,
  `projects/savia-vaults/tests/fixtures/files/*`.
- Documentación: `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/README.md`,
  `projects/savia-vaults/CHANGELOG.md`, `.claude/skills/savia-vaults/SKILL.md`,
  `projects/savia-vaults/workers/files/requirements.lock`,
  `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Criterios de aceptación

- **AC1** Guardar un fichero devuelve `documentId`, `revisionId` y SHA-256; la
  descarga devuelve exactamente los mismos bytes (hash idéntico).
- **AC2** Sustituir crea revisión nueva y el original anterior sigue intacto; RAG
  solo sirve la revisión vigente tras el sync.
- **AC3** Un PDF de 2 páginas se consulta por RAG y el hit cita la página correcta;
  un XLSX devuelve valor y fórmula de la celda; PPTX cita la diapositiva; DOCX el elemento.
- **AC4** Toda extracción informa `units`, `extracted` y `skipped`; un formato no
  soportado queda `ARCHIVE_ONLY` y no aparece en RAG.
- **AC5** Borrar elimina bytes y extracción al instante y sus chunks del índice
  en el siguiente sync; `get`/`download`/`text` devuelven NOT_FOUND.
- **AC6** Sin permiso `read` sobre la cúpula, ninguna acción devuelve datos; `put`
  sin `write` se rechaza; confidencialidad superior a la cúpula se rechaza.
- **AC7** Nombres con rutas (`../x`, `/etc/passwd`), tamaños sobre límite y base64
  inválido fallan cerrados sin tocar disco.
- **AC8** Con `files.scan: required` y sin escáner se rechaza; con escáner, el fichero
  de prueba EICAR queda `QUARANTINED` y sin bytes.
- **AC9** Los tests existentes siguen en verde; los que requieren el worker Python
  se omiten solo si el intérprete configurado no existe (dependencia declarada).

## Esfuerzo

| Slice | Contenido | Agente | Humano |
|---|---|---|---|
| F1 | almacén, manifiesto, revisiones, borrado, límites, ACL | 3 h | 45 min |
| F2 | extracción TS + worker Python + escaneo opcional | 3 h | 45 min |
| F3 | fuente de Savia RAG con localizadores | 2 h | 30 min |
| F4 | MCP, CLI, documentación | 2 h | 30 min |

## Dependencias

SE-410/411/412 (Savia RAG), SE-291 (ACL por cúpula). Python 3.12 con docling
2.131.0 y openpyxl 3.1.5 (versiones en `workers/files/requirements.lock`).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files` | bash | idéntico |

### Verification protocol

- [ ] `vault_files` responde igual en ambos frontends

### Portability classification

- [x] **PURE_NODE** (+ worker Python opcional, fuera del frontend)
