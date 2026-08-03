# SE-291 — SaviaVaults: Multi-dome server con control de acceso por cupula

**Status:** PROPOSED
**Fecha:** 2026-08-01
**Proyecto:** projects/savia-vaults
**Padre:** SE-287 (vaults-complete v0.2.0), SE-288 (capa-conocimiento v0.3.0)
**Branch:** agent/se291-multi-dome-access
**Estimacion total:** ~42h (7 slices)

---

## Origen

Diagnostico post-SE-290 (2026-08-01). Savia Vaults v0.3.0 funciona correctamente para servir una cupula (SaviaLabs) via MCP/A2A. Pero el diseno documentado en SE-280 y SE-284 promete multi-domo y gestion de usuarios/permisos que no existen en codigo. La arquitectura mono-domo actual tiene un hard limit estructural: el servidor MCP arranca con `--path <un-solo-directorio>` y no puede cambiar en runtime.

### Lo que funciona

- 1 servidor MCP con 13 tools para un vault (v0.2.0 + v0.3.0)
- Storage, search, security, knowledge layer, federation, backup: modulos probados y estables
- SE-290 resolvio path resolution para single-dome
- 125 tests PASS

### Lo que NO funciona

| Gap | Severidad | Detalle |
|---|---|---|
| Multi-dome serving | CRITICAL | `serve` acepta un solo `--path`. No hay mecanismo para servir N domes desde una instancia |
| Dome registry | CRITICAL | No hay registro persistente de domes. El servidor no sabe que domes existen |
| Dome management CLI | HIGH | `dome create/list/info/delete` son stubs en bash wrapper; no existen en TS CLI |
| User/Permission system | CRITICAL | `user add/remove/list/passwd/perm` documentados en SE-284 pero zero codigo |
| Confidentiality enforcement | HIGH | N1-N4 definidos pero ningun gate de autorizacion los consulta |
| A2A multi-dome routing | MEDIUM | A2A endpoints no soportan seleccion de dome |
| Tool-level auth | CRITICAL | Tools MCP no validan identidad ni permisos |

---

## Objetivo

Un servidor SaviaVaults que gestione **multiples cupulas** desde una sola instancia MCP/A2A, con **control de acceso por cupula** (roles admin/writer/reader), **tokens de autenticacion** por usuario, y **enforcement de niveles de confidencialidad** (N1-N4). Al terminar, `savia-vaults serve --transport mcp` carga todos los domes registrados, sus tools aceptan un parametro `vault` para seleccionar cupula, y los accesos se validan contra roles configurados por dome.

## Out of scope

- NO OAuth/OIDC ni SSO externo — solo tokens Bearer locales
- NO multi-tenancy con organizaciones — usuarios globales con permisos por dome
- NO auditoria de accesos en tiempo real (queda para SE-293)
- NO quotas por usuario (queda para SE-293)
- NO UI de administracion — solo CLI y API

---

## Diseno general

```
                    MCP Client (OpenCode, Claude Code, etc.)
                           │
            ┌──────────────▼──────────────┐
            │     MCP Server (stdio)      │
            │                             │
            │  tools: vault_read(vault,path) │
            │         vault_search(vault,q)  │
            │         ... (13 tools + vault) │
            │                             │
            │  ┌───────────────────────┐  │
            │  │   AccessController    │  │  ← NEW: valida identidad + rol por dome
            │  │   per-vault RBAC      │  │
            │  └─────────┬─────────────┘  │
            │            │                │
            │  ┌─────────▼─────────────┐  │
            │  │    VaultRegistry      │  │  ← NEW: carga N domes, resuelve por nombre
            │  │  name → VaultInstance │  │
            │  └─────────┬─────────────┘  │
            │            │                │
            │     ┌──────┴──────┐         │
            │     ▼             ▼         │
            │  Vault A       Vault B      │  ← 1 Storage + 1 SearchEngine por dome
            │  (SaviaLabs)   (Labs)       │
            └─────────────────────────────┘

Cada VaultInstance contiene:
  - VaultStorage (git-backed, scoped al path del dome)
  - SearchEngine (BM25 index propio)
  - VaultSecurity (sandbox propio)
  - KnowledgeGraph (grafo propio)
  - metadatos: name, path, confidentiality (N1-N4), description
```

### Decisiones de diseno

