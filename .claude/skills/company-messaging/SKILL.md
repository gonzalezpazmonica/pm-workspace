---
layer: peripheral
name: company-messaging
description: Usar cuando se envían mensajes internos cifrados entre miembros de la organización vía Company Savia.
allowed-tools: [Read, Bash, Glob, Grep]
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.category: communication
  savia.maturity: beta
  savia.disable-model-invocation: false
  savia.priority: medium
  savia.summary: "Mensajeria interna Company Savia sobre ramas git con cifrado hibrido RSA+AES (confidencialidad, sin autenticacion ni integridad). Soporta mensajes directos, broadcasts y threading. Datos en company repo compartido. Nivel N2 (empresa)."
  savia.tags: "messaging, company, encryption, privacy"
  savia.user-invocable: False
---

# Company Messaging — Skill (ramas git, v3)

Mensajería asíncrona entre miembros de una organización sobre un repo git
compartido (Company Savia). Cada mensaje es un fichero markdown con
frontmatter YAML. Comportamiento verificado por `tests/test-company-messaging.bats`
contra un remoto bare local.

## Ramas y rutas reales

```
main
  ├── directory.md              ← directorio: tabla "| @handle | Nombre | Rol | Estado |"
  ├── pubkeys/{handle}.pem      ← claves públicas
  └── company/inbox/{id}.md     ← anuncios
exchange (huérfana)
  └── pending/{id}.md           ← mensajes directos en tránsito
user/{handle} (huérfana)
  ├── inbox/unread/{id}.md
  ├── inbox/read/{id}.md
  └── outbox/{id}.md            ← copia de lo enviado
```

Un handle solo admite `[A-Za-z0-9_-]`: se convierte en nombre de rama y de
ruta. La resolución es exacta (`@bo` no resuelve a `@bob`) y acepta tanto
filas de tabla (`| @bob | ... |`, el formato que genera `company-repo`) como
líneas `@bob` sueltas.

## Ciclo de vida de un mensaje

1. `send <handle> <asunto> <cuerpo> [--encrypt] [--priority p]`: trae `main`
   (directorio y claves frescos; sin red avisa y usa la última vista), resuelve el
   handle, cifra el cuerpo si se pide, pasa el mensaje entero por
   `privacy-check-company.sh --stdin` (bloquea si hay secretos) y lo escribe
   en `exchange:pending/{id}.md` más una copia en `user/{remitente}:outbox/`.
2. `inbox`: entrega los pendientes dirigidos al usuario
   (`exchange:pending` → `user/{handle}:inbox/unread/`) y lista no leídos y
   anuncios. Un mensaje ya presente en `unread/` o `read/` no se vuelve a
   entregar. Sin acceso al remoto avisa y muestra la última vista.
3. `read <id>`: muestra el mensaje y lo mueve de `unread/` a `read/` en un
   solo commit (sale de `unread/`).
4. `reply <id> <cuerpo>`: hereda `thread` del original (o usa su id) y fija
   `reply_to`.
5. `broadcast <asunto> <cuerpo>`: un `send` independiente por cada handle del
   directorio salvo el propio; devuelve error si falla alguno.
6. `announce <asunto> <cuerpo>`: escribe en `main:company/inbox/` (sin
   cifrar). Lectura de anuncios en `$HOME/.pm-workspace/company-inbox-read.log`.

Los ids son `AAAAMMDD-HHMMSS-PID-aleatorio`: los mensajes de un mismo
broadcast no colisionan.

No hay purga: los ficheros de `exchange:pending/` permanecen tras la
entrega (la deduplicación evita reentregas). No existe política de retención
implementada.

## Escrituras entre ramas (`savia-branch.sh`)

`write`, `move` y `ensure-orphan` operan con un worktree temporal desacoplado
(`mktemp -d`), sin cambiar la rama del clon:

- Con remoto `origin`: base en `origin/<rama>` recién traída (una rama local
  obsoleta perdería mensajes de otros), commit y `push HEAD:<rama>`. Si el
  push se rechaza por no ser fast-forward (otro miembro escribió a la vez),
  reintenta hasta 5 veces con espera aleatoria creciente; con muchos
  escritores simultáneos puede agotar los reintentos, siempre con error
  visible. Cualquier otro fallo de push devuelve código 1
  con el motivo en stderr: nunca se traga en silencio.
- La rama local se adelanta si no está extraída en ningún worktree; la rama
  extraída (normalmente `main`) no se toca para no desincronizar su árbol.
- Sin remoto `origin`: el commit va a la rama local.
- Reescribir el mismo contenido es un no-op con éxito.

## Cifrado (`savia-crypto.sh`)

Híbrido RSA-4096 + AES-256-CBC con openssl. Da confidencialidad, no
autenticación: no es "E2E" en sentido fuerte (ver límites).

- `keygen [--force]`: par en `~/.pm-workspace/savia-keys/` (privada en 600).
  Sin `--force` no sobrescribe un par existente.
- `encrypt <pubkey.pem> [texto]`: sin texto lee stdin; un texto vacío cifra
  vacío. Salida `base64(clave cifrada):::base64(cuerpo cifrado)`. Un secreto
  aleatorio de 256 bits por mensaje deriva clave e IV (PBKDF2 con sal) y llega
  a openssl por fichero (`-pass file:`), nunca por argv; `send` pasa el cuerpo
  por stdin. El secreto viaja cifrado con RSA como `p:<secreto>`.
- `decrypt` acepta también el formato anterior (`<clave>:<iv>` con `-K/-iv`),
  que sí expone la clave en argv al descifrar.
- `decrypt [paquete|-]`: con `-` o sin argumento lee stdin. Los paquetes de
  más de 128 KB solo caben por stdin (límite de un argumento en Linux).
- Descifrar con otra clave privada o un paquete sin `:::` falla con código
  distinto de 0.

El flujo de mensajería NO descifra al leer: `read` muestra el paquete y el
destinatario lo descifra con `savia-crypto.sh decrypt`. El asunto nunca se
cifra.

Límites conocidos (no resueltos aquí): relleno RSA PKCS#1 v1.5, AES-CBC sin
MAC (el cifrado no detecta manipulación) y sin firma del remitente, así que
`from:` no está autenticado.

## Privacidad (`privacy-check-company.sh`)

- `--stdin`: analiza un mensaje (claves AWS, PAT de GitHub, claves `sk-`,
  JWT, IP privadas, cadenas de conexión, claves privadas PEM) de cualquier
  tamaño. Lo invocan `send` y `announce` antes de cualquier push. Con
  `--encrypt` analiza el mensaje ya cifrado: el cuerpo en claro no se
  inspecciona (solo frontmatter y asunto).
- `<repo> <handle>`: analiza `user/{handle}:inbox/unread/` y `documents/` por
  rama, y los cambios staged solo si el clon está en `user/{handle}` o
  `exchange`.
- El asunto se revisa aparte con `check_subject_sensitivity`: solo avisa, no
  bloquea (ver `docs/rules/domain/messaging-subject-safety.md`).

## Scripts

| Script | Función |
|--------|---------|
| `scripts/savia-branch.sh` | read, list, write, move, exists, ensure-orphan, check-permission, fetch-messages |
| `scripts/savia-messaging.sh` (+ `-inbox`, `-actions`, `-privacy`) | send, inbox, read, reply, announce, broadcast, directory |
| `scripts/savia-crypto.sh` (+ `savia-crypto-ops.sh`) | keygen, encrypt, decrypt, export-pubkey |
| `scripts/privacy-check-company.sh` | Filtro de privacidad |
| `scripts/savia-compat.sh` | Utilidades portables (base64, YAML, config) |

Configuración: `~/.pm-workspace/company-repo` con `LOCAL_PATH=` y `USER_HANDLE=`.
