---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar e implementar'; decisiones: partir D02 a SE-419, ledger git local sin remoto en FilesHome, journal node:sqlite, clave de firma propia"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L3
related_specs: [SE-413, SE-414, SE-415, SE-416, SE-417]
origin: línea L33 de Savia Labs (privada), slice S1/S2 de durabilidad (decisiones D01 y D03); decisiones de la operadora del 2026-09-30 (ledger git local en FilesHome, journal node:sqlite, clave de firma propia, D02 en spec aparte)
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-418 — Savia Files: ledger git privado, journal de operaciones y receipts firmados

## Problema

Hoy el estado de Savia Files es un fichero JSON por documento (`docs/<id>.json`),
reescrito en sitio bajo un lock. Eso deja cuatro huecos:

- **Sin historia ni autoridad verificable.** Nadie puede decir qué había en una
  cúpula ayer ni probar que un manifiesto no se ha tocado a mano.
- **Operaciones a medias.** Si el proceso muere entre guardar los bytes y escribir el
  manifiesto, o durante la extracción, quedan revisiones `PENDING` para siempre y
  blobs huérfanos. El cliente no sabe si su `put` llegó.
- **Reintentos duplican.** Un cliente que reintenta un `put` por un timeout crea una
  segunda revisión.
- **Sin comprobante.** Un `put` o un `delete` no devuelve nada que se pueda verificar
  después.

## Decisiones (operadora, 2026-09-30)

| Tema | Decisión |
|---|---|
| Alcance | D01 (manifiestos en git privado) + D03 (journal/outbox) + receipts. D02 (ACL por documento, clearance) en SE-419 |
| Dónde vive el git | Repo local por cúpula en `<FilesHome>/<cúpula>/ledger`, **sin remoto**, dentro del backup nocturno |
| Journal | `node:sqlite` (incluido en Node ≥ 22.13), WAL + `synchronous=FULL`, sin dependencia nueva |
| Firma de receipts | Clave Ed25519 propia de Savia Files, separada de KEK/DEK y de la de VaultSecurity |

## Modelo

```
<FilesHome>/<cúpula>/
  docs/<id>.json        payload del documento (nombre, etiquetas, revisiones); sellado si la cúpula está cifrada
  blobs/ extract/       sin cambios (SE-413..417)
  ledger/               repo git privado, sin remoto — AUTORIDAD
    manifests/<documentId>.json
    intents/<operationId>.json
    tombstones/<documentId>.json
  journal.db            node:sqlite — operaciones en curso, outbox, receipts
```

- **El ledger manda.** Un documento existe si y solo si su manifiesto está en el
  último commit del ledger. El payload debe coincidir con el `metaHash` del
  manifiesto: si no coincide, `INTEGRITY` sin fallback permisivo.
- **El journal no es una segunda autoridad.** Guarda lo que aún no está en git
  (operaciones pendientes, eventos del outbox) y los receipts. Si se pierde, se
  reconstruye desde los intents del ledger (los receipts antiguos se pierden, no
  los datos).
- No hay transacción global git/SQLite/blobs: hay un **protocolo de recuperación**
  (sección 4), no una ficción de atomicidad distribuida.

## Solución

### 1. Manifiesto en el ledger (`src/files/ledger.ts`)

Manifiesto compacto derivado del payload, JSON canónico (RFC 8785), `schemaVersion: 1`
estricto:

```json
{ "schemaVersion": 1, "documentId": "f_…", "currentRevision": "r_…", "metaHash": "<sha256 del payload>",
  "revisions": [{ "revisionId": "r_…", "index": 1, "blob": "<ref>", "size": 1234, "type": "pdf",
                  "extraction": { "status": "READY", "digest": "<sha256>" } }] }
```

**Nunca en git:**
- nombres, etiquetas o texto;
- rutas del sistema, tokens o claves.

En cúpulas cifradas, `blob` es el SHA-256 del **cifrado** y `metaHash` el del payload
sellado: el ledger no contiene el SHA-256 del original (mantiene SE-417 AC1). En
claras, `blob` es el SHA-256 del original.

**Commits:**
- **Uno por operación**, con los manifiestos tocados + `intents/<operationId>.json`
  (`{operationId, kind, at, documents[], idempotencyKeyHash?}`).