**D1. Un parametro `vault` en cada tool MCP (no namespaces ni multi-instancia).** Agregar `vault` como parametro opcional a las 13 tools existentes. Si no se especifica, usar el dome por defecto (`defaultDome` en config). Esto evita explosion de tools (13 tools × N domes = inviable), no rompe compatibilidad con clientes existentes (el parametro es opcional), y permite que un solo proceso sirva todos los domes.

**D2. Dome registry en archivo JSON versionable.** `savia-vaults.domes.json` en la raiz del proyecto declara todos los domes conocidos. El servidor lo carga al arrancar. Esto permite compartir la config de domes entre miembros del equipo (el archivo se versiona) mientras que las credenciales se mantienen en `savia-vaults.users.json` (gitignored).

**D3. Users + tokens en archivo separado gitignored.** `savia-vaults.users.json` (gitignored) almacena usuarios, sus tokens hasheados (bcrypt), y sus roles por dome. Separado del registro de domes porque contiene informacion de autenticacion.

**D4. AccessController como middleware de tools MCP.** Cada tool del MCP server consulta al AccessController antes de ejecutar. El AccessController:
1. Extrae identidad del header MCP (campo `_meta.authToken` o variable de entorno `SAVIA_AUTH_TOKEN`)
2. Busca usuario por token
3. Verifica rol para el dome solicitado
4. Deniega si el nivel de confidencialidad del dome excede el rol del usuario

---

## Slice 1 — Dome Registry: multi-vault config + carga en servidor (4h)

**Problema:** El servidor `serve` acepta un solo `--path`. No hay concepto de "domes registrados".

**Diseno:**
- `src/registry/domes.ts`: clase `DomeRegistry` que carga, valida y persiste `savia-vaults.domes.json`
- `savia-vaults.domes.json` schema:
  ```json
  {
    "version": 1,
    "defaultDome": "SaviaLabs",
    "domes": {
      "SaviaLabs": {
        "name": "SaviaLabs",
        "path": "vaults/SaviaLabs",
        "description": "Cupula de contexto principal de Savia",
        "confidentiality": "N2",
        "schemaDir": "projects/savia-vaults/schema/entities"
      }
    }
  }
  ```
- `VaultInstance`: factory que crea Storage + SearchEngine + Security para un dome especifico
- `serve` command: si existe `savia-vaults.domes.json`, carga todos los domes registrados. Si no, fallback a `--path` legacy (single-dome). **Validacion al cargar**: domes cuyo `path` no exista en disco → warning en startup, se omiten del registry activo (no bloquean el arranque). Un dome `active: false` no aparece en `vault_domes`
- Refactor `src/cli/index.ts:serve`: opcion `--domes <file>` (default: `savia-vaults.domes.json`)
- `DomeRegistry.list()` → `DomeInfo[]`, `DomeRegistry.get(name)` → `VaultInstance`
- Migrar SaviaLabs al archivo de domes

**Acceptance criteria:**
- AC-1.1. `serve --transport mcp` carga todos los domes de `savia-vaults.domes.json`
- AC-1.2. `serve --transport mcp --path vaults/SaviaLabs` (legacy) sigue funcionando sin archivo de domes
- AC-1.3. `DomeRegistry.list()` devuelve todos los domes con nombre, path, confidencialidad
- AC-1.4. `DomeRegistry.get('SaviaLabs')` devuelve VaultInstance con Storage y SearchEngine propios
- AC-1.5. Dome con path inexistente → warning en startup, omitido del registry activo, servidor arranca
- AC-1.6. Errores de parseo en `savia-vaults.domes.json` bloquean el arranque con mensaje claro
- AC-1.7. Tests unitarios nuevos: `tests/unit/registry/domes.test.ts` (6+ tests incluyendo path invalido)

**Esfuerzo:** 4h

---

## Slice 2 — Tools MCP dome-scoped: parametro `vault` + `vault_domes` (8h)

**Problema:** Las 13 tools MCP no aceptan parametro de dome. Siempre operan sobre el vault unico. No hay forma de descubrir que domes existen desde un cliente MCP.

**Diseno:**
- Agregar `vault` como parametro opcional (string) en las 13 tools MCP registradas
- Si `vault` no se especifica → usar `defaultDome` del DomeRegistry
- Si `vault` especificado pero no existe en registry → error `DomeNotFound`
- El handler de cada tool:
  1. Lee `args.vault` (o defaultDome)
  2. `registry.get(vaultName)` resuelve la VaultInstance
  3. Delega la operacion al storage/search de esa instancia
