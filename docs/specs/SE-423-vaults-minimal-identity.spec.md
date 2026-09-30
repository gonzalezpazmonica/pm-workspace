---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar; token A2A obsoleto' con D1 = 365 días"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L3
related_specs: [SE-419, SE-420, SE-422, SE-291]
origin: revisión S02 de Vaults/Files (2026-09-30), hallazgos H2 y H3; delta mínimo compatible con la línea de identidad de Savia Labs (privada), sin adoptar su alcance completo
resource: https://github.com/gonzalezpazmonica/savia/tree/main/projects/savia-vaults/src/auth
---

# SE-423 — SaviaVaults: identidad mínima (Subject, credenciales con caducidad y decisión de acceso común)

## Problema

Savia Vaults se sirve por cuatro vías: MCP, A2A, HTTP (SE-422) y la CLI. No deciden igual
quién es cada cual ni qué puede hacer. En la revisión S02 (2026-09-30) se comprobó con
procesos reales:

1. **A2A no tiene usuarios.** Sin `SAVIA_VAULTS_TOKEN`, sirve cualquier cúpula a
   cualquiera, N4 incluida, junto con sus rutas absolutas. Envía
   `Access-Control-Allow-Origin: *`, así que una web abierta en el navegador puede leer
   un A2A local. Con token, hay un único secreto compartido que se compara sin tiempo
   constante, y ni permisos por cúpula ni guarda de loopback.
2. **MCP no ve revocaciones.** Un proceso MCP ya abierto sigue permitiendo el acceso tras
   `user revoke` y `user delete`. HTTP sí las aplica en la siguiente petición.
3. **La credencial es única y no caduca.** Cada usuario tiene un token `sv_…` sin fecha de
   caducidad, que no se puede limitar a unas cúpulas ni revocar sin regenerarlo, y que
   se identifica por el nombre de usuario. Renombrar a alguien o darle un segundo token
   (portátil y servidor) no es posible sin compartir el secreto.
4. `savia-vaults.users.json` se escribe con los permisos por defecto del proceso.

## Objetivo

Un delta pequeño y compatible que cierre esos huecos. **No** incluye login con
contraseña, MFA, SSO/OIDC, passkeys, organizaciones, federación ni autoridad de efectos:
quedan para specs posteriores, y esta no debe impedirlas.

## Solución

### 1. Subject

- Cada usuario gana `subjectId` (UUID v4) estable, independiente del nombre y de la
  credencial. Los receipts, la auditoría y las listas `readers`/`writers` (SE-419) nuevas
  guardan el `subjectId`.
- Las listas existentes con nombres se migran al `subjectId` en la primera escritura; la
  lectura acepta ambas formas mientras dure la migración.
- `type: human | service`. `service` no puede ser admin de cúpula ni leer N4.

### 2. Credenciales (PAT) con caducidad y revocación individual

- Varias por Subject: `{ id, name, prefix, hash, createdAt, expiresAt, lastUsedAt?, domes?: string[], maxRole?: reader|writer|admin, revokedAt? }`.
- `expiresAt` obligatorio. Por defecto 90 días; máximo configurable
  (`SAVIA_VAULTS_PAT_MAX_DAYS`, por defecto 365).
- `domes` y `maxRole` solo **restringen** lo que el Subject ya tiene; nunca lo amplían.
- CLI: `user token create <user> --name --expires --domes --max-role`,
  `user token list <user>` (sin secretos) y `user token revoke <user> <id>`.
- **Migración**: el token actual de cada usuario pasa a ser su primera credencial con
  `expiresAt` = migración + 365 días (D1). `files status` y `user list` avisan de
  lo que caduca en los próximos 14 días.
- Formato `sv_…` sin cambios para los clientes. Verificación con bcrypt y caché de 60 s
  en todas las vías, invalidada al cambiar el fichero.

### 3. PDP común

- `AccessController.decide({ credential, dome, action, resource?, via })` es el único
  punto de decisión para MCP, A2A, HTTP y la CLI con token. Devuelve
  `{ subjectId, username, role, credentialId }` o un error tipado.
- Evaluación: credencial válida (no caducada ni revocada) → permiso de cúpula →
  restricción de la credencial → nivel de cúpula y de nota (SE-420) → política del
  documento (SE-419).
- **Recarga**: el PDP llama a `reloadIfChanged()` en cada decisión, en todas las vías.
  Cierra H3.
- **Streams**: una descarga o subida en curso vuelve a consultar el PDP cada 8 MiB o
  cada 30 s. Si la decisión cambia, corta con 401/403 y no escribe ni sirve más bytes.
  Los grants `svt1.` (SE-422) se validan contra la credencial que los emitió: revocarla
  los invalida.

### 4. A2A detrás del PDP

- Con usuarios, cada petición A2A lleva `Authorization: Bearer <PAT>` y pasa por el PDP
  (lectura por cúpula).
- Sin usuarios, **solo loopback** y solo cúpulas ≤ N2. Fuera de loopback, A2A no arranca
  sin usuarios, igual que HTTP.
