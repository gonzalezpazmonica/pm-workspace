---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar ambas, PR por spec' (SE-421 y SE-422; tus-js-client autorizado como devDependency)"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L3
related_specs: [SE-413, SE-414, SE-416, SE-417, SE-418, SE-422]
origin: línea L33 de Savia Labs (privada), slice S2 (decisión D09), primera mitad; decisiones de la operadora del 2026-09-30 (producto open source, almacén en streaming, API HTTP en SE-422)
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-421 — Savia Files: almacén en streaming (ficheros de hasta 10 GiB)

## Problema

Savia Vaults es un producto open source: quien lo despliegue para un equipo subirá
vídeos, volcados o PDF de cientos de megas. Hoy el almacén trata cada fichero como
un `Buffer` entero en memoria:

- **Todo el fichero en memoria.** `add`, `readBytes`, el cifrado (`encryptStream`),
  el antivirus y la extracción cargan el fichero completo. El límite por defecto
  son 100 MiB, y subirlo cuesta RAM proporcional.
- **Copias en `/dev/shm`.** En cúpulas cifradas, el antivirus y el lector reciben
  una copia en claro en `/dev/shm`: un fichero de varios GiB llenaría la memoria.
- **Sin base para la API HTTP.** No hay forma de recibir un fichero por partes ni
  de servir un rango, que es lo que necesita la API HTTP (SE-422).

## Decisiones (operadora, 2026-09-30)

- D09 como producto: almacén en streaming ahora y API HTTP con tus 1.0 y tokens
  de subida acotados en SE-422.
- Límite configurable hasta 10 GiB.

## Solución

### 1. Cifrado incremental (`src/files/crypto.ts`)

- **`StreamEncryptor` / `StreamDecryptor`:** el mismo formato SVF1 de SE-417 (frames
  de 1 MiB con `TAG_FINAL`), pero empujando y extrayendo frames uno a uno.
  `encryptStream`/`decryptStream` pasan a ser envoltorios. El formato en disco no
  cambia; los ficheros de SE-417 se leen igual.
- **Rangos cifrados:** `decryptRange(key, file, aad, start, end)` descifra en orden
  desde el principio y descarta hasta `start`. secretstream no permite saltar
  frames: el coste es proporcional al desplazamiento, y se documenta. Cada frame
  servido va autenticado.
- **Formato de subida parcial (SVFU1)**, para las subidas reanudables de SE-422 en
  cúpulas cifradas:
  - trozos sellados con XChaCha20-Poly1305;
  - AAD `{uploadId, índice, final}` (construcción STREAM);
  - reanudable tras reiniciar el proceso (el estado de secretstream no se puede
    persistir).
  Al completar la subida, se convierte a SVF1 en una sola pasada, sin texto en
  claro en disco.

### 2. Almacén (`src/files/store.ts`)

- **`addStream({name, source, size?, …})`:**
  - lee un `Readable` y calcula el SHA-256 mientras escribe;
  - en claras, escribe a un temporal y lo renombra a `blobs/<sha256>`, con
    deduplicación como hoy;
  - en cifradas, escribe SVF1 frame a frame (`blobHash` del cifrado, SE-418);
  - memoria acotada (≈ 2 frames);
  - `TOO_LARGE` en cuanto se pasa del límite, borrando el temporal.
- `add(Buffer)` pasa a ser un envoltorio de `addStream`.
- **`openRead(id, rev?, range?)`:**
  - devuelve `{ stream, size, start, end }`;
  - en claras usa `createReadStream` con rango;
  - en cifradas, `StreamDecryptor` más recorte;
  - sin rango, verifica el SHA-256 al terminar y, si no coincide, destruye el
    stream con `INTEGRITY`;
  - con rango, verifica cada frame (cifradas) o nada (claras). Queda documentado;
    `files verify --deep` comprueba el fichero entero.
- `readBytes` se mantiene para ficheros pequeños (base64 de MCP, ≤ 20 MiB) y
  rechaza los mayores con `TOO_LARGE` (la CLI y la API usan streams).
- **Límites:**
  - `SAVIA_FILES_MAX_BYTES` admite hasta 10 GiB (por defecto 1 GiB);
  - `files.maxBytes` por cúpula en el registro, que no puede superar el global.

### 3. Antivirus y extracción (`scan.ts`, `extract.ts`)