- **Nueva tool `vault_domes`**: lista los domes registrados con nombre, descripcion, confidencialidad y noteCount. Sin parametros. Responde con datos publicos del registry (no expone paths en disco)
- Ejemplo de firma actualizada:
  ```typescript
  // vault_read
  {
    name: 'vault_read',
    inputSchema: {
      type: 'object',
      properties: {
        vault: { type: 'string', description: 'Dome name (default: configured default)' },
        path: { type: 'string', description: 'Relative path to the note' }
      },
      required: ['path']
    }
  }
  // vault_domes (nueva)
  {
    name: 'vault_domes',
    description: 'List registered domes with name, description, confidentiality, and note count.',
    inputSchema: { type: 'object', properties: {} }
  }
  ```
- `vault_list` con `vault` → lista archivos de ese dome (comportamiento actual)
- `vault_list` **sin** `vault` → lista archivos del defaultDome (NO lista domes — usar `vault_domes`)
- `vault_stats` sin `vault` → stats del defaultDome (NO agrega todos los domes: evitar fuga de info cross-dome)
- `vault_stats` con `vault` → stats de ese dome
- `vault_health` sin `vault` → health del defaultDome (mismo criterio)
- `vault_health` con `vault` → health de un dome
- `vault_introspect` con `vault` → introspeccion de ese dome
- `vault_introspect` sin `vault` → introspeccion del defaultDome
- `vault_graph`, `vault_query` → aceptan `vault`, operan sobre el KnowledgeGraph de ese dome

**Acceptance criteria:**
- AC-2.1. `vault_read({vault: "SaviaLabs", path: "INDEX.md"})` lee del dome correcto
- AC-2.2. `vault_read({path: "INDEX.md"})` sin vault usa el defaultDome
- AC-2.3. `vault_read({vault: "NoExiste", path: "x.md"})` devuelve error DomeNotFound
- AC-2.4. `vault_domes()` lista domes registrados con nombre, descripcion, confidencialidad, noteCount
- AC-2.5. `vault_list({vault: "SaviaLabs"})` lista archivos del dome (backward compat)
- AC-2.6. `vault_list()` sin vault lista archivos del defaultDome (backward compat, NO rompe clientes existentes)
- AC-2.7. `vault_stats()`/`vault_health()` sin vault → solo defaultDome (no agrega cross-dome)
- AC-2.8. `vault_search({vault: "SaviaLabs", query: "..."})` busca solo en ese dome
- AC-2.9. `vault_search({query: "..."})` sin vault busca en el defaultDome (NO en todos)
- AC-2.10. Tests MCP actualizados para cubrir multi-dome dispatch. `npm test` pasa

**Esfuerzo:** 8h

---

## Slice 3 — Dome management CLI (6h)

**Problema:** El bash wrapper `scripts/vaults` tiene stubs de `dome create|list|info|delete` que apuntan a `~/.savia/vaults/` (vacio). No hay implementacion real en TS CLI.

**Diseno:**
- Comandos nuevos en `src/cli/index.ts`:
  ```
  savia-vaults dome create <name> [--path <dir>] [--description <text>] [--confidentiality N2]
  savia-vaults dome list [--json]
  savia-vaults dome info <name> [--json]
  savia-vaults dome delete <name> [--force]
  savia-vaults dome set-default <name>
  ```
- `dome create`: crea directorio, init git, genera INDEX.md + MAP.md, registra en `savia-vaults.domes.json`
- `dome list`: lee registry, muestra tabla (nombre | path | confidencialidad | notas | default)
- `dome info <name>`: muestra metadatos completos + stats del dome
- `dome delete <name>`: elimina del registry (NO borra archivos en disco). `--force` borra tambien los archivos
- `dome set-default <name>`: actualiza `defaultDome` en registry
- Validaciones: nombre unico, path existe (para create), no borrar dome que es default sin `--force`
- Actualizar `scripts/vaults` bash wrapper para delegar en TS CLI en lugar de logica propia

