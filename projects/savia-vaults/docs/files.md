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
8b. [Cifrado en reposo y claves](#cifrado-en-reposo-y-claves)
8c. [Ledger, journal y receipts](#ledger-journal-y-receipts)
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
| N3/N4 nunca en claro en disco (SE-417) | Original, texto extraído, metadatos e índice RAG cifrados; copias temporales en memoria |
| Borrado criptográfico (SE-417) | Borrar destruye la clave de la revisión: ninguna copia del almacén sirve ya |
| Historia y autoridad verificables (SE-418) | Cada operación es un commit en un repo git privado de la cúpula; un manifiesto tocado a mano da `INTEGRITY` |
| Reintentar es seguro (SE-418) | `idempotencyKey`: el mismo resultado, sin revisión nueva; una operación cortada se completa o se cancela sola |
| Comprobante de cada operación (SE-418) | Receipt firmado (Ed25519) con el commit del ledger |

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

Requiere `git` en el PATH (SE-418; sin él, las escrituras dan `UNSUPPORTED` y las
lecturas siguen funcionando) y Node ≥ 22.13.

Para que los ficheros aparezcan en `vault_rag`, la cúpula también necesita
`rag.enabled`.

### Dependencias: instalación sin consola ni administrador (SE-416)

Savia Files usa dos piezas externas. Las instala `savia-vaults files setup` (o Savia
desde el chat con `vault_files action: "setup"`) en `~/.savia-vaults/tools`, **sin
permisos de administrador** y sin que la persona use la consola:

| Componente | Qué hace | Tamaño | Sin él |
|---|---|---|---|
| Lector de documentos | Python gestionado + Docling + openpyxl (lock con hashes) | ~1,5 GB (+0,5 GB de modelos en la primera extracción) | PDF, DOCX, PPTX y XLSX quedan `ARCHIVE_ONLY` (`worker-missing`) |
| Antivirus | ClamAV oficial de Cisco Talos, desempaquetado sin instalar, con firmas propias | ~150 MB | Los ficheros no se analizan (`scan: auto`) o se rechazan (`scan: required`) |

```bash
savia-vaults files status              # qué hay y qué falta, en frases llanas
savia-vaults files setup               # instala ambos (o --extractor / --antivirus)
savia-vaults files setup --uninstall   # desinstala
```

Cómo funciona:

- **Versiones fijadas**: ClamAV 1.5.4, uv 0.12.21 y Python 3.12. URL y SHA-256
  están escritos en el código; si una descarga no coincide, se aborta sin tocar
  nada. Los paquetes Python se instalan con `--require-hashes` desde
  `workers/files/requirements.lock`, generado desde `requirements.in` con
  `constraints.txt` (cómo regenerarlo, en la cabecera del lock).
- **Atómica e idempotente**: todo se prepara en un directorio temporal y se activa
  solo si funciona; ante un fallo sigue la instalación anterior. Repetirla no
  descarga nada (medido: 0,5 s).
- **Sin root**: el paquete `.deb` de ClamAV se lee en TypeScript (formato `ar` +
  `tar.gz`) y solo se extraen `clamscan`, `freshclam`, sus librerías y los
  certificados de firma. Los binarios traen rutas fijas a `/usr/local`, que se
  redirigen en cada llamada con `LD_LIBRARY_PATH` y `CVD_CERTS_DIR`.
- **Plataformas**: solo Linux x86_64, probado. En macOS, Windows o Linux arm64,
  `status` dice que todavía no se puede instalar automáticamente.
- Medido en la máquina de desarrollo: instalación completa en 31 s (depende de la
  red); lote de un PDF, un XLSX y el fichero de prueba EICAR con antivirus
  obligatorio en 28 s (PDF y XLSX `READY`, EICAR `QUARANTINED`).

Prioridad del intérprete del worker: `SAVIA_FILES_PYTHON`, después el lector
gestionado y, por compatibilidad, `~/.savia-vaults/files-venv` (instalación manual
de SE-413). La primera conversión descarga los modelos de maquetación de Docling a
`~/.cache/huggingface`; después el worker funciona **sin red** (`HF_HUB_OFFLINE=1`).

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
  ledger/                            repo git privado, sin remoto: la autoridad (SE-418)
  ledger.json                        marca de que el ledger ya importó los documentos previos
  journal.db                         (0600) operaciones en curso, outbox y receipts (node:sqlite, WAL)
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

Con ClamAV (`clamscan`), antes de extraer. Todos los ficheros de un lote se analizan
en **una sola llamada**, porque cada llamada carga 3,3 millones de firmas (~10 s y
~1 GB de RAM medidos):

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
- Qué ClamAV se usa: el gestionado por `files setup` (SE-416); si no hay, el de
  `SAVIA_FILES_CLAMSCAN`, y si no, el del sistema (`/usr/bin/clamscan`,
  `/usr/local/bin/clamscan`, `/opt/homebrew/bin/clamscan`).
- **Firmas al día sin intervención (SE-416)**: al instalar se descargan (108 MB,
  verificadas). Después, si la última comprobación correcta tiene más de 24 h, cada
  análisis lanza `freshclam` en segundo plano (como mucho una vez cada 4 h), sin
  esperar.
- **Firmas caducadas (más de 7 días)**: `required` rechaza con un mensaje que lo
  explica; `auto` analiza igualmente, lo anota en el resultado y `status` avisa de
  que no protege frente a amenazas recientes.

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

## Cifrado en reposo y claves

(SE-417) Las cúpulas **N3 y N4 se cifran siempre**. Las N1/N2 se cifran si su
configuración lleva `"files": {"enabled": true, "encryption": true}`. Una cúpula
cifrada no vuelve a estar en claro, aunque se quite la opción.

### Ficheros grandes (SE-421)

El almacén trabaja **en streaming**: ni guardar ni descargar cargan el fichero en
memoria.

- **Alta:** `files add` y la API HTTP (SE-422) escriben un temporal del almacén
  mientras calculan el SHA-256 y el tipo. En cúpulas cifradas cifran frame a frame
  (mismo formato SVF1). El lock solo se toma para registrar la revisión: una subida
  de gigas no bloquea al resto.
- **Descarga:** `files get` escribe en streaming a un `.part`, que solo se renombra
  si todo llegó y el SHA-256 cuadra.
- **Rango (`--range`):**
  - en cifradas se autentica cada frame, pero se descifra desde el principio (el
    coste crece con el desplazamiento);
  - en claras el rango no se verifica: `files verify --deep` comprueba el fichero
    entero.
- **Antivirus:**
  - se pide a clamscan que lea hasta su máximo (4 000 MB); con sus valores por
    defecto decía «OK» de lo que no había leído;
  - un fichero cifrado por encima del tope de extracción se analiza por stdin,
    descifrado al vuelo, sin copia en claro;
  - por encima de 4 000 MB no se analiza (`too-large-to-scan`), y `scan: required`
    lo rechaza.
- **Extracción:** solo hasta `SAVIA_FILES_MAX_EXTRACT_BYTES`.
- **Memoria medida** (máximo del proceso en `putMany` + descarga completa):

| Tamaño | N2: guardar / descargar | N3: guardar / descargar | Memoria máxima N2 / N3 |
|---|---|---|---|
| 10 MB | 150 / 51 ms | 310 / 91 ms | 129 / 155 MiB |
| 1 GiB | 3,2 / 4,8 s | 9,5 / 8,0 s | 142 / 160 MiB |
| 2 GiB | 6,4 / 9,5 s | 18,1 / 16,1 s | 141 / 160 MiB |

### Qué se cifra y cómo

Todo con libsodium (`libsodium-wrappers-sumo`), sin criptografía propia:

| Qué | Cómo | Clave |
|---|---|---|
| Original (`blobs/<revisionId>.svf`) | `crypto_secretstream_xchacha20poly1305` en frames de 1 MiB; `TAG_FINAL` obligatorio; se verifica el SHA-256 al descifrar | DEK de la revisión |
| Texto extraído (`extract/<revisionId>.json`) | XChaCha20-Poly1305 (IETF) | DEK de la revisión |
| Manifiesto (`docs/<id>.json`) | Sellado entero; en claro solo `{id, v}`: ni nombre, ni etiquetas, ni SHA-256 | subclave `meta` de la cúpula |
| Índice RAG (chunks, vectores, BM25) | Sellado por fichero; el manifiesto de la generación solo tiene ids opacos, hashes y contrato | subclave `index` de la cúpula |

- **Datos asociados**: todo va autenticado con `{schemaVersion, domeId, documentId,
  revisionId, artifactKind}` en JSON canónico (RFC 8785). Mover un fichero cifrado a
  otro documento, reordenar o truncar frames, o cambiar un bit, falla cerrado con
  `INTEGRITY`.
- **Claves**: una DEK aleatoria por revisión, envuelta con la clave de la cúpula
  (KEK). Las subclaves `meta` e `index` se derivan de la KEK (`crypto_kdf`).
- **Sin deduplicación** en cúpulas cifradas: cada revisión tiene su blob. El nombre
  es el id de revisión, que es aleatorio.
- **Copias temporales**: el lector de documentos y el antivirus necesitan el fichero
  en claro. Se descifra en `/dev/shm` (memoria, `0700`/`0600`) y se borra al
  terminar, también si el worker falla o se agota el tiempo. Sin `/dev/shm`, se usa
  `<cúpula>/.work`.
- **Coste medido** (fichero de 10 MB, máquina de desarrollo):
  - guardar: 54 → 177 ms;
  - descargar: 24 → 58 ms;
  - consulta `vault_rag` con 300 ficheros: 6 ms en ambos casos.

  Un PDF real en N3 con el lector real queda `READY`, cita su página y deja 0
  ficheros con texto en claro.

### Dónde están las claves

```
~/.savia-vaults/keys/files/          (0700; SAVIA_FILES_KEYS_HOME; nunca dentro de git)
  <cúpula>/kek                       clave de la cúpula (32 bytes, 0600)
  <cúpula>/wraps/<revisionId>.json   clave de cada revisión, envuelta con la KEK
  recovery.pub                       clave pública de recuperación (tras exportar)
```

**Modelo de amenazas.**

- **Protege frente a:** copia o filtración del almacén, del índice RAG o de sus
  backups, y frente a la manipulación de cualquiera de ellos.
- **No protege frente a:** alguien con acceso a tu cuenta de usuario, que puede leer
  la KEK; ni frente a un proceso de Savia comprometido, que ve el texto en memoria.

### Borrado criptográfico

Borrar una revisión (o un documento) destruye su envoltura en `wraps/`. A partir de
ese momento, ninguna copia del almacén, tampoco un backup antiguo, permite recuperar
el original, aunque se tenga la KEK.

Hay una excepción: las **copias nocturnas de claves** hechas antes del borrado siguen
conteniendo esa envoltura hasta que rotan (`SAVIA_BACKUP_RETENTION`, def. 30 días).
Durante ese tiempo, quien tenga el fichero de recuperación y la frase podría
recuperarlo. Es el precio de poder restaurar tras perder el disco.

### Recuperación (hazlo en cuanto cifres una cúpula)

Sin copia de las claves, perder el disco es perder los ficheros cifrados. `files
status` avisa mientras no exista:

```bash
savia-vaults files keys export [--dir <carpeta nueva>]    # o vault_files action:"keys", op:"export"
```

Crea una carpeta con tres ficheros:

- `savia-claves.recovery`: la clave privada de recuperación y las KEK, cifradas con
  la frase (Argon2id + secretbox);
- `frase-de-recuperacion.txt`: 10 palabras + 4 dígitos (≈ 63 bits), generada una vez;
- `LEEME.txt`: qué hacer.

La frase nunca viaja en la respuesta ni por el chat. Guarda la frase en el gestor de
contraseñas y el fichero fuera del ordenador, en otro sitio, y borra la carpeta.

**Copia nocturna de claves**: con el fichero de recuperación creado, el backup
nocturno guarda cada noche las KEK y las envolturas selladas para la clave pública
de recuperación (`files keys backup`). Esa copia incluye los ficheros subidos después
de exportar, y solo la abre quien tenga el fichero y la frase.

**Restaurar tras perder el disco**:

```bash
tar -xzf savia-files-<fecha>.tar.gz -C ~/.savia-vaults/              # almacén
savia-vaults files keys import savia-claves.recovery \
  --phrase-file <fichero con la frase> --backup savia-keys-<fecha>.sealed
```

Probado: restaurar en directorios vacíos devuelve bytes idénticos, también de
ficheros subidos después de exportar.

### Rotación y migración

- `savia-vaults files keys rotate --dome <c>` (o `vault_files action:"keys", op:"rotate"`,
  rol admin): genera una KEK nueva, re-envuelve las DEK y re-sella manifiestos e
  índice RAG **sin descifrar los originales ni volver a embeber**. Si se corta, se
  repite y termina. Después, la KEK antigua ya no abre nada.
- `savia-vaults files encrypt --dome <c>` (o `action:"encrypt"`): cifra una cúpula
  existente. En N3/N4 también ocurre sola en la primera escritura. Reutiliza los
  vectores del índice (no re-embebe), borra los ficheros en claro y las generaciones
  del índice que quedaran en claro. Es reanudable.
- **Sin la KEK** en una cúpula cifrada: todas las operaciones dan `KEY_MISSING` con
  un mensaje que remite a la restauración. Nunca se crea una clave nueva en silencio.

## Ledger, journal y receipts

(SE-418) Hasta SE-417, el estado de la cúpula era un JSON por documento reescrito en
sitio. Ahora hay tres piezas:

- **Ledger** (`<cúpula>/ledger/`): la autoridad.
  - Es un repo git local **sin remoto**, sin hooks, que no lee la configuración
    global ni las variables `GIT_*`.
  - Cada operación es **un commit** con los manifiestos compactos de los documentos
    tocados (`manifests/<id>.json`) y su intent (`intents/<operationId>.json`).
  - Borrar deja `tombstones/<id>.json`.
  - Un documento existe si su manifiesto está en el ledger.
- **Journal** (`journal.db`, `node:sqlite`): lo que aún no está en git.
  - Guarda operaciones pendientes (con lease y proceso dueño), el outbox y los
    receipts.
  - Si se pierde o se corrompe, se aparta a `journal.db.corrupt-*` y se reconstruye
    desde los intents del ledger. Se pierden los receipts antiguos, no los datos.
- **Receipts**: comprobante de cada `put`, `delete` y `reprocess`.
  - Contenido: `{operationId, dome, kind, refs, status, commitSha, manifestHash, at, keyId, signature}`.
  - Se firman con Ed25519 sobre `"savia-files-receipt-v1\n" + JSON canónico`.
  - La clave de firma es propia: `~/.savia-vaults/keys/files/_signing/`, 0600,
    separada de las de cifrado. `registry.json` guarda las públicas: rotar
    (`files keys rotate-signing`) conserva las anteriores.
  - La copia sellada de claves (SE-417) incluye el registro y las claves de firma.

**Qué hay en el ledger (y qué no).**

- **En claras:** ids, estado de extracción y su digest, tamaño, tipo y SHA-256 del
  original.
- **En cifradas:** solo ids, el SHA-256 del **cifrado** y el estado. Ni tipo, ni
  tamaño, ni el SHA-256 del original.
- **Nunca:** nombres, etiquetas, texto, rutas ni claves.
- **Límite conocido:** la historia git conserva los ids y hashes de lo borrado. En
  claras, eso incluye el SHA-256 del original. Purgar la historia es una spec
  posterior.

**Qué pasa si algo se corta.**

| Situación | Resultado |
|---|---|
| Git falla al confirmar | La llamada devuelve `COMMIT_PENDING` con el `operationId`; nunca `READY`. El siguiente acceso (o el reintento con la misma `idempotencyKey`) la completa |
| El proceso muere tras escribir el documento y antes del commit | La siguiente escritura, o `files recover`, completa el commit (queda marcado `(recuperada)`) |
| El proceso muere antes de escribir nada | La operación queda `failed` (`ABORTED`); el blob que hubiera quedado lo limpia `files gc` |
| Una revisión quedó `PENDING` | El outbox la extrae en la siguiente escritura o con `files recover`, una sola vez |
| Alguien edita `docs/<id>.json` a mano | `INTEGRITY` al leerlo; `files verify` lo lista |
| Alguien añade un remoto al ledger | Las escrituras fallan con `UNSAFE_HOME` hasta quitarlo |

Mientras una operación está abierta, los lectores ven sus documentos (el journal
dice que se están escribiendo).

**Coste medido (AC8)**, frente a SE-417:

| | Antes | SE-418 |
|---|---|---|
| `put` 1 KB, p50, N2 / N3 | 1 / 3 ms | 28 / 39 ms |
| `put` 10 MB, p50, N2 / N3 | 57 / 176 ms | 93 / 272 ms |
| `putMany` de 300 ficheros, N2 / N3 | 232 / 569 ms (sin commits) | 711 / 1 056 ms (1 commit) |
| `list` de ~320 documentos en un proceso nuevo, N2 / N3 | 10 / 17 ms | 21 / 24 ms |

El coste fijo, unos 27 ms por operación, son tres llamadas a git. `node:sqlite` es
experimental en Node 22: por eso se exige Node ≥ 22.13, y el aviso puede aparecer
en stderr.

## MCP: `vault_files`

Una sola tool con `action`. Respuestas en JSON compacto.

| `action` | Permiso | Parámetros | Devuelve |
|---|---|---|---|
| `put` | write | `dome`, `name`, `contentBase64` (≤ 20 MiB), `tags?`, `confidentiality?`, `replaces?`, `idempotencyKey?` | `documentId`, `revisionId`, `sha256`, `size`, `mime`, `status`, `units`, `extracted`, `skipped`, `error?`, `operationId`, `receipt` |
| `delete` | write | `dome`, `id`, `idempotencyKey?` | `{deleted, revisions, operationId, receipt}` |
| `reprocess` | write | `dome`, `id`, `revisionId?`, `idempotencyKey?` | estado de extracción nuevo, `operationId`, `receipt` |
| `operation` (SE-418) | read | `dome`, `operationId` | `{operation, receipt?}` |
| `log` (SE-418) | read | `dome`, `limit?` | últimas operaciones: id, tipo, estado, commit, fecha |
| `verify` (SE-418) | read | `dome`, `deep?` | `{ok, documents, operations, receipts, problems[{code, id?}]}` |
| `recover` (SE-418) | write | `dome` | completa operaciones cortadas y extrae lo pendiente |
| `policy` (SE-419) | write + poder escribir el documento | `dome`, `id`, `confidentiality?`, `readers?`, `writers?` (array o `null` = hereda), `expectedPolicyVersion?`, `idempotencyKey?` | `{documentId, confidentiality?, readers?, writers?, policyVersion, operationId, receipt}` |
| `list` | read | `dome`, `tag?` | `{documents: [...], corrupt}`: resumen por documento (id, nombre, estado, tamaño, revisiones) y número de manifiestos ilegibles |
| `get` | read | `dome`, `id` | documento con todas sus revisiones y cobertura |
| `text` | read | `dome`, `id`, `revisionId?`, `locator?` (filtro parcial, p. ej. `{"type":"page","page":2}`), `maxChars?` (def. 12 000) | `units[]`, `truncated` |
| `download` | read | `dome`, `id`, `revisionId?` | `contentBase64`, `sha256`, `mime`, `name` |
| `status` (SE-416) | — (sin cúpula) | — | por componente: `state`, versión, disco, antigüedad de firmas, `message`; `summary` con frases para la persona; `job` si hay una instalación en curso |
| `encrypt` (SE-417) | write | `dome` | `{documents, revisions}` migrados; re-sella el índice |
| `keys` (SE-417) | admin* | `op: "rotate"` + `dome`, `op: "export"` + `dir?`, u `op: "rotate-signing"` (SE-418) | rotación, carpeta del fichero de recuperación (la frase queda en un fichero, nunca en la respuesta) o clave de firma nueva |
| `setup` (SE-416) | admin de la máquina* | `components?` (`extractor`, `antivirus`; def. ambos) | arranca la instalación **en segundo plano** y vuelve al instante; el progreso se consulta con `status` |

\* Sin usuarios configurados (servidor local de una persona), cualquiera. Con
usuarios, hace falta el rol `admin` sobre la cúpula por defecto: instalar software
en la máquina no es un permiso de cúpula.

Ejemplo:

```json
{ "action": "put", "dome": "proyectos", "name": "contrato.pdf",
  "contentBase64": "JVBERi0xLjcK…", "tags": ["contrato"] }
```

Para ficheros de más de 20 MiB, usar la CLI (`files add` / `files get`), que no
pasa por base64 y trabaja en streaming (SE-421). Ver [Ficheros grandes](#ficheros-grandes-se-421).

## CLI: `savia-vaults files`

Módulo propio del dispatcher: no carga el servidor MCP ni la capa de conocimiento.
Todos los subcomandos aceptan `--domes-file <fichero>` (def. `savia-vaults.domes.json`).

```bash
savia-vaults files add contrato.pdf presupuesto.xlsx --dome proyectos --tags contrato,2026
savia-vaults files add contrato-v2.pdf --dome proyectos --replaces f_3c…   # revisión nueva
savia-vaults files list --dome proyectos [--tag contrato] [--json]
savia-vaults files show f_3c… --dome proyectos          # revisiones y cobertura
savia-vaults files text f_3c… --dome proyectos          # [p. 2] Cláusula 7…
savia-vaults files get f_3c… --dome proyectos -o copia.pdf [--revision r_…] [--force] [--range 0-1048575]
savia-vaults files rm f_3c… --dome proyectos
savia-vaults files reprocess f_3c… --dome proyectos     # tras instalar el worker o ClamAV
savia-vaults files gc --dome proyectos                  # huérfanos tras una caída
savia-vaults files verify --dome proyectos [--deep]     # ledger, manifiestos, originales, receipts (SE-418)
savia-vaults files log --dome proyectos [--limit 20]    # operaciones: id, tipo, estado, commit
savia-vaults files recover --dome proyectos             # completa operaciones cortadas
savia-vaults files policy f_3c… --dome proyectos --readers ana,luis --writers ana   # SE-419
savia-vaults files policy f_3c… --dome proyectos --readers-inherit --level N2
savia-vaults files keys rotate-signing                  # clave de firma de receipts nueva
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
  `put/delete/reprocess/policy` exigen `write`. Sin `read`, ninguna acción devuelve datos.
- **Permisos por documento (SE-419)**, además de los de la cúpula:
  - **Nivel:** el nivel del documento (o, si no tiene, el de la cúpula) se aplica
    con la misma tabla de roles: lectura N3 ⇒ `writer`, N4 ⇒ `admin`.
    - Al guardar, un documento nunca supera su cúpula, así que esto solo actúa si
      la cúpula se **reclasifica a la baja**.
    - En `vault_rag`, lo que supera el nivel de la cúpula ya lo omite el indexador
      para todos.
  - **Listas `readers` y `writers`:** solo restringen.
    - `null` o ausente hereda de la cúpula; `[]` deja solo a `admin`.
    - Estar en `writers` implica poder leer.
    - Ser autor no da permisos.
  - **Qué ve quien no tiene permiso:**
    - `list` omite lo que no puede leer;
    - `get`, `text` y `download` dan `NOT_FOUND`, sin revelar que existe;
    - escribir sin permiso da `POLICY_DENIED` (o `NOT_FOUND` si ni siquiera lo lee).
  - **Cambiar la política:** `vault_files action:"policy"` (`id`,
    `confidentiality?`, `readers?`, `writers?` con array o `null`,
    `expectedPolicyVersion?`, `idempotencyKey?`) o `files policy`.
    - Puede hacerlo quien puede escribir el documento.
    - Es una operación del ledger con receipt.
    - Si otro la cambió antes, `CONFLICT`.
    - Las listas viven en el payload (sellado en cúpulas cifradas), nunca en el
      ledger; `get` solo las muestra a quien puede escribir.
  - **`vault_rag`:** filtra cada hit de fichero con la política **actual** del
    documento. Un cambio vale en la siguiente consulta, sin sync, y un documento
    borrado deja de salir antes del siguiente sync.
    - La cúpula declara `filtered: n` (sin ids).
    - Coste medido con 300 ficheros: `vault_rag` p50 ~7–8 ms con o sin filtro;
      `list` ~2 ms.
  - **Sin usuarios configurados** (servidor local de una persona), todo está
    permitido; las listas se guardan y se aplican en cuanto haya usuarios.
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
| `SAVIA_FILES_MAX_BYTES` | 1 073 741 824 (1 GiB) | Tamaño máximo por fichero (SE-421: como mucho 10 GiB). `files.maxBytes` en la cúpula lo baja para esa cúpula |
| `SAVIA_FILES_MAX_EXTRACT_BYTES` | 268 435 456 (256 MiB) | Por encima, el fichero se guarda y se descarga pero no se extrae (`ARCHIVE_ONLY`, `too-large-to-extract`) |
| `SAVIA_FILES_MAX_DOCS` | 10 000 | Documentos por cúpula |
| `SAVIA_FILES_EXTRACT_TIMEOUT_MS` | 300 000 | Timeout del worker |
| `SAVIA_FILES_MAX_TRANSFER_BYTES` | 20 971 520 (20 MiB) | `put`/`download` por MCP |
| `SAVIA_FILES_MAX_UNITS` | 50 000 | Unidades por extracción (worker) |
| `SAVIA_FILES_MAX_UNZIPPED_BYTES` | 268 435 456 (256 MiB) | Tamaño descomprimido máximo de un DOCX/PPTX/XLSX |
| `SAVIA_FILES_WORKERS` | 1 | Workers Python simultáneos por proceso |
| `SAVIA_FILES_LOCK_WAIT_MS` | 10 000 | Espera máxima por el lock de escritura |
| `SAVIA_TOOLS_HOME` | `~/.savia-vaults/tools` | Dónde instala `files setup` (nunca dentro de un repo git) |
| `SAVIA_FILES_KEYS_HOME` | `~/.savia-vaults/keys/files` | Claves de las cúpulas cifradas (SE-417; nunca dentro de git) |
| `SAVIA_BACKUP_UPLOAD_KEYS` | `false` | Backup nocturno: subir también la copia **sellada** de claves a Nextcloud (solo en configuración local) |
| `SAVIA_NODE` | node del PATH o de nvm | Node que usa el backup nocturno para `files keys backup` |
| `SAVIA_VAULTS_CLI` | `projects/savia-vaults/dist/cli/index.js` | CLI que usa el backup nocturno |

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
| `UNSUPPORTED` | `files setup` en una plataforma sin instalación automática |
| `COMMIT_PENDING` | El ledger no pudo confirmar (git falló). La operación sigue pendiente y se completa en el siguiente acceso; reintentar con la misma `idempotencyKey` es seguro |
| `IDEMPOTENCY_CONFLICT` | La `idempotencyKey` ya se usó con otra petición |
| `CONFLICT` | `policy` con `expectedPolicyVersion` distinta de la actual (otro la cambió antes) |
| `KEY_MISSING` | Cúpula cifrada sin su clave (restaurar con `files keys import`), o copia de claves sin fichero de recuperación |

## Operación

- **Copia de seguridad (SE-417)**: `scripts/vaults-backup-cron.sh` añade cada noche
  `savia-files-<fecha>.tar.gz` (sin locks ni temporales; las cúpulas cifradas viajan
  cifradas) y lo sube a Nextcloud como las cúpulas.
  - **Claves**, por otro canal, en `backups/keys/`:
    - con fichero de recuperación, copia sellada (`savia-keys-<fecha>.sealed`);
    - sin él, copia local `0600` y `AVISO` en el log.
  - **Las claves no se suben** salvo que la configuración local
    (`~/.savia-vaults/nextcloud.env`) lleve `SAVIA_BACKUP_UPLOAD_KEYS=true`, y
    entonces solo la copia sellada. Por defecto no se suben.
  - El índice RAG se puede regenerar (`rag sync --rebuild`); los originales no.
- **Tras `files setup`**: `files reprocess` sobre los documentos `ARCHIVE_ONLY`
  con `worker-missing`.
- **Tras una caída**: `files recover` y `files gc`.
- **Tras restaurar un backup**: `files verify --deep` en cada cúpula debe dar `OK`.
  El tar nocturno incluye `ledger/` y `journal.db`; si el journal llegara
  inconsistente, se reconstruye solo desde el ledger.
- **Manifiesto de documento corrupto** (`corrupt > 0` en `list`): restaurar
  `docs/<id>.json` desde la copia de seguridad. Si no hay copia, borrar ese fichero
  y ejecutar `files gc`. Mientras haya corruptos, `gc` solo limpia temporales.
- **Extracción con `INTEGRITY`**: `files reprocess <id>` la regenera desde el original.
- **Tests**: `npx vitest run tests/unit/files tests/integration/files tests/e2e/mcp-files.test.ts tests/e2e/files.test.ts`.
  Los que necesitan el worker se omiten solo si no existe el intérprete configurado.

## Fuera del MVP

Aprobado como MVP recortado. Queda para specs posteriores, una por slice:

- subida reanudable por HTTP (tus) y streaming autenticado;
- publicación por snapshot (barrier/CAS) y grafo de procedencia;
- clearance de usuarios independiente del rol y grupos;
- nivel por nota markdown en `vault_read` (hoy solo lo aplica el indexador de RAG);
- purga de la historia del ledger;
- digestión LLM, grafo de afirmaciones, citas mixtas y visor;
- revocación, restauración verificada y purga de derivados y copias;
- OCR, audio/vídeo, backend S3 y conectores.
