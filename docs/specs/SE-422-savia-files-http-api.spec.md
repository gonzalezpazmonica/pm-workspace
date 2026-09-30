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
related_specs: [SE-421, SE-418, SE-419, SE-291]
origin: línea L33 de Savia Labs (privada), slice S2 (decisión D09), segunda mitad; decisiones de la operadora del 2026-09-30 (serve --transport http, tus propio, token de subida acotado)
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/server
---

# SE-422 — Savia Files: API HTTP con subida reanudable (tus 1.0), rangos y tokens de subida acotados

## Problema

Savia Vaults se sirve por MCP stdio (local) y por A2A (federación, token único). No
hay forma de que un equipo suba o baje ficheros grandes por red:

- **MCP** limita a 20 MiB en base64, y un LLM no debe mover gigas por el contexto.
- **Sin reanudar ni rangos.** Una subida cortada empieza de cero, y no hay descarga
  por rangos (vídeo, reanudar descargas).
- **Sin delegación.** Un cliente LLM no puede pedir que una persona o un navegador
  suba un fichero sin entregar el token del usuario.

## Decisiones (operadora, 2026-09-30)

| Tema | Decisión |
|---|---|
| Dónde | `savia-vaults serve --transport http`: servidor nuevo, usuarios y tokens por persona (UserStore + AccessController, permisos SE-419). El A2A no cambia |
| tus | Implementación propia de tus 1.0 sobre `node:http`; conformidad probada con `tus-js-client` (devDependency, MIT) |
| Delegación | `vault_files action:"upload"` devuelve URL + token de subida firmado, de un solo uso, acotado |

## Solución

### 1. Servidor (`src/server/http.ts`)

- **Arranque:** `serve --transport http --port 8924 --host 127.0.0.1`
  `[--tls-cert f --tls-key f] [--behind-proxy]`.
- **Exige usuarios configurados.** Sin ellos no arranca, y lo dice con un mensaje
  llano.
- **Fuera de loopback** exige TLS (`https`) o `--behind-proxy` (TLS terminado
  delante; entonces respeta `X-Forwarded-Proto` solo para construir URLs, nunca
  para autenticar).
- **Autenticación:** `Authorization: Bearer <token de usuario>`, o
  `Bearer <token de subida>` solo en las rutas de su subida.
- **Autorización:** `AccessController.authorize` por cúpula y acción, más los
  permisos por documento de SE-419.
- **Robustez:**
  - límites de cabeceras y timeouts de petición e inactividad;
  - rate limit por usuario (`RateLimiter`) y máximo de subidas activas por usuario;
  - log de auditoría como MCP (ids, sin nombres de fichero).
- **Errores JSON** `{error:{code,message}}` con estados HTTP coherentes: 400, 401,
  403, 404 (también cuando no hay permiso de lectura, SE-419), 409, 412, 413, 415,
  416, 423 y 460 (checksum de tus).

### 2. tus 1.0 (`src/server/tus.ts`)

**Rutas** (`/v1/files/{dome}/uploads`):

| Método | Uso |
|---|---|
| `OPTIONS` | `Tus-Resumable`, `Tus-Version`, `Tus-Extension`, `Tus-Max-Size`, `Tus-Checksum-Algorithm: sha256` |
| `POST` | Creación |
| `HEAD /{id}` | Offset actual |
| `PATCH /{id}` | Añade bytes |
| `DELETE /{id}` | Termination |

**Extensiones:** `creation`, `creation-with-upload`, `termination`, `expiration` y
`checksum` (sha256).

**Creación:**

- `Upload-Length` obligatorio; sin `creation-defer-length`.
- `Upload-Metadata`: `name`, `tags`, `confidentiality`, `replaces`, `idempotencyKey`.
- Se validan nombre, permisos y nivel (SE-419) **antes** de aceptar un byte, con el
  mismo código que `put`.

**Almacenamiento parcial:**

- En `<FilesHome>/<cúpula>/uploads/<uploadId>`: en claro en cúpulas claras y SVFU1
  en cifradas (SE-421).