- **Borrar** quita el manifiesto y añade `tombstones/<documentId>.json` (`{documentId,
  deletedAt, operationId}`).
- **Configuración del repo:**
  - `git` del sistema con `-c core.hooksPath=/dev/null -c commit.gpgsign=false`;
  - identidad local `Savia Files`;
  - `git remote` vacío: si alguien añade un remoto, las escrituras fallan con
    `UNSAFE_HOME`.
- **Lotes:** un `putMany` de N ficheros es **una** operación y un commit. La
  extracción posterior es una segunda operación (`extract`).

**Lectura:**
- `readDoc` verifica en cada fallo de caché que `sha256(payload) === metaHash` del
  manifiesto.
- Si no coincide mientras otro proceso tiene el lock, espera al lock (≤
  `lockWaitMs`) y reintenta; si sigue sin coincidir, `INTEGRITY`.
- Un payload sin manifiesto no se lista ni se sirve.

### 2. Journal y outbox (`src/files/journal.ts`)

`node:sqlite` en `journal.db` (0600), WAL, `synchronous=FULL`, `busy_timeout=5000`,
migraciones versionadas en transacción.

| Tabla | Contenido |
|---|---|
| `operations` | `operation_id` PK, `kind`, `status` (`pending`/`committed`/`failed`), `idem_key_hash` UNIQUE, `request_hash`, `documents`, `commit_sha`, `error_code`, fechas |
| `outbox` | `id`, `operation_id`, `event` (`extract`, `rag-sync`), `payload` (ids), `status`, `attempts`, `next_at` |
| `receipts` | `operation_id` PK, receipt JSON firmado |

- **Nada sensible en el journal:**
  - ids, códigos de error y hashes de la petición;
  - nunca nombres, texto ni mensajes de error libres;
  - en cúpulas cifradas, tampoco el SHA-256 del original.
- **Idempotencia:** `idempotencyKey` opcional en `put`, `delete` y `reprocess`.
  - Se guarda su SHA-256.
  - Misma clave y misma petición: el mismo receipt, sin efecto nuevo.
  - Misma clave y otra petición: `IDEMPOTENCY_CONFLICT`.
- **Outbox al menos una vez, efectos idempotentes:**
  - `extract` re-extrae solo revisiones aún `PENDING`;
  - `rag-sync` llama a `onChange`;
  - los eventos pendientes se consumen al abrir la cúpula en el servicio, con
    reintentos y retroceso.

### 3. Receipts firmados (`src/files/receipts.ts`)

```ts
interface Receipt {
  operationId: string; dome: string; kind: string; documentId?: string; revisionIds?: string[];
  status: 'pending' | 'committed' | 'failed';
  commitSha?: string; manifestHash?: string; errorCode?: string;
  at: string; algorithm: 'Ed25519'; keyId: string; signature: string;
}
```

- **Firma:** Ed25519 (`node:crypto`) sobre `UTF8("savia-files-receipt-v1\n") +
  JCS(receipt sin signature)`, en base64url sin relleno. Los campos ausentes se
  omiten; nunca `null`.
- **Coherencia:**
  - `committed` exige un `commitSha` que exista en el ledger;
  - `pending` nunca lleva `commitSha`;
  - `failed` lleva `errorCode`.
- **Claves de firma:**
  - en `<keysHome>/signing/`: `<keyId>.pem` (0600) y `registry.json` con las
    públicas (`keyId`, clave raw de 32 B, `createdAt`, `retiredAt?`);
  - la rotación (`files keys rotate-signing`) conserva las públicas anteriores;
  - una clave que viene dentro del receipt no crea confianza: solo cuenta el
    registro.
- **Copia de seguridad:** el registro y las claves de firma entran en la copia
  sellada de claves (SE-417).

### 4. Protocolo de escritura y recuperación

Dentro del lock de la cúpula (reentrante):

1. `journal.begin(kind, idem)` deja la operación `pending`, o devuelve el receipt si
   es un reintento idempotente.
2. Efecto en el almacén (blobs, payload), como hoy.
3. `ledger.commit(opId, docsTocados)` regenera los manifiestos desde los payloads,
   escribe el intent y hace commit.
4. `journal.commit(opId, sha)` añade los eventos al outbox y firma el receipt.

