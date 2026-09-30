---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar e implementar'; decisiones: nivel + ACL opcional, filtrado de vault_rag al consultar, cambia la política un writer con acceso al documento, local sin usuarios todo permitido"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L3
related_specs: [SE-413, SE-417, SE-418, SE-410]
origin: línea L33 de Savia Labs (privada), slice S1 de autoridad (decisión D02); decisiones de la operadora del 2026-09-30
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-419 — Savia Files: permisos por documento (nivel y listas) en todas las vistas

## Problema

`vault_files` y `vault_rag` solo autorizan por cúpula:

- **Sin restricción por persona.** No hay forma de limitar un documento a unas
  personas concretas dentro de su cúpula: quien lee la cúpula lee todos sus
  ficheros.
- **El nivel del documento no se aplica.** Hoy es inocuo, porque al guardar no
  puede superar el de la cúpula. Deja de serlo si una cúpula se **reclasifica a la
  baja** en el registro (p. ej. N3→N2): sus documentos N3 pasarían a leerlos los
  `reader`.
- **Borrados en `vault_rag`.** Un documento borrado sigue saliendo hasta el
  siguiente sync.
- **El servicio no sabe quién llama:** `authorize()` no devuelve el usuario.

(Corregido durante la implementación: la primera versión decía que un documento N3
podía vivir en una cúpula N2 y leerlo un `reader`. No es posible: `add` lo rechaza
desde SE-413.)

## Decisiones (operadora, 2026-09-30)

| Tema | Decisión |
|---|---|
| Modelo | Nivel del documento con la tabla de roles de las cúpulas + listas opcionales `readers`/`writers` que **restringen** |
| Savia RAG | Filtrar cada hit de fichero con la política **actual** del documento al consultar; sin reindexar |
| Quién cambia la política | Un `writer` que pueda escribir ese documento (y `admin`) |
| Servidor local sin usuarios | Todo permitido, como hoy; nivel y listas se guardan y se aplican en cuanto existan usuarios |

## Modelo

`authorize(dome, action, tool)` devuelve el **principal** `{ username, role }`, o
`undefined` en modo local sin usuarios. Para un documento `doc` de la cúpula `D`:

```
nivel      = doc.confidentiality ?? D.confidentiality
puede leer = sin principal
          || role == admin
          || ( rol ≥ LECTURA_MIN[nivel]
               && (doc.acl.readers == null || username ∈ readers ∪ writers) )
puede escribir = sin principal
          || role == admin
          || ( rol ≥ ESCRITURA_MIN[nivel] && (doc.acl.writers == null || username ∈ writers) )
```

`LECTURA_MIN` y `ESCRITURA_MIN` son las tablas actuales de `AccessController`:

- **Lectura:** N1/N2 `reader`, N3 `writer`, N4 `admin`.
- **Escritura:** N1–N3 `writer`, N4 `admin`.

Las listas solo restringen, nunca amplían:

- `null` o ausente: se hereda de la cúpula.
- `[]`: nadie salvo `admin`.
- Ser autor no da ningún permiso.

Las listas viven en el payload del documento (`docs/<id>.json`), sellado en cúpulas
cifradas. **No van al ledger**: son nombres de usuario. El `metaHash` del manifiesto
(SE-418) ya cubre cualquier cambio hecho a mano.

## Solución

### 1. Principal (`src/server/mcp.ts`)

- `authorize` del servidor MCP devuelve la `Authorization` que ya calcula
  `AccessController`, o `undefined` sin usuarios.
- `FilesService` y `RagService` reciben
  `authorize: (...) => Promise<Principal | void>` (compatible con quien no devuelve
  nada: se trata como modo local).

### 2. Aplicación en `vault_files` (`src/files/policy.ts`, `service.ts`)

| Acción | Regla |
|---|---|
| `list` | Omite los documentos que no puede leer (sin contarlos) |
| `get`, `text`, `download` | `NOT_FOUND` si no puede leer (no se revela que existe) |
| `put` nuevo | El nivel pedido debe poder escribirlo quien sube; si no, `POLICY_DENIED` |
| `put` con `replaces`, `delete`, `reprocess` | Necesita poder escribir el documento; si no puede ni leerlo, `NOT_FOUND`; si solo lo lee, `POLICY_DENIED` |
| `policy` (nueva) | Cambia `confidentiality`, `readers` y `writers` de un documento |
| `operation`, `log`, `verify`, `recover` | Solo ids; siguen siendo de cúpula |

**La acción `policy`:**