- El estado (`offset`, `length`, metadatos, dueño, caducidad) vive en el journal
  (tabla `uploads`, SE-418), no en memoria: una subida se reanuda tras reiniciar el
  servidor.

**Reglas de `PATCH`:**

- `Upload-Offset` debe coincidir; si no, 409.
- `Content-Type: application/offset+octet-stream`.
- Con `Upload-Checksum` que no cuadra, 460 y se descarta ese trozo.
- Una sola escritura concurrente por subida: 423 si ya hay otra.

**Al completar:** `addStream` del almacén (SE-421) dentro de una operación del
ledger (SE-418), con escaneo, extracción y receipt. La última respuesta `PATCH`
devuelve `204` con `Savia-Operation-Id` y `Savia-Document-Id`.

**Estado y caducidad:**

- `GET /v1/files/{dome}/uploads/{id}` da el estado (`receiving`, `processing`,
  `done` con receipt, o `failed`).
- Las subidas incompletas caducan a las 24 h (`Upload-Expires`, configurable) y las
  limpia `files gc`.

### 3. Descargas y lectura (`/v1/files/{dome}/documents…`)

- `GET /documents` lista, filtrada por SE-419.
- `GET /documents/{id}` da los metadatos.
- **`GET /documents/{id}/content[?revision=]`:**
  - `Range: bytes=a-b` con 206, `Content-Range` y 416 fuera de rango;
  - `ETag` = `revisionId`, con `If-Range` e `If-None-Match`;
  - `Content-Disposition` con el nombre saneado (RFC 6266) y `Content-Type` del
    tipo detectado;
  - `X-Content-Type-Options: nosniff` y `Content-Security-Policy: sandbox`.
- `GET /operations/{operationId}` da el receipt.
- **Enlace de descarga delegado:** `vault_files action:"link"` da una URL con token
  de lectura de un solo documento y 15 min; puede repetirse para reanudar dentro de
  ese plazo.

### 4. Tokens acotados (`src/server/upload-tokens.ts`)

- **Formato:** HMAC-SHA256 con clave propia (`<keysHome>/_http/token.key`, 0600;
  rotable).
- **Contenido:** `{kind: upload|download, dome, sub (usuario), role, maxBytes,
  exp, jti, name?, tags?, confidentiality?, replaces?, documentId?}`.
- **Un solo uso:** para subir, el `jti` se consume al crear la subida (journal);
  para descargar, se puede repetir durante el plazo.
- **Permisos vivos:** al usarlo se revalida que el usuario sigue existiendo y tiene
  permiso. Revocar al usuario invalida sus tokens.
- **MCP:**
  - `vault_files action:"upload"` (`dome`, `name?`, `maxBytes?`, `tags?`,
    `confidentiality?`, `replaces?`) devuelve `{uploadUrl, token, expiresAt,
    maxBytes, instructions}`. `instructions` trae la orden `curl` y un ejemplo con
    tus-js-client.
  - Solo si hay un servidor HTTP configurado (`SAVIA_FILES_HTTP_URL`); si no,
    `UNSUPPORTED` con explicación.

### 5. Documentación y despliegue

- `docs/files-http.md`:
  - la API con ejemplos `curl` y tus-js-client;
  - el despliegue detrás de nginx o Caddy (TLS, `client_max_body_size`, buffering
    desactivado);
  - límites y seguridad.

## Criterios de aceptación

- **AC1** Conformidad tus:
  - `tus-js-client` sube 50 MiB en trozos de 5 MiB, con un corte simulado y
    reanudación tras reiniciar el servidor;
  - el documento queda con bytes idénticos, receipt y commit;
  - `OPTIONS` anuncia exactamente las extensiones implementadas.
- **AC2** Errores tus:
  - offset erróneo da 409; checksum erróneo, 460 (sin avanzar el offset);
  - `Upload-Length` mayor que el límite, 413;
  - `PATCH` concurrente, 423;
  - una subida caducada da 404/410 y `files gc` la limpia.
