# Savia Files — API HTTP (SE-422)

API HTTP de Savia Vaults para subir y bajar ficheros grandes por red: subida
reanudable con [tus 1.0](https://tus.io/protocols/resumable-upload), descarga por
rangos y consulta de documentos. Es para equipos que sirven Savia Vaults en un
servidor. El uso local por MCP y CLI sigue igual (ver [files.md](files.md)).

## Índice

1. [Arranque](#arranque)
2. [Autenticación](#autenticación)
3. [Subir (tus)](#subir-tus)
4. [Descargar y consultar](#descargar-y-consultar)
5. [Subidas delegadas desde el chat (MCP)](#subidas-delegadas-desde-el-chat-mcp)
6. [Despliegue detrás de un proxy](#despliegue-detrás-de-un-proxy)
7. [Límites, errores y seguridad](#límites-errores-y-seguridad)
8. [Coste medido](#coste-medido)

## Arranque

```bash
savia-vaults user create eva                 # token personal sv_… (se muestra una vez)
savia-vaults user grant eva proyectos writer
savia-vaults serve --transport http --port 8924 --domes savia-vaults.domes.json
# fuera de loopback:  --host 0.0.0.0 --tls-cert cert.pem --tls-key key.pem
#                 o:  --host 0.0.0.0 --behind-proxy     (TLS en el proxy)
```

- **Condiciones para arrancar:**
  - Sin usuarios no arranca: no hay a quién autorizar.
  - Fuera de loopback (`127.0.0.1`, `::1`) exige TLS propio o `--behind-proxy`.
- **Ficheros de claves y usuarios:** usa los mismos que MCP y la CLI
  (`SAVIA_FILES_HOME`, `SAVIA_FILES_KEYS_HOME`, `savia-vaults.users.json`).
- **Cambios de usuarios en caliente:** se leen sin reiniciar, aquí y en el servidor MCP
  (SE-424). Borrar un usuario, quitarle una cúpula o regenerar su token invalida su
  acceso y sus autorizaciones acotadas en la siguiente petición.
- **Para `vault_files upload/link`:** define `SAVIA_FILES_HTTP_URL` con la URL
  pública del servidor en el entorno del MCP.

## Autenticación

`Authorization: Bearer <token>` en cada petición:

| Token | Qué permite |
|---|---|
| Personal `sv_…` | Lo que la persona puede hacer por MCP: permisos de cúpula (lectura/escritura/admin) y por documento (SE-419). Caduca siempre; puede estar limitado a unas cúpulas y a un rol máximo (SE-423, `user token-create`) |
| Autorización acotada `svt1.…` | **Subida:** una sola subida a una cúpula, con tamaño máximo, 1 h. **Descarga:** un documento, 15 min. Siempre en nombre de su usuario y con sus permisos actuales |

La descarga acepta también `?token=` en la URL, para enlaces de navegador.

## Subir (tus)

**Rutas:**

- `/v1/files/{cúpula}/uploads`: `OPTIONS` y `POST` (creación).
- `/v1/files/{cúpula}/uploads/{id}`: `HEAD`, `PATCH` y `DELETE`.
- `GET /v1/files/{cúpula}/uploads/{id}`: estado en JSON (no es tus).

**Extensiones:** `creation`, `creation-with-upload`, `termination`, `expiration` y
`checksum` (sha256). No hay `creation-defer-length`.

**`Upload-Metadata`:**

- `filename`: obligatorio (o `name`);
- `tags`: separadas por comas;
- `confidentiality`, `replaces` e `idempotencyKey`, opcionales.

Los metadatos de una autorización acotada mandan sobre los del cliente.

```bash
T=sv_…; U=http://127.0.0.1:8924/v1/files/proyectos/uploads
LOC=$(curl -si -X POST "$U" -H "Authorization: Bearer $T" -H "Tus-Resumable: 1.0.0" \
  -H "Upload-Length: $(stat -c%s video.mp4)" -H "Upload-Metadata: filename $(printf video.mp4 | base64)" \
  | awk '/^Location:/ {print $2}' | tr -d '\r')
curl -s -X PATCH "http://127.0.0.1:8924$LOC" -H "Authorization: Bearer $T" -H "Tus-Resumable: 1.0.0" \
  -H "Upload-Offset: 0" -H "Content-Type: application/offset+octet-stream" --data-binary @video.mp4 -D -
# Savia-Document-Id, Savia-Operation-Id y Savia-Status en la respuesta final
```

```js
// Navegador o Node con tus-js-client
new tus.Upload(file, {
  endpoint: 'https://savia.ejemplo/v1/files/proyectos/uploads',
  headers: { Authorization: 'Bearer ' + token },
  metadata: { filename: file.name },
  chunkSize: 64 * 1024 * 1024,
  onSuccess: () => console.log('subido'),
}).start();
```

**Qué garantiza:**

- **Reanudación.** Offset, longitud y caducidad viven en el journal de la cúpula:
  una subida se reanuda aunque el servidor se reinicie (`HEAD` da el offset).
- **Cortes.** Un `PATCH` cortado conserva lo recibido, salvo si trae
  `Upload-Checksum`: entonces se descarta entero.
- **Cúpulas cifradas.** Los trozos se sellan en disco desde el primer byte (SVFU1,
  SE-421) y los metadatos también: nunca hay un fichero en claro a medio subir. Al
  completar, se convierten a SVF1 sin texto en claro en disco. Rotar la clave de la
  cúpula invalida las subidas en curso.
- **Al completar**, el documento se guarda como un `put`:
  - una operación del ledger con receipt (SE-418);
  - antivirus y extracción (SE-421);
  - permisos (SE-419).
  Los bytes de la subida se borran.
- **Caducidad.** Las subidas incompletas caducan a las 24 h y las limpia
  `files gc`.

## Descargar y consultar

| Ruta | Devuelve |
|---|---|
| `GET /v1/files/{c}/documents[?tag=]` | Lista (solo lo que el usuario puede leer) |
| `GET /v1/files/{c}/documents/{id}` | Documento (sin listas de acceso si solo puede leer) |
| `GET /v1/files/{c}/documents/{id}/content[?revision=]` | El original |
| `GET /v1/files/{c}/operations/{operationId}` | Estado y receipt firmado |
| `GET /v1/health` | `{ok: true}` |

**Cabeceras de la descarga:**

- `ETag` es el `revisionId`; admite `If-None-Match` (304) e `If-Range`.
- `Range: bytes=a-b | a- | -n` devuelve 206 con `Content-Range`; fuera de rango,
  416. Varios rangos a la vez: se sirve el fichero entero.
- `Content-Disposition: attachment` con el nombre saneado y `filename*`.
- `X-Content-Type-Options: nosniff` y `Content-Security-Policy: sandbox`.

**Rangos en cúpulas cifradas:** se autentica cada frame, pero se descifra desde el
principio: el final de un fichero grande tarda más que el principio (ver coste).

## Subidas delegadas desde el chat (MCP)

Un LLM no debe mover gigas por su contexto. En su lugar:

- **`vault_files action:"upload"`** (`dome`, `name?`, `maxBytes?`, `tags?`,
  `confidentiality?`, `replaces?`) devuelve `uploadUrl`, `token` (autorización
  acotada) e `instructions`. Savia se los da a la persona, que sube con su
  navegador, `curl` o un cliente tus.
  - El documento queda a nombre de quien lo pidió y con sus permisos.
  - La autorización es de un solo uso, caduca en 1 h y no sirve para otra cúpula
    ni para descargar.
- **`vault_files action:"link"`** (`dome`, `id`, `revisionId?`) devuelve un enlace
  de descarga de 15 min para ese documento.

Ambas necesitan usuarios y `SAVIA_FILES_HTTP_URL`; sin ellas, `UNSUPPORTED` con la
explicación.

## Despliegue detrás de un proxy

```nginx
location /v1/files/ {
  proxy_pass http://127.0.0.1:8924;
  proxy_request_buffering off;   # la subida va en streaming
  proxy_buffering off;
  client_max_body_size 0;        # el límite lo pone Savia (Upload-Length)
  proxy_read_timeout 300s;
  proxy_set_header Host $host;
}
```

```caddy
savia.ejemplo {
  reverse_proxy /v1/files/* 127.0.0.1:8924 {
    flush_interval -1
  }
}
```

Arranca Savia con `--behind-proxy` solo si el proxy termina TLS. `Location` va en
ruta relativa (`/v1/files/…`), así que no depende del host.

## Límites, errores y seguridad

**Variables:**

| Variable | Defecto | Qué hace |
|---|---|---|
| `SAVIA_FILES_MAX_BYTES` / `files.maxBytes` | 1 GiB (máx. 10 GiB) | `Tus-Max-Size` y límite por fichero |
| `SAVIA_FILES_MAX_ACTIVE_UPLOADS` | 20 | Subidas sin terminar por usuario (429 si se supera) |
| `SAVIA_FILES_HTTP_RATE` | 600 | Peticiones por minuto y usuario |
| `SAVIA_FILES_HTTP_URL` | — | URL pública para `upload` y `link` |

**Timeouts:** 30 s para recibir las cabeceras y 120 s de inactividad. Sin límite de
duración total (una subida grande puede tardar).

**Estados HTTP:**

| Estado | Cuándo |
|---|---|
| 400 | Petición no válida |
| 401 | Sin token, token no válido o autorización ya usada |
| 403 | Sin permiso, o autorización acotada fuera de su ámbito |
| 404 | No existe, o no hay permiso de lectura (SE-419) |
| 409 | Offset o versión que no coincide |
| 410 | Subida caducada |
| 412 | Falta `Tus-Resumable: 1.0.0` |
| 413 | Demasiado grande |
| 415 | `Content-Type` no válido en un `PATCH` |
| 416 | Rango fuera del fichero |
| 422 | Antivirus obligatorio no disponible, o fichero de más de 2 GiB en una cúpula que exige escaneo |
| 423 | Otro `PATCH` en curso sobre la misma subida |
| 429 | Límite de peticiones o de subidas activas |
| 460 | `Upload-Checksum` no coincide |
| 501 | No soportado |
| 503 | Reintentar (`Retry-After`) |

El cuerpo es `{error: {code, message}}`.

**Seguridad:**

- Los tokens personales se comprueban con bcrypt, con una caché de 60 s
  invalidada al cambiar el fichero de usuarios.
- Las autorizaciones acotadas se firman con HMAC-SHA256 y una clave propia
  (`<keys>/_http/token.key`, 0600). La subida es de un solo uso: el `jti` se
  consume al crear.
- La auditoría registra usuario, cúpula y acción, nunca nombres de fichero.
- Un enlace de descarga con `?token=` puede quedar en logs de proxies: por eso caduca
  en 15 min y sirve para un solo documento.

## Coste medido

Servidor real en otro proceso y cliente `tus-js-client` en local (trozos de
64 MiB). Fichero de 1 GiB:

| | N2 | N3 (cifrada) |
|---|---|---|
| Subida (incluye guardar y registrar) | 5,1 s (~199 MB/s) | 18,1 s (~57 MB/s) |
| Descarga completa (curl) | 3,5 s | 6,6 s |
| Rango: primer MiB | 11 ms | 15 ms |
| Rango: último MiB | 11 ms | 3,7 s (se descifra desde el principio) |

Memoria máxima del servidor durante la prueba: **185 MiB**.