**Qué pasa si algo falla:**

- **Fallo de git en el paso 3:**
  - la operación queda `pending` y la llamada falla con `COMMIT_PENDING` y el
    `operationId`, reintentable;
  - nunca se devuelve `READY` ni `accepted` sin commit.
- **Reconciliador:** corre al tomar el lock y cuando hay operaciones `pending`.
  - Si el intent ya está en git, la operación se marca `committed`.
  - Si los payloads de sus documentos existen y son legibles, completa el commit.
  - Si no, la cancela: deshace sus revisiones, borra los blobs huérfanos y deja el
    receipt `failed`.
- **Journal perdido o corrupto:** se aparta a `journal.db.corrupt-<fecha>`, se crea
  vacío y se reconstruye con las operaciones `committed` a partir de los intents.

### 5. Migración

- **Primera escritura en una cúpula sin ledger:** `git init` y una operación `import`
  con todos los documentos existentes, claros o cifrados. Es reanudable y no cambia
  ni bytes ni payloads.
- **Sin `git` en el sistema:** las escrituras fallan con `UNSUPPORTED` y un mensaje
  llano; las lecturas siguen funcionando. `files status` avisa. Savia ya requiere
  git para las cúpulas.

### 6. Superficie

- **Resultados:**
  - `put`/`putMany` devuelven `operationId` y `receipt`;
  - `delete` y `reprocess` también.
- **MCP `vault_files`:**
  - `idempotencyKey` en `put`, `delete` y `reprocess`;
  - acción nueva `operation` (`operationId`): estado y receipt.
- **CLI:**
  - `files verify --dome <c> [--deep]`: comprueba:
    - `git fsck` y que no haya remoto;
    - que cada manifiesto tenga su payload con el hash correcto, y al revés;
    - que existan los blobs (con `--deep`, también su hash);
    - la firma de los receipts y que su `commitSha` exista.
  - `files log --dome <c>`: operaciones, solo ids y fechas.
  - `files keys rotate-signing`.
- **Backup:** el tar nocturno ya incluye `ledger/` y `journal.db*`. Tras restaurar,
  `files verify` debe dar OK.
- `engines.node` pasa a `>=22.13.0`.

## Criterios de aceptación

- **AC1** Tras un `put` en N2 y en N3:
  - el receipt es `committed` y su `commitSha` existe en el ledger;
  - el commit contiene exactamente los manifiestos del lote y su intent;
  - el ledger (todo el historial) no contiene nombres, etiquetas, texto, rutas ni,
    en N3, el SHA-256 del original;
  - `git remote` está vacío.
- **AC2** Idempotencia:
  - reintentar un `put` con la misma `idempotencyKey` devuelve el mismo receipt y
    no crea revisión nueva;
  - la misma clave con otro contenido da `IDEMPOTENCY_CONFLICT`.
- **AC3** Recuperación, con fallos inyectados en cada paso del protocolo:
  - muerte tras guardar el payload y antes del commit: el siguiente acceso completa
    el commit y el receipt queda `committed`;
  - muerte antes del payload: la operación queda `failed`, sin documento visible y
    sin blob huérfano tras `gc`;
  - git no disponible: `COMMIT_PENDING` con `operationId`, nunca `READY`; al volver
    git, el reintento completa.
- **AC4** Autoridad:
  - un payload editado fuera de Savia da `INTEGRITY` al leerlo;
  - un payload sin manifiesto no se lista;
  - `files verify` informa de ambos;
  - un remoto añadido al ledger bloquea las escrituras.
- **AC5** Outbox:
  - si el proceso muere con una revisión `PENDING` ya confirmada, la siguiente
    apertura la extrae una vez;
  - repetir el evento no duplica nada;
  - Savia RAG recibe el `rag-sync`.
- **AC6** Receipts:
  - la firma se verifica contra el registro y cambiar un byte la invalida;
  - tras `rotate-signing`, los receipts antiguos siguen verificando;
  - la clave de firma es 0600 y distinta de la de VaultSecurity.
- **AC7** Migración:
  - una cúpula de SE-417 (clara y cifrada) queda con ledger y commit `import`, sin
    cambios en bytes ni payloads;
  - borrar `journal.db` y reabrir lo reconstruye desde los intents;
  - `files verify` da OK.