**Acceptance criteria:**
- AC-3.1. `savia-vaults dome create Labs --path vaults/Labs --confidentiality N1` crea dome y lo registra
- AC-3.2. `savia-vaults dome list` muestra todos los domes registrados con sus metadatos
- AC-3.3. `savia-vaults dome info SaviaLabs` muestra path, confidencialidad, stats, default
- AC-3.4. `savia-vaults dome delete Labs` elimina del registry, archivos intactos
- AC-3.5. `savia-vaults dome delete Labs --force` elimina del registry Y borra directorio
- AC-3.6. `savia-vaults dome create Duplicado` rechaza nombre ya registrado
- AC-3.7. `savia-vaults dome set-default Labs` actualiza defaultDome en registry
- AC-3.8. Tests unitarios: `tests/unit/cli/dome-commands.test.ts` (6+ tests)

**Esfuerzo:** 6h

---

## Slice 4 — User & permission system (10h)

**Problema:** Zero implementacion de usuarios y permisos. SE-284 documento la CLI pero sin codigo.

**Diseno:**
- `src/auth/types.ts`: `User`, `UserRole` (admin|writer|reader), `DomePermission`, `AuthToken`
- `src/auth/store.ts`: clase `UserStore` que persiste en `savia-vaults.users.json` (gitignored)
  ```json
  {
    "version": 1,
    "users": {
      "monica": {
        "username": "monica",
        "tokenHash": "$2b$10$...",
        "tokenPrefix": "sv_",       // primeros 4 chars del token (para identificar)
        "createdAt": "2026-08-01T...",
        "permissions": {
          "SaviaLabs": { "role": "admin" },
          "Labs": { "role": "writer" }
        }
      }
    }
  }
  ```
- Tokens formato: `sv_<32 bytes random base64url>` (prefijo `sv_` para identificacion visual)
- Almacenamiento: bcrypt hash (12 rounds) del token completo. JAMAS se guarda el token en texto claro
- `UserStore.createUser(username)`: genera token, hashea, guarda usuario. Devuelve el token (UNA SOLA VEZ)
- `UserStore.validateToken(token)`: busca por prefijo, verifica con bcrypt. Devuelve usuario o null
- `UserStore.setPermission(username, dome, role)`: asigna/actualiza rol
- `UserStore.removePermission(username, dome)`: revoca acceso
- `UserStore.getPermissions(username)`: lista todos los permisos del usuario
- `UserStore.regenerateToken(username)`: nuevo token, invalida el anterior
- Generacion de tokens: `crypto.randomBytes(32).toString('base64url')`

**Acceptance criteria:**
- AC-4.1. `UserStore.createUser('monica')` genera token, hashea, persiste. Token visible solo en creacion
- AC-4.2. `UserStore.validateToken('sv_abc123...')` retorna usuario si token valido
- AC-4.3. `UserStore.validateToken('token-invalido')` retorna null
- AC-4.4. `UserStore.setPermission('monica', 'SaviaLabs', 'reader')` persiste correctamente
- AC-4.5. `UserStore.getPermissions('monica')` lista todos los domes y roles del usuario
- AC-4.6. Re-generacion de token invalida token anterior (hash distinto)
- AC-4.7. `savia-vaults.users.json` jamas contiene tokens en texto claro
- AC-4.8. Tests unitarios: `tests/unit/auth/user-store.test.ts` (10+ tests)
- AC-4.9. Tests unitarios: `tests/unit/auth/token-validation.test.ts` (5+ tests)

**Esfuerzo:** 10h

---

## Slice 5 — AccessController: RBAC gate en tools MCP (6h)

**Problema:** Las tools MCP no validan identidad ni permisos. Cualquier cliente puede leer/escribir cualquier dome.

**Diseno:**
- `src/auth/controller.ts`: clase `AccessController`
  ```typescript
  class AccessController {
    constructor(userStore: UserStore, domeRegistry: DomeRegistry)

    // Autoriza una operacion. Lanza AuthError si denegada.
    async authorize(params: {
      authToken?: string;       // del header MCP _meta o env var
      dome: string;             // dome al que se quiere acceder
      action: 'read' | 'write' | 'admin';  // accion solicitada
    }): Promise<Authorization>;
  }
  ```
- Roles y permisos:
  | Rol | read | write | user-mgmt | dome-mgmt |
  |---|---|---|---|---|
  | reader | Si | No | No | No |
  | writer | Si | Si | No | No |
  | admin | Si | Si | Si | Si |

- Flujo de autorizacion:
  1. Si el dome tiene confidencialidad N1 (publico) y la accion es `read` → permitir sin token
  2. Si el dome es N2+ o accion no es read → requiere token
  3. Validar token contra UserStore
  4. Verificar que el usuario tiene rol suficiente para la accion en ese dome
  5. Si todo OK → devolver Authorization con username + role
  6. Si falla → `AuthError` con mensaje y codigo (unauthorized / forbidden / dome_not_found)