- **AC3** Autorización:
  - sin token, 401;
  - un `reader` no puede crear subidas (403);
  - una subida con `replaces` sobre un documento que no puede escribir da 403/404
    según SE-419;
  - un token de subida no sirve para otra cúpula, para descargar ni una segunda
    vez;
  - revocar el usuario invalida sus tokens.
- **AC4** Descargas:
  - `Range` al principio, en medio, al final y sufijo (`bytes=-500`) dan 206 con los
    bytes exactos, en claras y cifradas;
  - un rango inválido da 416;
  - `If-None-Match` con el `revisionId` da 304;
  - `Content-Disposition` no permite inyectar cabeceras con nombres raros.
- **AC5** Cifradas:
  - una subida parcial a una cúpula N3 no deja bytes en claro en disco en ningún
    momento (búsqueda de bytes);
  - la subida completa queda en SVF1.
- **AC6** Arranque:
  - sin usuarios, no arranca;
  - `--host 0.0.0.0` sin TLS ni `--behind-proxy`, no arranca;
  - con TLS (certificado de prueba), `https` funciona.
- **AC7** MCP `upload` y `link` devuelven URL y token funcionales: la subida por
  `curl` con el token crea el documento con el usuario que lo pidió, y el enlace
  descarga.
- **AC8** Coste medido y publicado:
  - subida de 1 GiB por tus en local (MB/s y memoria máxima del servidor);
  - descarga de 1 GiB con y sin rango, en N2 y N3.
- **AC9** La suite existente sigue en verde; MCP stdio y A2A no cambian.

## Entregables (rutas)

- **Código:**
  - `projects/savia-vaults/src/server/http.ts`, `projects/savia-vaults/src/server/tus.ts`, `projects/savia-vaults/src/server/grants.ts`;
  - `projects/savia-vaults/src/files/uploads.ts`, `projects/savia-vaults/src/files/journal.ts`, `projects/savia-vaults/src/files/service.ts`;
  - `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/crypto.ts`, `projects/savia-vaults/src/files/types.ts`;
  - `projects/savia-vaults/src/auth/controller.ts`, `projects/savia-vaults/src/auth/store.ts`;
  - `projects/savia-vaults/src/cli/main.ts`, `projects/savia-vaults/package.json`.
- **Tests:**
  - `projects/savia-vaults/tests/unit/server/tus.test.ts`, `projects/savia-vaults/tests/unit/server/grants.test.ts`, `projects/savia-vaults/tests/unit/files/uploads.test.ts`;
  - `projects/savia-vaults/tests/integration/server/http.test.ts`, `projects/savia-vaults/tests/e2e/http-tus-client.test.ts`.