- **AC8** Coste medido y publicado:
  - `put` de un fichero pequeño y de 10 MB, p50, con y sin ledger;
  - `putMany` de 300 ficheros en como mucho 2 commits;
  - `list` de 300 documentos.
- **AC9** Backup y restauración: el tar nocturno restaurado en un directorio vacío
  pasa `files verify` y descarga bytes idénticos.
- **AC10** Las cúpulas sin `files.enabled` no cambian y la suite existente sigue en
  verde.

## Entregables (rutas)

- **Código:**
  - `projects/savia-vaults/src/files/ledger.ts`, `projects/savia-vaults/src/files/journal.ts`, `projects/savia-vaults/src/files/receipts.ts`;
  - `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/service.ts`;
  - `projects/savia-vaults/src/files/keys.ts`, `projects/savia-vaults/src/files/types.ts`;
  - `projects/savia-vaults/src/cli/files.ts` (la tool MCP se define en `service.ts`);
  - `projects/savia-vaults/package.json`, `projects/savia-vaults/vitest.config.ts`.
- **Tests:**
  - `projects/savia-vaults/tests/unit/files/ledger.test.ts`, `projects/savia-vaults/tests/unit/files/journal.test.ts`, `projects/savia-vaults/tests/unit/files/receipts.test.ts`;
  - `projects/savia-vaults/tests/unit/files/store.test.ts`, `projects/savia-vaults/tests/unit/files/service.test.ts`;
  - `projects/savia-vaults/tests/integration/files/ledger.test.ts`, `projects/savia-vaults/tests/e2e/files.test.ts`;
  - `projects/savia-vaults/tests/e2e/mcp-files.test.ts`, `projects/savia-vaults/tests/setup-isolation.ts`;
  - `tests/test-vaults-backup.bats`.