- **Antivirus en streaming:** `clamscan -` por stdin, descifrando al vuelo en
  cúpulas cifradas: sin copia en claro en disco ni en `/dev/shm`. Se pasan a
  clamscan `--max-filesize`/`--max-scansize` iguales al tamaño del fichero (hasta
  su tope interno de 4 GiB). Por encima, el veredicto es `scan-error` con motivo
  `too-large-to-scan`, y `required` lo trata como no escaneado.
- **Extracción con tope** `SAVIA_FILES_MAX_EXTRACT_BYTES` (por defecto 256 MiB):
  - un fichero soportado mayor queda `ARCHIVE_ONLY` con
    `skipped: too-large-to-extract` (descargable y citable como fichero, sin texto);
  - por debajo del tope, igual que hoy (copia en `/dev/shm` en cifradas);
  - los formatos de texto se leen por stream.
- **Bomba ZIP:** `zip-guard` recibe la ruta y lee solo el directorio central, sin
  cargar el ZIP entero.

### 4. CLI

- `files add` lee de disco en streaming.
- `files get` escribe en streaming y admite `--range <inicio-fin>`.

## Criterios de aceptación

- **AC1** `files add` de un fichero de 2 GiB (N2 y N3):
  - memoria residente máxima < 256 MiB (medida);
  - la descarga devuelve bytes idénticos (SHA-256);
  - en N3, 0 bytes en claro en disco y en `/dev/shm` durante y después.
- **AC2** Los ficheros guardados con SE-413..420 (claros y cifrados SVF1) se leen
  sin migración. `encryptStream`/`decryptStream` producen y leen el mismo formato.
- **AC3** Rangos:
  - `openRead` con rango devuelve exactamente los bytes pedidos (inicio, mitad,
    final, cruzando fronteras de frame, un solo byte), en claras y cifradas;
  - un frame manipulado dentro del rango da `INTEGRITY`.
- **AC4** Sin rango, un blob manipulado da `INTEGRITY` al final del stream y el
  consumidor recibe el error, no un fichero «completo».
- **AC5** Límites:
  - `TOO_LARGE` a mitad de stream deja 0 temporales;
  - `files.maxBytes` de la cúpula manda si es menor;
  - `readBytes` de un fichero de más de 20 MiB da `TOO_LARGE` con indicación de
    usar el stream.
- **AC6** Antivirus:
  - con el ClamAV gestionado real, EICAR por stdin queda `QUARANTINED` en N2 y N3
    sin copia en claro en disco;
  - un fichero por encima del tope de clamscan queda `scan-error`
    (`too-large-to-scan`) y en `required` no pasa.
- **AC7** Extracción:
  - un PDF por encima de `SAVIA_FILES_MAX_EXTRACT_BYTES` queda `ARCHIVE_ONLY`
    (`too-large-to-extract`), sin lanzar el worker;
  - `zip-guard` detecta la bomba ZIP leyendo solo el directorio central.
- **AC8** SVFU1:
  - trozos escritos en varias sesiones (el proceso reinicia entre medias) se
    convierten a SVF1 idéntico en contenido;
  - un trozo reordenado o manipulado da `INTEGRITY`;
  - la conversión no deja texto en claro en disco.
- **AC9** Coste medido y publicado:
  - `add` y descarga de 10 MB, 1 GiB y 2 GiB (N2 y N3): tiempo y memoria máxima;
  - frente a SE-420 en 10 MB.
- **AC10** La suite existente sigue en verde.

## Entregables (rutas)

- **Código:**
  - `projects/savia-vaults/src/files/crypto.ts`, `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/scan.ts`;
  - `projects/savia-vaults/src/files/extract.ts`, `projects/savia-vaults/src/files/zip-guard.ts`, `projects/savia-vaults/src/files/types.ts`;
  - `projects/savia-vaults/src/files/service.ts`, `projects/savia-vaults/src/cli/files.ts`, `projects/savia-vaults/src/registry/domes.ts`.
  - (`scan.test.ts` y `extract.test.ts` no cambian: la cobertura nueva está en `streaming.test.ts`.)
- **Tests:**
  - `projects/savia-vaults/tests/unit/files/zip-guard.test.ts`, `projects/savia-vaults/tests/integration/files/streaming.test.ts`, `projects/savia-vaults/tests/e2e/files.test.ts`.