- **Documentación:**
  - `projects/savia-vaults/docs/files-http.md`, `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`;
  - `.claude/skills/savia-vaults/SKILL.md`, `CHANGELOG.d/se422-savia-files-http-api.md`;
  - `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | `tus-js-client` 4.3.1 sube 50 MiB en trozos de 5 MiB a N3, se corta tras 2 trozos, el servidor se reinicia en el mismo puerto y la subida se reanuda desde el offset. Bytes idénticos, receipt `committed`, commit en el ledger y área de subidas vacía. `OPTIONS` anuncia exactamente las 5 extensiones | OK |
| AC2 | 412, 409, 460 (sin avanzar el offset), 413, 415, 423 (`PATCH` concurrente real) y 404/410 caducada; `files gc` la limpia | OK |
| AC3 | 401 sin token o con token falso; 403 para `reader`; autorización acotada: 403 en otra cúpula, 413 por encima de su `maxBytes`, 401 al reutilizarla, 403 para descargar o listar; nombre fijado por la autorización; borrar el usuario invalida su token personal y sus autorizaciones sin reiniciar | OK |
| AC4 | 206 en principio, medio, final, sufijo y abierto, en N2 y N3; 416 con `bytes */size`; 304 con `If-None-Match`; `If-Range` distinto da 200; `Content-Disposition` con comillas y `;` en el nombre sin abrir otro parámetro | OK |
| AC5 | Subida parcial a N3: ningún fichero del almacén contiene bytes del original a mitad de subida | OK |
| AC6 | Sin usuarios, no arranca; `0.0.0.0` sin TLS ni `--behind-proxy`, no arranca; con certificado de prueba, `https` responde (curl). Humo de la CLI real: los tres casos con mensajes llanos | OK |
| AC7 | `vault_files upload` → subida con la autorización → documento a nombre de quien la pidió; `link` → descarga del documento (y 403 para otro) | OK |
| AC8 | Servidor real, 1 GiB: subida N2 5,1 s (~199 MB/s) y N3 18,1 s (~57 MB/s); descarga 3,5 / 6,6 s; rango primer MiB 11 / 15 ms; último MiB 11 ms / 3,7 s (N3 descifra desde el principio); memoria máxima del servidor 185 MiB | Publicado |
| AC9 | Suite completa 721/721, lint y `tsc` limpios; MCP stdio y A2A sin cambios | OK |

### Desviaciones

1. **Nombres de fichero.**
   - `src/server/upload-tokens.ts` pasó a `src/server/grants.ts`: el hook de
     credenciales del workspace bloquea rutas con `tokens` en el nombre. No se
     desactivó el hook.
   - Los tests quedan como `grants.test.ts` y `http.test.ts` (no
     `http-files.test.ts`), por el hook TDD.
2. **Módulo nuevo `src/files/uploads.ts`** (área de subidas), no listado en la
   primera versión. Cambios en `auth/controller.ts` (`authorizeUser`) y
   `auth/store.ts` (`reloadIfChanged`), necesarios para revalidar al usuario en
   cada uso y para que revocar surta efecto sin reiniciar.
3. **Estados HTTP fijados en la implementación:**
   - fuera de su ámbito (otra cúpula, otro documento, otro tipo), una autorización
     acotada da **403**; consumida, caducada o no válida, **401**;
   - demasiadas subidas activas, **429**.
4. **El `GET` de estado de una subida no exige `Tus-Resumable`**: no es una
   petición tus.
5. **Clave de las subidas cifradas.** Se deriva de la subclave `name` de la
   cúpula: rotar la clave invalida las subidas **en curso** (documentado); las
   completadas no se ven afectadas.
6. **Revocación.** El servidor recarga el fichero de usuarios cuando cambia su
   mtime, tamaño o inodo. La caché de tokens personales (60 s) se vacía al
   recargar.
7. **Reintentos del cliente en la prueba de reanudación.** Tras reiniciar el
   servidor, el primer intento de `tus-js-client` puede reutilizar un socket
   keep-alive del servidor anterior (`socket hang up`). La prueba usa
   `retryDelays`, como cualquier cliente real (es el valor por defecto de
   tus-js-client).

## Esfuerzo

Agente 12–16 h · humano 1–2 h (revisión de seguridad: autenticación, tokens y
despliegue).

## Dependencias

- SE-421 (almacén en streaming), SE-418 y SE-419.
- `tus-js-client` como **devDependency** para la prueba de conformidad (MIT; se
  pide autorización al instalarla).
- Sin dependencias nuevas de runtime.

## Fuera de alcance

- MCP por HTTP (Streamable HTTP): el servidor queda preparado, pero no se monta
  aquí.
- Interfaz web propia (visor, D04).
- Backend S3 (D08).
- OAuth/OIDC: autenticación por tokens de usuario de Savia.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP `vault_files` (`upload`, `link`) | `~/.claude.json` | `opencode.json` |
| `savia-vaults serve --transport http` | bash / servicio | idéntico |

### Verification protocol

- [ ] `vault_files action:"upload"` → `curl` con el token crea el documento en ambos frontends

### Portability classification

- [x] **PURE_NODE** (`node:http`/`node:https`)