- quien llama necesita poder **escribir el documento**;
- el nivel no puede superar el de la cúpula;
- los nombres de usuario deben ser válidos (1–64 caracteres `[A-Za-z0-9._-]`), sin
  duplicados, 256 como máximo;
- es una operación del ledger (`kind: policy`) con receipt;
- `idempotencyKey` es opcional;
- `expectedPolicyVersion` es opcional: si no coincide, `CONFLICT`, para que dos
  cambios simultáneos no se pisen;
- cada cambio incrementa `policyVersion` en el payload.

### 3. Aplicación en `vault_rag` (`src/rag/service.ts`)

- **Filtrado:** cada hit con `source.documentId` se comprueba contra la política
  **actual** del documento, leída del almacén con la caché de SE-414, y se descarta
  si no puede leerlo.
- **Documento borrado:** si ya no existe, el hit también se descarta. Así se cierra
  la ventana entre borrar y el siguiente sync.
- **Candidatos extra:** con principal, la búsqueda pide `min(k × 4, 200)` candidatos
  por cúpula antes de filtrar, para no devolver menos de `k` por culpa del filtro.
- **Aviso sin revelar nada:** el resultado declara `filtered: n` por cúpula (cuántos
  hits se ocultaron), sin ids.

### 4. CLI y MCP

- **CLI:** `savia-vaults files policy <id> --dome <c> [--level N3] [--readers a,b | --readers-inherit]
  [--writers a,b | --writers-inherit]`. La CLI local es del operador, sin ACL de
  red, como hoy.
- **MCP:** `vault_files action:"policy"` con `id`, `confidentiality?`, `readers?`,
  `writers?` (array o `null` para heredar), `expectedPolicyVersion?` e
  `idempotencyKey?`.
- **Consultas:** `get` devuelve `acl` y `policyVersion` a quien puede escribir el
  documento; a quien solo lee, solo el nivel.

## Criterios de aceptación

- **AC1** Con usuarios, un documento N3 de una cúpula reclasificada de N3 a N2
  queda oculto a un `reader`:
  - no lo ve en `list`;
  - `get`, `text` y `download` dan `NOT_FOUND`;
  - `vault_rag` no devuelve ninguno de sus chunks;
  - un `writer` sí lo ve en `list` y lee su texto.
- **AC2** Listas:
  - con `readers: ["ana"]`, `ana` (reader) lee y `luis` (reader) no;
  - con `readers: []`, solo `admin`;
  - con `writers: ["ana"]`, `ana` puede escribir y leer, y otro `writer` recibe
    `POLICY_DENIED` al escribir (aunque lo lea si `readers` lo permite);
  - `null` hereda de la cúpula.
- **AC3** `policy`:
  - un `writer` con acceso cambia nivel y listas: receipt `committed`, commit
    `policy` en el ledger sin nombres de usuario y `policyVersion + 1`;
  - un `writer` sin acceso al documento recibe `NOT_FOUND`;
  - un nivel mayor que la cúpula o un nombre de usuario no válido dan
    `INVALID_INPUT`;
  - un `expectedPolicyVersion` viejo da `CONFLICT`;
  - un `reader` recibe `POLICY_DENIED`.
- **AC4** El cambio vale al instante: tras endurecer la política, la siguiente
  `vault_rag` del usuario afectado ya no devuelve el documento, sin sync de por
  medio. Un documento borrado deja de salir en `vault_rag` antes del siguiente sync.
- **AC5** `put`:
  - un `writer` no puede crear un documento N4 (`POLICY_DENIED`);
  - `replaces`, `delete` y `reprocess` sobre un documento que no puede escribir
    fallan sin efecto.
- **AC6** Sin usuarios (modo local), todo sigue como hoy. Las listas se guardan y se
  aplican al crear el primer usuario.
- **AC7** En una cúpula cifrada, las listas no aparecen en claro en disco ni en el
  ledger. Editarlas a mano da `INTEGRITY` (SE-418).
- **AC8** Coste medido: `vault_rag` p50 con principal y filtro frente a sin él
  (300 ficheros), y `list` de 300 documentos.
- **AC9** La suite existente sigue en verde; las cúpulas sin `files.enabled` no
  cambian.

## Entregables (rutas)

- **Código:**
  - `projects/savia-vaults/src/files/policy.ts`, `projects/savia-vaults/src/files/service.ts`, `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/types.ts`;
  - `projects/savia-vaults/src/rag/service.ts`, `projects/savia-vaults/src/rag/types.ts`;
  - `projects/savia-vaults/src/server/mcp.ts`, `projects/savia-vaults/src/cli/files.ts`.
