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
- `projects/savia-vaults/src/files/policy.ts`, `projects/savia-vaults/src/files/service.ts`,
  `projects/savia-vaults/src/server/tus.ts`, `projects/savia-vaults/src/cli/main.ts`
- `projects/savia-vaults/tests/unit/auth/*.test.ts`,
  `projects/savia-vaults/tests/integration/auth/*.test.ts`,
  `projects/savia-vaults/tests/integration/server/a2a-users.test.ts`,
  `projects/savia-vaults/tests/e2e/mcp-revocation.test.ts`
- `projects/savia-vaults/docs/files-http.md`, `projects/savia-vaults/docs/VAULTS-CLI.md`,
  `projects/savia-vaults/docs/USAGE.md`, `projects/savia-vaults/CHANGELOG.md`,
  `.claude/skills/savia-vaults/SKILL.md`

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

## Resultados

### PR 1 — Subject, credenciales y migración (2026-10-01)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 (MCP y HTTP) | `tests/unit/auth/identity.test.ts`: caducada o revocada ⇒ `Invalid or expired token`; `authorizeUser` con `credentialId` ⇒ «revocada o caducada». `tests/integration/auth/credentials-http.test.ts`: servidor HTTP real, revocar y caducar ⇒ 401 en la siguiente petición aunque el token estuviera en caché | Parcial: A2A y CLI en PR 2 |
| AC4 | Credencial `domes:[A]`, `maxRole: reader` de un admin de A y B: lee A, no escribe en A (403), no ve B (403), en el controlador y en HTTP | OK |
| AC6 | Fichero v1 ⇒ el token sigue valiendo, caduca a los 365 días, `.v1.bak` idéntico en `0600`, segunda carga con el mismo `subjectId` y la misma caducidad | OK (listas `readers`/`writers` en PR 2) |
| AC8 | Escritura atómica (temporal + rename) en `0600`; un fichero previo `0664` pasa a `0600`; sin temporales | OK |
| AC10 | Suite 748/748, `tsc` y `eslint` limpios; `docs/VAULTS-CLI.md` (sección de usuarios rehecha: describía comandos inexistentes) y `docs/files-http.md` | OK |

Desviaciones:

1. **Migración al cargar y guardado inmediato**, no «en la siguiente escritura»: si no,
   cada proceso generaría un `subjectId` y una caducidad distintos hasta la primera escritura.
2. **CLI**: `user tokens`, `user token-create` y `user token-revoke` en lugar de
   `user token create|list|revoke`, para conservar `user token <usuario> --regenerate`.
   `--regenerate` revoca ahora todas las credenciales del usuario y crea una nueva.
3. **`lastUsedAt` no se registra**: escribir en cada validación cambiaría el fichero en
   cada petición y forzaría recargas en todos los procesos.

### PR 2 — A2A por usuario, transferencias, svt1 y subjectId (2026-10-01)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | MCP (stdio real) y HTTP del PR 1; A2A real: `tests/integration/server/a2a-users.test.ts`, revocar ⇒ 401 en la siguiente petición sin reiniciar | OK en MCP, A2A y HTTP. CLI: no usa tokens (ver desviación 1) |
| AC2 | `tests/e2e/mcp-revocation.test.ts` con cliente MCP real y la caché ya caliente: `token-revoke` de la propia credencial ⇒ denegado; revocar otra no afecta; `rename` no corta; `user delete` ⇒ denegado | OK |
| AC3 | `tests/integration/auth/identity-pr2.test.ts`: descarga real de 64 MiB con umbrales reales, revocada antes de leer ⇒ corte con ≤ 16 MiB recibidos (8 MiB hasta la primera comprobación + búferes); `PATCH` ⇒ 401 y solo lo recibido antes; enlace `svt1` de la credencial revocada ⇒ 401, el de otra credencial sigue valiendo. Sin la comprobación, los dos tests de corte fallan (verificado) | OK |
| AC5 | A2A: sin token ⇒ 401; un lector de A no ve B en `/domes` ni en la búsqueda, y no lee ni escribe en B (403); `/domes` sin rutas; fuera de loopback exige usuarios; `SAVIA_VAULTS_TOKEN` solo en loopback con aviso; sin el fichero de usuarios no pasa a modo público (401) | OK |
| AC6 | Listas antiguas por nombre se siguen respetando (`identity-pr2.test.ts`) | OK |
| AC7 | Las listas fijadas por MCP/HTTP se guardan como `sub:<subjectId>` y se muestran por nombre; `user rename` conserva tokens, permisos y acceso por documento; el nombre anterior queda como alias y no se reutiliza | OK (ver desviación 2) |
| AC9 | Medido en esta máquina (p50, 2 rondas, main frente a la rama, 120 documentos, 1/3 con lista): PDP en frío (bcrypt coste 12, `bcryptjs`) 341–367 ms en ambos; con caché **0,009–0,011 ms** (main: 360–366 ms, bcrypt en cada llamada); `list` 0,82–1,12 ms frente a 0,82–1,17 ms (ruido); `vault_rag` 108,8–110,3 ms frente a 113,4–114,0 ms (−3 %) | OK |
| AC10 | Suite 759/759, `tsc` y `eslint` limpios; `docs/files-http.md`, `docs/VAULTS-CLI.md`, `docs/USAGE.md` (A2A) y la skill (citaba `user add`/`passwd`, que no existen) | OK |

Desviaciones:

1. **CLI sin tokens**: la CLI opera sobre el fichero de usuarios como dueña de la máquina;
   no hay vía CLI con token a la que aplicar AC1. Queda fuera, no se simula.
2. **Receipts sin identidad**: los receipts de SE-418 no registran quién actuó, así que
   renombrar no los altera. Añadir el `subjectId` al receipt firmado cambiaría su formato y
   no entra en esta spec.
3. **Descarga cortada sin 401**: con las cabeceras `200` ya enviadas, el corte es cerrar la
   conexión (respuesta truncada). El `PATCH` sí responde 401/403.
4. **Caché de credenciales en el `UserStore`** (60 s, revalidando revocación y caducidad en
   cada uso), común a MCP, A2A y HTTP, en lugar de un `decide()` nuevo: el
   `AccessController` existente ya es el punto de decisión de las tres vías.
5. **Hallazgo**: A2A que arrancaba con usuarios pasaba a modo público si el fichero
   desaparecía. Corregido como en MCP (SE-424 H3).