- **Documentación:**
  - `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`;
  - `.claude/skills/savia-vaults/SKILL.md`, `CHANGELOG.d/se418-savia-files-ledger.md`;
  - `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | Integración: lote de 2 ficheros en N2 y N3 ⇒ un commit con sus 2 manifiestos y el intent. Historia completa sin nombre, etiqueta, texto ni ruta; en N3, sin SHA-256 del original ni tipo. `git remote` vacío. Lector real + PDF del repo en N3: `READY`, receipt `committed`, 0 fugas en la historia | OK |
| AC2 | Integración: `put` y `delete` repetidos devuelven el mismo receipt, sin revisión nueva; otra petición con la misma clave da `IDEMPOTENCY_CONFLICT` | OK |
| AC3 | Integración: caída tras el payload ⇒ commit `(recuperada)`; caída antes ⇒ `failed`/`ABORTED`, sin commit, y `gc` limpia el blob; `index.lock` ⇒ `COMMIT_PENDING` con `operationId`, y el reintento con la misma clave completa | OK |
| AC4 | Integración: payload editado ⇒ `INTEGRITY`; payload sin manifiesto no se lista; `verify` da `PAYLOAD_MISMATCH` y `UNTRACKED_PAYLOAD`; con remoto ⇒ `UNSAFE_HOME` | OK |
| AC5 | Integración: revisión `PENDING` confirmada ⇒ `recover` la extrae una vez (una sola operación `extract`); outbox vacío al repetir; un `rag-sync` por operación | OK |
| AC6 | `receipts.test.ts` (firma, alteración, rotación, registro, snapshot/restore) + integración (0600, clave distinta tras rotar, `verify` sin problemas) | OK |
| AC7 | Integración: cúpulas N2 y N3 sin ledger ⇒ commit `import` con bytes y payloads idénticos; journal borrado ⇒ reconstruido (`import`, `put`); `verify --deep` OK | OK |
| AC8 | Ver tabla de coste en `docs/files.md`. `putMany` de 300 = 1 commit | Publicado |
| AC9 | Integración: tar de `files/` y `keys/` restaurado ⇒ `verify --deep` OK y bytes idénticos (N2 y N3); BATS: el tar nocturno incluye `ledger/` y `journal.db` | OK |
| AC10 | Suite completa: 668 tests en verde, lint y `tsc` limpios; BATS de backup 16/16 | OK |

**Coste (AC8, p50):**

| | Antes (SE-417) | SE-418 |
|---|---|---|
| `put` 1 KB, N2 / N3 | 1 / 3 ms | 28 / 39 ms |
| `put` 10 MB, N2 / N3 | 57 / 176 ms | 93 / 272 ms |
| `putMany` de 300 ficheros, N2 / N3 | 232 / 569 ms | 711 / 1 056 ms (1 commit) |
| `list` de ~320 documentos en frío, N2 / N3 | 10 / 17 ms | 21 / 24 ms |

La primera medición de `putMany` daba 1 489 ms: había un `fsync` del journal por
documento y por sección. Se corrigió en la desviación 5, sin cambiar la semántica.

### Desviaciones

1. **Lecturas durante una operación.** No esperan al lock, como decía la spec. Un
   payload que no coincide con su manifiesto se acepta solo si el journal registra
   una operación pendiente sobre ese documento; si no, `INTEGRITY` o `NOT_FOUND`.
   El documento se registra en el journal **antes** de escribir el payload.
   - Ventaja: sin esperas y sin falsos `INTEGRITY` durante una extracción larga.
   - Límite: una edición manual durante esa ventana entraría en el commit.
2. **Manifiesto sin `index`.** No lleva índice de revisión (el orden del array es
   el de creación). En cúpulas cifradas tampoco lleva `size` ni `type`, para
   mantener lo que SE-417 ocultaba.
3. **Operación fallida que tocó documentos** (p. ej. un lote deshecho por el
   antivirus): se confirma igualmente, con `errorCode` en el intent y receipt
   `failed` con `commitSha`. Así el ledger refleja siempre el disco. Sin documentos
   tocados, no hay commit.
4. **AC5, «la siguiente apertura».** El outbox se consume en la siguiente
   **escritura** o con `files recover` / `action:"recover"`, no en las lecturas:
   una lectura no debe lanzar una extracción de minutos.
5. **`synchronous=NORMAL`** para las escrituras frecuentes del journal (documento
   tocado, renovación del lease, reclamación del outbox). En WAL son durables
   frente a la caída del proceso. Los cambios de estado (`begin`, `commit`, `fail`)
   siguen en FULL y llevan esas páginas al disco. El payload tampoco se escribe con
   `fsync`, así que exigir más al journal no añadía garantía.
6. **Rutas y receipts.**
   - Las claves de firma están en `<keysHome>/_signing/`: el `_` no es un nombre de
     cúpula válido, así que no puede chocar con una.
   - El receipt lleva `refs[]` (lote) en vez de un solo `documentId`, y no lleva
     `byteHash`, que en N3 sería el SHA-256 del original.
7. **Aislamiento de tests.** La primera ejecución de la suite creó una clave de
   firma en `~/.savia-vaults/keys/files/_signing` real: varios tests no fijaban el
   almacén de claves. Corregido:
   - `tests/setup-isolation.ts` fija un directorio temporal;
   - `keysHome()` respeta el del proceso;
   - los e2e pasan `SAVIA_FILES_KEYS_HOME`.
   La clave creada se apartó a `/tmp`.
8. `scripts/vaults-backup-cron.sh` no cambia: su tar ya incluía `ledger/` y
   `journal.db`. Lo fija un test BATS nuevo.

## Esfuerzo

Agente 10–14 h · humano 1–2 h (revisión del protocolo de recuperación y del contenido
del ledger).

## Dependencias

SE-413 a SE-417. Node ≥ 22.13 (`node:sqlite`) y `git` del sistema. Sin paquetes npm
nuevos.

## Fuera de alcance

- ACL por documento, clearance y epochs de política (D02, SE-419).
- Streaming HTTP y tus (D09).
- Snapshots, CAS y barrier de publicación (D05).
- Purga del historial git (D10). El ledger conserva ids y hashes de documentos
  borrados; en cúpulas claras eso incluye el SHA-256 del original borrado. Se
  documenta.
- Replicación del ledger a un remoto.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files verify/log` | bash | idéntico |

### Verification protocol

- [ ] `vault_files put` con `idempotencyKey` devuelve el mismo receipt dos veces en ambos frontends

### Portability classification

- [x] **PURE_NODE** (`node:sqlite`, `node:crypto`; requiere `git` en el PATH)