- Integracion en MCP server:
  - `src/server/mcp.ts`: cada tool handler llama a `this.auth.authorize(...)` antes de ejecutar
  - `vault_read`, `vault_search`, `vault_list`, `vault_stats`, `vault_tags`, `vault_introspect`, `vault_graph`, `vault_query`, `vault_health`, `vault_diff`, `vault_log`, `vault_domes` → `action: 'read'`
  - `vault_write` → `action: 'write'`
  - `vault_index` → `action: 'write'`
  - El token se lee de la variable de entorno `SAVIA_AUTH_TOKEN` (configurada una vez en el cliente MCP, ej. `env` en `opencode.json`). No viaja como argumento de tool
  - Las tools CLI (`dome`, `user`) operan directo sobre archivos sin autenticacion MCP

- Bootstrap: el primer admin se crea via CLI antes de arrancar el servidor MCP
  - `savia-vaults user create admin` genera token (visible una sola vez)
  - El token se configura en el cliente MCP via variable de entorno `SAVIA_AUTH_TOKEN`
  - En OpenCode: `opencode.json` → `mcp.savia-vaults.env.SAVIA_AUTH_TOKEN`
  - Hasta que `SAVIA_AUTH_TOKEN` tenga un token valido, el servidor MCP rechaza toda operacion
  - Las tools CLI (`dome`, `user`) operan directo sobre archivos, sin pasar por el servidor MCP
  - NO hay modo legacy ni fallback: sin token valido = sin acceso

**Acceptance criteria:**
- AC-5.1. Dome N1 (publico): `vault_read` sin token → permitido
- AC-5.2. Dome N2+: `vault_read` sin token → error `unauthorized`
- AC-5.3. Usuario reader: `vault_read` → OK, `vault_write` → `forbidden`
- AC-5.4. Usuario writer: `vault_read` + `vault_write` → OK
- AC-5.5. Usuario admin: todas las operaciones → OK
- AC-5.6. Usuario sin permiso en dome especifico → `forbidden` aunque tenga permisos en otro dome
- AC-5.7. Sin archivo de usuarios → servidor MCP rechaza toda operacion (no legacy mode)
- AC-5.8. Bootstrap: `user create admin` crea usuario admin, servidor MCP empieza a aceptar con ese token
- AC-5.9. Token expirado o invalido → `unauthorized`
- AC-5.10. Tests unitarios: `tests/unit/auth/access-controller.test.ts` (12+ tests)
- AC-5.11. Tests de integracion: `tests/integration/auth-workflow.test.ts` (5+ tests)

**Esfuerzo:** 6h

---

## Slice 6 — User management CLI (4h)

**Problema:** No hay forma de gestionar usuarios y permisos desde linea de comandos.

**Diseno:**
- Comandos nuevos en `src/cli/index.ts`:
  ```
  savia-vaults user create <username>
  savia-vaults user delete <username>
  savia-vaults user list [--json]
  savia-vaults user token <username> [--regenerate]
  savia-vaults user grant <username> <dome> <role>
  savia-vaults user revoke <username> <dome>
  savia-vaults user permissions <username> [--json]
  ```
- `user create`: genera usuario + token. Muestra el token UNA vez con aviso de guardar seguro
- `user delete`: elimina usuario y todos sus permisos
- `user list`: tabla de usuarios con cantidad de domes asignados
- `user token`: muestra token actual (solo si se pasa flag `--show`). `--regenerate` genera nuevo token
- `user grant`: asigna rol a usuario en dome. Requiere que dome exista
- `user revoke`: quita acceso de usuario a dome
- `user permissions`: lista todos los permisos del usuario (dome | rol)

**Acceptance criteria:**
- AC-6.1. `savia-vaults user create alice` crea usuario y muestra token (una vez)
- AC-6.2. `savia-vaults user grant alice SaviaLabs reader` asigna rol reader
- AC-6.3. `savia-vaults user permissions alice` muestra SaviaLabs: reader
- AC-6.4. `savia-vaults user revoke alice SaviaLabs` elimina el permiso
- AC-6.5. `savia-vaults user token alice --regenerate` genera nuevo token, invalida anterior
- AC-6.6. `savia-vaults user delete alice` elimina usuario y todos sus permisos
- AC-6.7. `savia-vaults user grant alice NoExiste reader` rechaza con dome not found
- AC-6.8. Tests unitarios: `tests/unit/cli/user-commands.test.ts` (6+ tests)