- **Documentación:**
  - `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`, `CHANGELOG.d/se421-savia-files-streaming.md`;
  - `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | Medición: 2 GiB en N2 y N3, memoria máxima 141 / 160 MiB (< 256), descarga con SHA-256 idéntico y 0 restos en `/dev/shm`. Test: 3 MiB+ en N3 sin ningún fragmento en claro en el almacén | OK |
| AC2 | Ficheros de `add` (SE-417) leídos por `openRead`; `encryptStream`/`decryptStream` compatibles con 0, 1, frame exacto, frame+1 y 3 frames; suite de SE-417 intacta | OK |
| AC3 | Rangos al principio, en medio, al final, cruzando frames, de 1 byte y enteros, en claras y cifradas; rango inválido da `INVALID_INPUT`; frame manipulado dentro del rango da `INTEGRITY` | OK |
| AC4 | Blob manipulado (claro y cifrado) da `INTEGRITY` en el stream, no un fichero «completo»; la CLI no deja fichero | OK |
| AC5 | `TOO_LARGE` a mitad sin temporales ni envoltura; `files.maxBytes` de la cúpula (tamaño declarado y a mitad de stream); `readBytes` grande da `TOO_LARGE` | OK |
| AC6 | Falso clamscan por stdin (limpio, infectado, tope sin abrir el stream); **ClamAV gestionado real**: EICAR en N3 por encima del tope de extracción queda `QUARANTINED` sin copia en `/dev/shm` | OK |
| AC7 | PDF por encima de `SAVIA_FILES_MAX_EXTRACT_BYTES` queda `ARCHIVE_ONLY` (`too-large-to-extract`) sin worker; `inspectZipFile` coincide con `inspectZip` (fixtures, bomba, zip64, ZIP roto) | OK |
| AC8 | SVFU1: trozos en orden; otra subida, orden cambiado, sin final o manipulado dan `INTEGRITY` | OK (unit; la reanudación entre procesos se prueba de verdad en SE-422) |
| AC9 | Ver tabla | Publicado |
| AC10 | Suite completa en verde | OK |

**Coste (AC9):**

| Tamaño | N2: guardar / descargar | N3: guardar / descargar | Memoria máxima N2 / N3 |
|---|---|---|---|
| 10 MB (main, SE-420) | 176 / 49 ms | 375 / 90 ms | 142 / 208 MiB |
| 10 MB (SE-421) | 150 / 51 ms | 310 / 91 ms | 129 / 155 MiB |
| 1 GiB | 3,2 / 4,8 s | 9,5 / 8,0 s | 142 / 160 MiB |
| 2 GiB | 6,4 / 9,5 s | 18,1 / 16,1 s | 141 / 160 MiB |

### Desviaciones

1. **`add(Buffer)` sigue síncrono** y comparte con `addStream` la validación y el
   registro de la revisión, en vez de ser un envoltorio asíncrono. Así no cambia el
   contrato de quien ya lo usa.
2. **Antivirus por stdin solo para cifrados por encima del tope de extracción.**
   clamscan carga las firmas en cada invocación (unos 10 s). El resto se sigue
   analizando por ruta en un solo lote (SE-416): el blob en claras, o la copia en
   `/dev/shm` en cifradas pequeñas. Por encima de 4 000 MB no se analiza.
3. **`gc` y altas en curso.** No borra temporales `*.tmp-<pid>-<ms>` de un proceso
   vivo con menos de 24 h, ni la envoltura de su DEK.
4. **`openRead` recorre el cifrado desde el principio** para servir un rango: es el
   límite de SVF1 ya declarado en SE-417.
5. **Los datos se alinean a frames de 1 MiB** al cifrar en streaming, aunque la
   fuente llegue en trozos de 64 KiB: mismo tamaño de frame que `encryptStream`.

## Esfuerzo

Agente 8–12 h · humano 1 h (revisión del formato SVFU1 y de los límites).

## Dependencias

SE-413..420. Sin paquetes nuevos.

## Fuera de alcance

- API HTTP, tus, tokens de subida y rangos HTTP (SE-422).
- Acceso aleatorio a rangos cifrados sin descifrar desde el principio (cambiaría el
  formato SVF1).
- Verificación de rangos en claras (necesitaría hashes por bloque).
- OCR y extracción de ficheros por encima del tope.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| CLI `savia-vaults files add/get --range` | bash | idéntico |
| MCP `vault_files` (sin cambios de contrato) | `~/.claude.json` | `opencode.json` |

### Verification protocol

- [ ] `files add` de 2 GiB con memoria < 256 MiB y descarga idéntica

### Portability classification

- [x] **PURE_NODE** (clamscan por stdin si está instalado)