- `SAVIA_VAULTS_TOKEN` (secreto compartido) queda obsoleto: se acepta solo en loopback,
  con aviso, durante una versión (decisión D2).
- Sin `Access-Control-Allow-Origin: *`: CORS desactivado, u orígenes explícitos por
  configuración.
- `/domes` no devuelve rutas absolutas.

### 5. Ficheros

- `savia-vaults.users.json` se escribe en `0600` de forma atómica (temporal + rename).
  Esquema `version: 2`; la versión 1 se migra al cargar y se guarda en la siguiente
  escritura, con copia `.v1.bak` en `0600`.

## Decisiones (operadora, 2026-09-30)

- **D1** Los tokens migrados caducan a los **365 días** de la migración. Los nuevos, por
  defecto a los 90 días (máximo `SAVIA_VAULTS_PAT_MAX_DAYS`, 365).
- **D2** `SAVIA_VAULTS_TOKEN` en A2A queda **obsoleto con aviso durante una versión**,
  solo en loopback.
- **D3** Los arreglos inmediatos de A2A (guarda) y MCP (recarga) van antes, en SE-424;
  esta spec los generaliza al PDP común.

## Criterios de aceptación

- **AC1** Una credencial caducada o revocada da 401 en MCP, A2A, HTTP y la CLI, **sin
  reiniciar** ningún proceso (test con los cuatro servidores reales en loopback).
- **AC2** `user revoke`, `user delete` y `token revoke` se aplican en la siguiente llamada
  de un proceso MCP ya abierto (cliente MCP real).
- **AC3** Una descarga HTTP de 64 MiB se corta en ≤ 8 MiB o ≤ 30 s tras revocar la
  credencial; un `PATCH` en curso también. Un grant `svt1.` de una credencial revocada
  da 401.
- **AC4** Una credencial con `domes: [A]` y `maxRole: reader` no escribe en A ni lee B,
  aunque el Subject sea admin de ambas.
- **AC5** A2A: sin usuarios y `--host 0.0.0.0`, no arranca. Sin usuarios en loopback, no
  sirve N3/N4. Con usuarios, un lector de A no ve B. Sin `CORS *`. `/domes` sin rutas.
- **AC6** Migración de v1: los tokens existentes siguen funcionando, con `expiresAt`, y las
  listas `readers`/`writers` con nombres se siguen respetando. Existe `.v1.bak` en `0600`.
  Una segunda carga es idempotente.
- **AC7** Renombrar un usuario conserva su acceso por documento y sus receipts (por
  `subjectId`).
- **AC8** `savia-vaults.users.json` en `0600`; una escritura interrumpida no deja el fichero
  a medias.
- **AC9** Coste: una decisión del PDP con caché ≤ 1 ms p50; sin caché (bcrypt) medido y
  publicado. `vault_rag` y `list` sin regresión > 10 %.
- **AC10** Suite completa en verde; los documentos (`docs/files-http.md`, `VAULTS-CLI.md`,
  la skill) explican credenciales, caducidad y revocación.

## Entregables (rutas)

- `projects/savia-vaults/src/auth/store.ts`, `projects/savia-vaults/src/auth/types.ts`,
  `projects/savia-vaults/src/auth/controller.ts`
- `projects/savia-vaults/src/server/mcp.ts`, `projects/savia-vaults/src/server/a2a.ts`,
  `projects/savia-vaults/src/server/http.ts`, `projects/savia-vaults/src/server/grants.ts`
- `projects/savia-vaults/src/files/policy.ts`, `projects/savia-vaults/src/cli/main.ts`
- `projects/savia-vaults/tests/unit/auth/*.test.ts`,
  `projects/savia-vaults/tests/integration/auth/*.test.ts`,
  `projects/savia-vaults/tests/e2e/identity-revocation.test.ts`
- `projects/savia-vaults/docs/files-http.md`, `projects/savia-vaults/docs/VAULTS-CLI.md`

## Esfuerzo

Agente 8–12 h; revisión humana 2–3 h (migración y A2A). Dos PR posibles: (1) Subject,
credenciales y migración; (2) PDP en las cuatro vías, streams y A2A.

## Fuera de alcance

Login interactivo, MFA, sesiones de navegador, recuperación de cuenta, organizaciones y
membresías, SSO/OIDC/passkeys, SCIM, federación, clearance por persona distinta del rol
de cúpula, y cualquier autoridad de efectos en sistemas externos.

## OpenCode Implementation Plan

### Bindings touched

Solo `projects/savia-vaults` (TypeScript/Node). Ningún hook, comando ni agente del
workspace.

### Verification protocol

- [ ] Los cuatro servidores reales en loopback con el mismo fichero de usuarios: revocar
  → 401 en cada uno sin reiniciar.
- [ ] Cliente MCP real (stdio) en Claude Code y OpenCode: revocación en caliente.

### Portability classification

- [x] **PURE_NODE**