**Esfuerzo:** 4h

---

## Slice 7 — Confidencialidad enforcement + A2A auth + integracion final (4h)

**Problema:** Los niveles N1-N4 no se validan en runtime. A2A no tiene auth multi-dome.

**Diseno:**
- `src/auth/confidentiality.ts`: `ConfidentialityGuard`
  - Mapea nivel → requisito minimo de rol para lectura Y escritura
  - N1 (publico) → lectura sin restriccion, escritura writer
  - N2 (interno) → lectura reader, escritura writer
  - N3 (confidencial) → lectura writer, escritura writer
  - N4 (restringido) → lectura admin, **escritura admin** (ni writer puede escribir en N4)
- `vaults dome confidentiality set N3 --dome Legal` actualiza nivel en registry
- `vaults dome confidentiality get --dome Legal` consulta nivel actual
- `vaults dome confidentiality audit` lista todos los domes con su nivel y compliance
- A2A Server multi-dome:
  - Endpoints aceptan parametro `?vault=<name>` o header `X-Vault: <name>`
  - Auth via `Authorization: Bearer sv_<token>` (mismo token que MCP, mismo UserStore)
  - Rate limiter por dome (no global). MCP no tiene rate limiting (stdio, cliente unico)
- Integracion final:
  - `VaultInstance` incluye `ConfidentialityGuard` y `AccessController`
  - `serve` command: todas las piezas conectadas (Registry → UserStore → AccessController → Tools + A2A)
  - Actualizar `savia-vaults.domes.json` con SaviaLabs (N2, default)
  - Actualizar `.gitignore`: agregar `savia-vaults.users.json`
  - Actualizar `scripts/vaults` bash wrapper para delegar en TS CLI

**Acceptance criteria:**
- AC-7.1. Dome N4: usuario reader → `vault_read` denegado aunque el dome exista
- AC-7.2. Dome N2: usuario reader → `vault_read` permitido
- AC-7.3. `savia-vaults dome confidentiality set N3 Legal` persiste en registry
- AC-7.4. `curl "http://127.0.0.1:8923/search?vault=SaviaLabs&q=test" -H "Authorization: Bearer sv_<token>"` autentica
- AC-7.5. Sin token en dome N2+: A2A devuelve 401
- AC-7.6. `savia-vaults dome confidentiality audit` muestra tabla de niveles por dome
- AC-7.7. `npm test` — 125 tests existentes + ~55 nuevos = ~180 tests PASS
- AC-7.8. `npm run build` sin errores
- AC-7.9. `npm run typecheck` sin errores

**Esfuerzo:** 4h

---

## Plan de Implementacion

### Orden recomendado

1 (Registry, 4h) → 3 (Dome CLI, 6h) → 4 (User system, 10h) → 6 (User CLI, 4h) → 2 (Dome-scoped tools, 8h) → 5 (AccessController, 6h) → 7 (Confidencialidad + A2A + final, 4h)

Total: 42h

### Dependencias

- Slice 3 depende de Slice 1 (necesita DomeRegistry para crear/listar domes)
- Slice 6 depende de Slice 4 (opera sobre UserStore)
- Slice 2 depende de Slices 1, 3, 4, 6 (necesita domes + usuarios creados para testear dispatch)
- Slice 5 depende de Slice 4 (necesita UserStore) y Slice 2 (tools deben existir para integrar auth)
- Slice 7 depende de Slices 1-6 (integra todo)

### Riesgos

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| bcrypt no compila en todos los OS | Media | Alto | Usar `bcryptjs` (JS puro, sin native addons) como dependencia |
| `SAVIA_AUTH_TOKEN` no configurado → todas las tools deniegan | Baja | Medio | Error claro en cada tool: "auth token not configured". Documentar en README |
| Bootstrap bloqueante: sin admin no hay acceso | Baja | Alto | CLI `user create` opera directo sobre archivo, sin pasar por MCP |

---

## Verification method

