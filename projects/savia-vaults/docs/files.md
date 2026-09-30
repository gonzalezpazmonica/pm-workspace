# Savia Files (SE-413) — ficheros como fuente de conocimiento

Savia Files permite guardar en una cúpula ficheros originales (PDF, DOCX, PPTX,
XLSX, TXT, MD, CSV, JSON), extraer su texto indicando de dónde sale cada fragmento
y consultarlo con Savia RAG citando página, diapositiva, elemento o celda.

Este documento describe el MVP de SE-413. Qué queda fuera y por qué está al final.

## Índice

1. [Qué garantiza](#qué-garantiza)
2. [Activación](#activación)
3. [Modelo de datos](#modelo-de-datos)
4. [Almacén en disco](#almacén-en-disco)
5. [Detección de tipo](#detección-de-tipo)
6. [Extracción](#extracción)
7. [Escaneo antivirus](#escaneo-antivirus)
8. [Savia RAG](#savia-rag)
9. [MCP: `vault_files`](#mcp-vault_files)
10. [CLI: `savia-vaults files`](#cli-savia-vaults-files)
11. [Seguridad y permisos](#seguridad-y-permisos)
12. [Límites y variables de entorno](#límites-y-variables-de-entorno)
13. [Errores](#errores)
14. [Operación](#operación)
15. [Fuera del MVP](#fuera-del-mvp)

## Qué garantiza

| Garantía | Cómo |
|---|---|
| El original no se altera | Blob direccionado por SHA-256, modo `0400`; cada lectura verifica el hash (`INTEGRITY` si no casa) |
| Sustituir no destruye | `replaces` crea una revisión nueva; las anteriores siguen descargables por `revisionId` |
| Se cita la fuente exacta | Cada unidad extraída lleva un localizador; cada hit de RAG lleva documento, revisión y localizador |
| Nunca «READY» sin texto | Formato no soportado o worker ausente ⇒ `ARCHIVE_ONLY`, declarado |
| La cobertura se declara | `units`, `extracted`, `skipped[{reason,count}]` por revisión |
| Borrar es borrar | Bytes y extracciones se eliminan al instante; los chunks de RAG, en el siguiente sync |
| Misma ACL que la cúpula | `read` para consultar, `write` para guardar, borrar o reprocesar |

## Activación

Desactivado por defecto. Se activa por cúpula en `savia-vaults.domes.json`:

```json
{
  "name": "proyectos",
  "path": "./vaults/proyectos",
  "confidentiality": "N2",
  "rag": { "enabled": true },
  "files": { "enabled": true, "scan": "auto" }
}
```

| Campo | Valores | Defecto | Efecto |
|---|---|---|---|
| `files.enabled` | `true`/`false` | `false` | Sin él, `vault_files` y `savia-vaults files` responden `DISABLED` |
| `files.scan` | `auto`/`required`/`off` | `auto` | Ver [Escaneo antivirus](#escaneo-antivirus) |

Para que los ficheros aparezcan en `vault_rag`, la cúpula también necesita
`rag.enabled`.

### Worker de extracción (PDF, DOCX, PPTX, XLSX)

Los formatos ofimáticos se extraen con un proceso Python aparte. Instalación
(una vez, fuera del repo, con [uv](https://docs.astral.sh/uv/)):

```bash
uv venv ~/.savia-vaults/files-venv
uv pip install --python ~/.savia-vaults/files-venv/bin/python \
  --extra-index-url https://download.pytorch.org/whl/cpu \
  -r projects/savia-vaults/workers/files/requirements.lock
```

Ocupa ~1,5 GB (torch CPU). La primera conversión descarga los modelos de maquetación de
Docling a `~/.cache/huggingface`; después el worker funciona **sin red**
(`HF_HUB_OFFLINE=1`). Sin worker, TXT/MD/CSV/JSON se siguen extrayendo y el resto
queda `ARCHIVE_ONLY` con `skipped: [{reason: "worker-missing"}]`.

## Modelo de datos

```ts
FileDocument {
  id: "f_<16 hex>", name, tags[], confidentiality?: N1..N4,
  createdAt, updatedAt, currentRevision, revisions: FileRevision[]
}
FileRevision {
  id: "r_<16 hex>", sha256, size, mime, type, createdAt,
  extraction: { status, method, units, extracted, skipped[], error? }
}
ExtractUnit { locator, kind, text, formula? }
```

Estados de extracción:

| Estado | Significado | ¿En RAG? | ¿Descargable? |
|---|---|---|---|
| `PENDING` | Guardado, sin procesar todavía | No | Sí |
| `READY` | Extraído entero | Sí | Sí |
| `PARTIAL` | Extraído con omisiones (`skipped`: imágenes sin OCR, truncados, fórmulas sin valor calculado…) | Sí | Sí |
| `FAILED` | La extracción falló (`error`) | No | Sí |
| `ARCHIVE_ONLY` | Sin texto utilizable: formato no soportado, worker ausente o **ninguna unidad extraída** (PDF escaneado → `page-without-text`, fichero vacío → `empty`). Nunca `READY` sin unidades (SE-415) | No | Sí |
| `QUARANTINED` | El escáner lo detectó infectado; bytes borrados | No | No |

Localizadores:

| Formato | Localizador | Ejemplo de etiqueta |
|---|---|---|
| PDF | `{type:"page", page}` | `p. 2` |
| PPTX | `{type:"slide", slide}`; las notas del presentador van como `kind: "notes"` en su diapositiva (SE-415) | `diapositiva 2` |
| DOCX | `{type:"element", index}` (orden en el documento; DOCX no tiene páginas fijas) | `elemento 4` |
| XLSX | `{type:"cell", sheet, cell}` + `formula`. Texto con contexto (SE-415): `Inventario!D2 · Coste anual · Servidor de copias: 4200` | `Presupuesto!B3` |
| TXT/MD | `{type:"lines", from, to}` (bloques separados por línea en blanco, ≤ 60 líneas) | `líneas 3–4` |
| CSV | `{type:"row", row}` (fila 1 = cabecera) | `fila 2` |
| JSON | `{type:"key", path}` (una unidad por valor hoja) | `clave a.b[0]` |

## Almacén en disco

```
$SAVIA_FILES_HOME/<cúpula>/          (0700; def. ~/.savia-vaults/files/)
  docs/<documentId>.json             (0600) un manifiesto por documento (revisiones); escritura atómica
  blobs/<sha256>                     (0400) originales
  extract/<revisionId>.json          (0600) unidades extraídas, ligadas por digest a su revisión
  files.lock                         lock entre procesos (pid + timestamp; huérfano a los 10 min)
  manifest.json.migrated             copia del manifiesto único del MVP, tras migrar (SE-414)
```

- El almacén se niega a crearse dentro de un repo git (`UNSAFE_HOME`): contiene
  originales y texto extraído que no deben acabar versionados.
- Dos documentos con los mismos bytes comparten blob; el blob se borra cuando
  ninguna revisión lo referencia.
- Orden de escritura: blob → manifiesto del documento. Una caída entre ambos deja
  un blob huérfano, nunca un documento sin bytes. `files gc` lo limpia.
- **Un manifiesto por documento (SE-414)**:
  - cada escritura toca un solo fichero pequeño, así que el coste no crece con el número de documentos;
  - un manifiesto corrupto solo afecta a su documento: `list` lo omite y lo cuenta en `corrupt`, y `get` devuelve `INTEGRITY`;
  - con manifiestos corruptos, el borrado y `gc` no eliminan blobs, porque no se puede saber quién los referencia.
- **Migración automática**: un almacén del MVP (`manifest.json` único) se reparte
  en `docs/` al primer acceso, bajo lock. Se conserva `manifest.json.migrated` y se
  calcula el digest de las extracciones existentes.
- **Extracción ligada (SE-414)**: al escribir la extracción se guarda su SHA-256
  en la revisión (`extraction.digest`) y se verifica al leerla. Una extracción
  editada en disco devuelve `INTEGRITY`, no se publica en RAG y no impide
  sincronizar el resto de la cúpula. `files reprocess` la regenera.
- **Lock con espera (SE-414)**: si otro proceso está escribiendo (por ejemplo, la CLI
  con el servidor MCP activo), se espera hasta `SAVIA_FILES_LOCK_WAIT_MS` (def.
  10 s) antes de devolver `LOCKED`.
- El nombre visible nunca es una ruta: se rechazan `/`, `\`, `.`, `..`, caracteres
  de control, caracteres Unicode de formato (bidi como U+202E, zero-width como U+200B,
  BOM U+FEFF), U+2028/U+2029 y nombres de más de 255 bytes. Así, `factura‮fdp.exe`
  no puede mostrarse como `factuaexe.pdf`.
- El almacén resuelve symlinks antes de comprobar que no está dentro de git
  (SE-414; también `SAVIA_RAG_HOME`).

## Detección de tipo

La extensión propone el tipo y los bytes lo confirman:

| Extensión | Firma exigida |
|---|---|
| `.pdf` | empieza por `%PDF-` |
| `.docx` / `.pptx` / `.xlsx` | ZIP (`PK\x03\x04`) que contiene `word/document.xml` / `ppt/presentation.xml` / `xl/workbook.xml` |
| `.txt` `.md` `.markdown` `.csv` `.json` | UTF-8 válido sin bytes NUL; si no, Windows-1252 sin controles ni bytes sin asignar (SE-415, `encoding: "windows-1252"`) |

Si no casan, el tipo es `unknown` y la revisión queda `ARCHIVE_ONLY`. Un `.pdf` que
no es un PDF no llega al worker.

## Extracción

- **Texto (TypeScript, sin dependencias)**: TXT/MD por bloques de líneas, CSV con
  parser RFC 4180 (comillas, `""`, saltos de línea entre comillas, separador `;`
  detectado por cabecera) y JSON aplanado por clave. Un JSON inválido deja la
  revisión `FAILED`.
  - **Codificación (SE-415)**: los ficheros en Windows-1252 (típicos de Excel en
    español) se decodifican al extraer (`method: text-windows-1252`). La descarga
    devuelve siempre los bytes originales.
  - **JSON (SE-415)**: recorrido iterativo, sin límite de pila. Por encima de
    50 000 hojas las omitidas se declaran (`max-units ×N`, `PARTIAL`), y los
    subárboles más hondos de 64 niveles como `max-depth`.
- **Worker Python** (`workers/files/extract.py`):
  - PDF, DOCX y PPTX con Docling, **sin OCR**. Las tablas salen en markdown; las
    imágenes se cuentan en `skipped` como `image-no-ocr`, y las páginas de PDF sin
    ninguna unidad de texto como `page-without-text` (SE-415).
  - **Notas del presentador (SE-415)**: python-pptx añade una unidad `notes` por
    diapositiva con notas; Docling no las extrae.
  - **Contexto de celda (SE-415)**: por hoja se detecta la cabecera (la primera fila
    no vacía, si tiene dos o más celdas y todas son texto). Cada celda de datos lleva
    el nombre de su columna y la etiqueta de su fila (la primera celda de texto de
    la fila). Así, "coste anual del servidor de copias" encuentra `D2` en una hoja de
    400 filas.
  - **Por lotes (SE-415)**: el worker procesa varios ficheros en un solo proceso
    (`--batch`, una línea JSON por fichero) y carga Docling una vez. Cada fichero
    tiene su límite de tiempo. Si el proceso muere a mitad, los ficheros ya devueltos
    se guardan y el resto queda `FAILED`. `files add` de varios ficheros usa un solo
    lote: los 6 PDF del corpus de evaluación pasan de 73,8 s a 37,1 s.
  - XLSX con openpyxl en modo solo lectura: valor calculado guardado en el fichero
    y fórmula por celda. **No se ejecutan macros ni se recalculan fórmulas.** Si
    una fórmula no tiene valor guardado, se cuenta como
    `formula-without-cached-value` (la revisión queda `PARTIAL`).
  - **Guardia de descompresión (SE-414)**: antes de lanzar el worker, se lee el
    directorio central del ZIP de DOCX, PPTX y XLSX, sin descomprimir. Se rechaza
    (`FAILED`, `error: "decompression-limit: …"`) si:
    - la suma descomprimida declarada supera `SAVIA_FILES_MAX_UNZIPPED_BYTES` (def. 256 MiB);
    - una entrada de más de 1 MiB comprime más de 200:1;
    - hay más de 10 000 entradas;
    - el ZIP es inválido.

    Medido: un DOCX de 1 MB que se descomprime a 414 MB pasaba 180 s en el worker
    con 1,2 GB; ahora se rechaza en 3 ms. Si el ZIP miente en sus cabeceras, la
    lectura de Python se limita al tamaño declarado.
  - **Un worker a la vez (SE-414)**: cada worker usa ~1,2 GB. Un semáforo por
    proceso limita los simultáneos (`SAVIA_FILES_WORKERS`, def. 1). Medido: 4 `put`
    de PDF a la vez pasaban de 4 workers y 4,5 GB a 1 worker y 1,15 GB, a cambio
    de serializar (17 s → 39 s). El límite no se aplica entre procesos distintos.
  - Aislamiento: proceso aparte con entorno reducido (`PATH`, `HOME`, `LANG`,
    sin red de modelos), timeout (`SAVIA_FILES_EXTRACT_TIMEOUT_MS`, def. 300 s,
    `SIGKILL`), salida máxima de 64 MiB, 50 000 unidades y 20 000 caracteres por
    unidad (`truncated`).
  - Las unidades se validan al volver del worker; las inválidas se descartan como
    `invalid-unit`.
- El texto extraído es **dato no confiable**: nunca se ejecuta ni se interpreta
  como instrucciones.

Tiempos medidos en la máquina de desarrollo (RTX 2070, CPU para Docling):

- PDF, DOCX o PPTX de 1–3 páginas en un proceso nuevo: 4,5–12 s, casi todo carga de
  modelos (~6 s). Dentro de un lote, 2–6 s por PDF (13 s el de 12 páginas).
- XLSX: ~0,3 s. Texto: < 10 ms.

## Escaneo antivirus

Con ClamAV (`clamscan`), antes de extraer:

| `files.scan` | Hay `clamscan` | No hay `clamscan` |
|---|---|---|
| `auto` (def.) | Escanea | No escanea; sigue |
| `required` | Escanea; si el escáner falla, rechaza | `put` rechaza con `SCAN_REQUIRED` **antes de guardar** |
| `off` | No escanea | No escanea |

- Infectado ⇒ `QUARANTINED`: se borran bytes y extracción, se conserva el registro
  con la firma en `error`, y no entra en RAG ni se descarga.
- Si el escáner falla en `auto`, la revisión se procesa y se añade
  `skipped: [{reason: "scan-error"}]` (queda `PARTIAL`, no oculta el fallo).
- Si el escáner falla en `required` durante un `put`, la revisión nueva se deshace.
- Se busca en `SAVIA_FILES_CLAMSCAN`, `/usr/bin/clamscan`, `/usr/local/bin/clamscan`
  y `/opt/homebrew/bin/clamscan`. Instalación en Debian/Ubuntu:
  `sudo apt install clamav && sudo freshclam`.

## Savia RAG

- Los documentos con extracción `READY` o `PARTIAL` (solo su revisión vigente)
  entran en el indexer como fuentes virtuales `files/<documentId>`, junto a las
  notas markdown de la cúpula.
- El hash de la fuente combina SHA-256 y id de revisión, nombre,
  confidencialidad y versión del troceado (`files-v1`): solo se re-embeben los
  ficheros que cambian.
- Troceado: agrupa unidades consecutivas hasta `chunkChars` sin cruzar **página,
  diapositiva ni hoja**, así que un chunk de PDF cita una sola página. Una unidad
  mayor que `chunkChars` se parte sin perder texto. El texto embebido lleva de
  cabecera `nombre › localizador`.
- Cada hit lleva `source` (también en la respuesta `lean`):

```json
{
  "dome": "proyectos", "path": "files/f_3c…", "heading": "contrato.pdf › p. 2",
  "text": "Cláusula 7. La penalización por retraso será del 2% mensual.",
  "source": { "kind": "file", "documentId": "f_3c…", "revisionId": "r_9a…",
              "name": "contrato.pdf", "locator": { "type": "page", "page": 2 } }
}
```

  `locatorEnd` aparece cuando el chunk abarca varias unidades (celdas, filas,
  líneas).
- Frescura: `put`, `delete` y `reprocess` por MCP programan el sync de la cúpula;
  por CLI, la siguiente búsqueda detecta el cambio y sincroniza dentro del
  presupuesto inline, o lo hace `rag sync` (cron). `rag status` cuenta los
  ficheros pendientes en `pendingDocs`.
- Confidencialidad: un documento con nivel superior al de su cúpula no se indexa
  (CRIT-001), aunque `put` ya lo impide.

## MCP: `vault_files`

Una sola tool con `action`. Respuestas en JSON compacto.

| `action` | Permiso | Parámetros | Devuelve |
|---|---|---|---|
| `put` | write | `dome`, `name`, `contentBase64` (≤ 20 MiB), `tags?`, `confidentiality?`, `replaces?` | `documentId`, `revisionId`, `sha256`, `size`, `mime`, `status`, `units`, `extracted`, `skipped`, `error?` |
| `list` | read | `dome`, `tag?` | `{documents: [...], corrupt}`: resumen por documento (id, nombre, estado, tamaño, revisiones) y número de manifiestos ilegibles |
| `get` | read | `dome`, `id` | documento con todas sus revisiones y cobertura |
| `text` | read | `dome`, `id`, `revisionId?`, `locator?` (filtro parcial, p. ej. `{"type":"page","page":2}`), `maxChars?` (def. 12 000) | `units[]`, `truncated` |
| `download` | read | `dome`, `id`, `revisionId?` | `contentBase64`, `sha256`, `mime`, `name` |
| `delete` | write | `dome`, `id` | `{deleted, revisions}` |
| `reprocess` | write | `dome`, `id`, `revisionId?` | estado de extracción nuevo |

Ejemplo:

```json
{ "action": "put", "dome": "proyectos", "name": "contrato.pdf",
  "contentBase64": "JVBERi0xLjcK…", "tags": ["contrato"] }
```

Para ficheros de más de 20 MiB, usar la CLI (`files add` / `files get`), que no
pasa por base64.

## CLI: `savia-vaults files`

Módulo propio del dispatcher: no carga el servidor MCP ni la capa de conocimiento.
Todos los subcomandos aceptan `--domes-file <fichero>` (def. `savia-vaults.domes.json`).

```bash
savia-vaults files add contrato.pdf presupuesto.xlsx --dome proyectos --tags contrato,2026
savia-vaults files add contrato-v2.pdf --dome proyectos --replaces f_3c…   # revisión nueva
savia-vaults files list --dome proyectos [--tag contrato] [--json]
savia-vaults files show f_3c… --dome proyectos          # revisiones y cobertura
savia-vaults files text f_3c… --dome proyectos          # [p. 2] Cláusula 7…
savia-vaults files get f_3c… --dome proyectos -o copia.pdf [--revision r_…] [--force]
savia-vaults files rm f_3c… --dome proyectos
savia-vaults files reprocess f_3c… --dome proyectos     # tras instalar el worker o ClamAV
savia-vaults files gc --dome proyectos                  # huérfanos tras una caída
savia-vaults rag search "penalización por retraso" --domes proyectos
```

- `add` usa el nombre base del fichero de origen; la ruta local no se guarda.
- `add` con varios ficheros valida todos los nombres y tamaños antes de guardar
  nada y los extrae en un solo worker (SE-415).
- `get` no sobrescribe sin `--force` y escribe con modo `0600`.
- Salida con error: código 1 (`3` si hay otra escritura en curso, `LOCKED`).
- La CLI es de uso local del operador y no aplica la ACL de red. Por MCP, cada
  acción se autoriza contra la cúpula.

## Seguridad y permisos

- ACL: la de la cúpula (SE-291). `list/get/text/download` exigen `read`;
  `put/delete/reprocess` exigen `write`. Sin `read`, ninguna acción devuelve datos.
- Confidencialidad: `put` con `confidentiality` superior al nivel de la cúpula ⇒
  `POLICY_DENIED`.
- Entradas que fallan cerradas sin tocar disco: nombre con ruta, tamaño sobre el
  límite, base64 inválido, `revisionId` con formato no válido, escaneo obligatorio
  sin escáner.
- Nada del cliente decide rutas físicas: los blobs se nombran por hash y las
  extracciones por id de revisión validado (`r_<16 hex>`).
- Los bytes se leen siempre verificando SHA-256.

## Límites y variables de entorno

| Variable | Defecto | Uso |
|---|---|---|
| `SAVIA_FILES_HOME` | `~/.savia-vaults/files` | Raíz del almacén (fuera de git) |
| `SAVIA_FILES_PYTHON` | `~/.savia-vaults/files-venv/bin/python` | Intérprete del worker |
| `SAVIA_FILES_CLAMSCAN` | rutas estándar | Binario de ClamAV |
| `SAVIA_FILES_MAX_BYTES` | 104 857 600 (100 MiB) | Tamaño máximo por fichero |
| `SAVIA_FILES_MAX_DOCS` | 10 000 | Documentos por cúpula |
| `SAVIA_FILES_EXTRACT_TIMEOUT_MS` | 300 000 | Timeout del worker |
| `SAVIA_FILES_MAX_TRANSFER_BYTES` | 20 971 520 (20 MiB) | `put`/`download` por MCP |
| `SAVIA_FILES_MAX_UNITS` | 50 000 | Unidades por extracción (worker) |
| `SAVIA_FILES_MAX_UNZIPPED_BYTES` | 268 435 456 (256 MiB) | Tamaño descomprimido máximo de un DOCX/PPTX/XLSX |
| `SAVIA_FILES_WORKERS` | 1 | Workers Python simultáneos por proceso |
| `SAVIA_FILES_LOCK_WAIT_MS` | 10 000 | Espera máxima por el lock de escritura |

## Errores

| Código | Cuándo |
|---|---|
| `NOT_FOUND` | Cúpula, documento, revisión o extracción inexistente; revisión en cuarentena |
| `INVALID_INPUT` | Nombre, base64, `revisionId`, confidencialidad o acción no válidos |
| `TOO_LARGE` | Fichero o transferencia sobre el límite |
| `LIMIT` | Cúpula con el máximo de documentos |
| `LOCKED` | Otra escritura siguió en curso durante toda la espera |
| `INTEGRITY` | El blob no coincide con su SHA-256, la extracción no coincide con su digest, o el manifiesto del documento está corrupto |
| `POLICY_DENIED` | Confidencialidad superior a la cúpula |
| `UNSAFE_HOME` | `SAVIA_FILES_HOME` dentro de un repo git |
| `SCAN_REQUIRED` | `files.scan: required` sin escáner o con el escáner fallando |
| `DISABLED` | La cúpula no tiene `files.enabled` |

## Operación

- **Copia de seguridad**: `$SAVIA_FILES_HOME` no está en git; inclúyelo en la copia de
  `~/.savia-vaults/`. El índice RAG se puede regenerar desde los ficheros
  (`rag sync --rebuild`); los originales no.
- **Tras instalar el worker o ClamAV**: `files reprocess` sobre los documentos
  `ARCHIVE_ONLY` con `worker-missing`.
- **Tras una caída**: `files gc`.
- **Manifiesto de documento corrupto** (`corrupt > 0` en `list`): restaurar
  `docs/<id>.json` desde la copia de seguridad. Si no hay copia, borrar ese fichero
  y ejecutar `files gc`. Mientras haya corruptos, `gc` solo limpia temporales.
- **Extracción con `INTEGRITY`**: `files reprocess <id>` la regenera desde el original.
- **Tests**: `npx vitest run tests/unit/files tests/integration/files tests/e2e/mcp-files.test.ts tests/e2e/files.test.ts`.
  Los que necesitan el worker se omiten solo si no existe el intérprete configurado.

## Fuera del MVP

Aprobado como MVP recortado. Queda para specs posteriores, una por slice:

- cifrado en reposo y gestión de claves;
- subida reanudable por HTTP (tus) y streaming autenticado;
- manifiestos en git privado, journal durable y publicación por snapshot;
- digestión LLM, grafo de afirmaciones, citas mixtas y visor;
- revocación, restauración verificada y purga de derivados y copias;
- OCR, audio/vídeo, backend S3 y conectores.