- **Tests:**
  - `projects/savia-vaults/tests/unit/files/policy.test.ts`;
  - `projects/savia-vaults/tests/integration/files/acl.test.ts`, `projects/savia-vaults/tests/e2e/mcp-files.test.ts`.
- **Documentación:**
  - `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`;
  - `.claude/skills/savia-vaults/SKILL.md`, `CHANGELOG.d/se419-savia-files-document-acl.md`;
  - `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Resultados (2026-09-30)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | `acl.test.ts`: cúpula reclasificada N3→N2 ⇒ el documento N3 no sale en `list`; `get`/`text`/`download` dan `NOT_FOUND` al reader; el writer lo lista y lee. En `vault_rag` no sale para nadie: el indexador ya omite lo que supera el nivel de la cúpula (SE-410) | OK |
| AC2 | `policy.test.ts` (reglas) + `acl.test.ts`: `readers` y `writers`, `[]` solo admin, `null` hereda, `filtered` sin ids | OK |
| AC3 | `acl.test.ts`: receipt `policy` y commit sin nombres de usuario, `policyVersion` 1, `CONFLICT`, `INVALID_INPUT`, `POLICY_DENIED`/`NOT_FOUND`; las listas no se muestran a quien solo lee | OK |
| AC4 | `acl.test.ts`: endurecer vale en la siguiente `vault_rag` sin sync; un borrado desaparece de `vault_rag` antes del sync. E2E MCP con dos tokens reales (writer y reader) | OK |
| AC5 | `acl.test.ts`: un writer no crea N4; `replaces`, `reprocess` y `delete` sin permiso dan `POLICY_DENIED`, sin efecto | OK |
| AC6 | `acl.test.ts`: modo local sin principal, todo permitido; la lista se aplica en cuanto hay principal | OK |
| AC7 | `acl.test.ts`: en N3 ningún fichero del almacén contiene el nombre de usuario de la lista; editar las listas a mano da `INTEGRITY` | OK |
| AC8 | Con 300 ficheros (la mitad restringidos), `vault_rag` p50 N2: 8,2 ms sin principal / 7,4 ms con filtro; N3: 7,6 / 7,0 ms. `list` p50: 2,5 / 1,5 ms (N2) y 2,4 / 2,1 ms (N3) | Publicado |
| AC9 | Suite completa: 681 tests en verde, lint y `tsc` limpios | OK |

### Desviaciones

1. **Premisa del problema corregida.** La primera versión de la spec decía que un
   documento N3 podía vivir en una cúpula N2 y leerlo un `reader`. No es posible:
   `add` rechaza un nivel mayor que la cúpula desde SE-413. El nivel por documento
   solo actúa si la cúpula se reclasifica a la baja, y ahí `vault_rag` ya estaba
   protegido por el indexador. Lo que aporta de verdad SE-419:
   - las listas por documento;
   - el principal en las autorizaciones;
   - el filtrado de `vault_rag` con la política actual, que además cierra la
     ventana de documentos borrados.
   AC1 y el apartado de notas se corrigieron en consecuencia.
2. **Denegaciones sin receipt.** `delete`, `reprocess` y `policy` sin permiso se
   deniegan dentro de la operación: dejan receipt `failed` (código
   `POLICY_DENIED`/`NOT_FOUND`) sin tocar datos. `put` con `replaces` o un nivel no
   permitido se deniega antes de abrir la operación, sin receipt.
3. **Usuarios de las listas.** No se comprueba que existan en el fichero de
   usuarios: el servicio de ficheros no lo lee, y un usuario creado después debe
   poder figurar ya. Se valida el formato del nombre.

## Esfuerzo

Agente 6–9 h · humano 1 h (revisión de las reglas de acceso y de los casos de
`vault_rag`).

## Dependencias

SE-413, SE-417, SE-418 y SE-410. Sin paquetes nuevos.

## Fuera de alcance

- **Nivel por nota markdown.** Una nota con `confidentiality` mayor que el de su
  cúpula ya queda fuera de `vault_rag` (el indexador la omite), pero `vault_read` la
  sirve igual a quien lee la cúpula. Es un hueco fuera de Savia Files; se propone
  como spec aparte.
- Clearance por usuario independiente del rol (diseño SF01).
- Epochs de política y fences de revocación de derivados (D10).
- Grupos de usuarios.
- ACL en A2A (no expone Savia Files).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files`, `vault_rag`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files policy` | bash | idéntico |

### Verification protocol

- [ ] Con dos tokens (reader y writer), `vault_rag` devuelve el documento N3 solo al writer en ambos frontends

### Portability classification

- [x] **PURE_NODE**