1. Servidor MCP multi-dome funcional: `serve --transport mcp` levanta N domes
2. `vault_domes()` lista todos los domes registrados con nombre, confidencialidad, noteCount
3. `vault_read({vault: "SaviaLabs", path: "INDEX.md"})` devuelve contenido correcto
4. `vault_list()` sin vault → archivos del defaultDome (backward compat, NO rompe clientes)
5. `vault_stats()` sin vault → solo defaultDome (no filtra info cross-dome)
6. Tool `vault_read({vault: "Legal", path: "secret.md"})` con usuario reader → denegado (N4)
7. Tool `vault_write` con usuario reader → denegado (forbidden)
8. Tool `vault_write` en dome N4 con usuario writer → denegado (N4 write = admin only)
9. Tool `vault_write` en dome N4 con usuario admin → OK
10. CLI: `dome create`, `dome list`, `user create`, `user grant`, `user permissions` funcionales
11. A2A: `curl /search?vault=SaviaLabs` con Bearer token autentica correctamente
12. Sin `SAVIA_AUTH_TOKEN` → servidor MCP rechaza toda operacion
13. Dome con path inexistente → warning en startup, servidor arranca con domes validos
14. `npm test` — 125 tests existentes + ~55 nuevos = ~180 tests PASS
15. `npm run build && npm run typecheck` — sin errores

## Ficheros nuevos

```
projects/savia-vaults/
├── savia-vaults.domes.json          # Registry de domes (versionable)
├── savia-vaults.users.json          # Usuarios + permisos (gitignored)
├── src/
│   ├── registry/
│   │   └── domes.ts                 # DomeRegistry + VaultInstance factory
│   └── auth/
│       ├── types.ts                 # User, UserRole, DomePermission, AuthToken, ConfidentialityLevel
│       ├── store.ts                 # UserStore (CRUD + token management)
│       ├── controller.ts            # AccessController (RBAC gate)
│       └── confidentiality.ts       # ConfidentialityGuard (N1-N4 enforcement + write gate)
tests/
├── unit/
│   ├── registry/
│   │   └── domes.test.ts            # DomeRegistry + path validation (6+ tests)
│   ├── auth/
│   │   ├── user-store.test.ts       # UserStore CRUD + tokens (10+ tests)
│   │   ├── token-validation.test.ts # Token format + bcrypt verify (5+ tests)
│   │   └── access-controller.test.ts # RBAC + confidentiality gates (12+ tests)
│   └── cli/
│       ├── dome-commands.test.ts    # dome create/list/info/delete (6+ tests)
│       └── user-commands.test.ts    # user create/grant/revoke/token (6+ tests)
└── integration/
    └── auth-workflow.test.ts        # End-to-end: create user → grant → MCP call → verify (5+ tests)
```

## Ficheros modificados

```
projects/savia-vaults/src/
├── cli/index.ts                     # +dome/user/confidentiality commands, serve multi-dome
├── server/mcp.ts                    # +AccessController en cada tool, +vault param, +vault_domes tool
├── server/a2a.ts                    # +vault routing, +auth middleware, rate limiter per dome
├── types.ts                         # +DomeInfo, +VaultRegistry, +ConfidentialityLevel types
└── .gitignore                       # +savia-vaults.users.json
```

---

## OpenCode Implementation Plan (SPEC-110)

### Classification
- **Complexity:** HIGH (7 slices, 3 nuevos modulos, auth system)
- **Risk:** MEDIUM (auth desde cero; sin deuda de compatibilidad)
- **Parallelizable:** Parcial (Slices 3+1 secuencial, Slices 4+6 secuencial, Slice 2 integra todo)
- **Test surface:** ~55 tests nuevos + 125 existentes = ~180 total

### Implementation Strategy
- **Agent:** typescript-developer (single agent, secuencial por dependencias)
- **Review:** code-reviewer post-implementation
- **Gates:**
  - Gate 1 (post-Slice 3): `npm test` → dome registry + dome CLI tests pass (~10 new)
  - Gate 2 (post-Slice 6): `npm test` → user store + user CLI tests pass (~25 new)
  - Gate 3 (post-Slice 5): `npm test` → all new + existing pass. Auth smoke: `SAVIA_AUTH_TOKEN=sv_xxx vault_read`
  - Gate 4 (post-Slice 7): `npm run build && npm run typecheck && npm test` → full green (~180 tests)
- **Security review:** Obligatorio (auth + tokens). Invocar `security-guardian` post-Slice 5
- **Bootstrap:** `user create admin` → copiar token → configurar `SAVIA_AUTH_TOKEN` en `opencode.json` MCP env → servidor funcional
