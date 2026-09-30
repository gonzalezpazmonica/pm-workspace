---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar e implementar'; decisiones: KEK en fichero 0600 aparte, índice RAG cifrado, N3/N4 siempre y N1/N2 opcional, backup incluido"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L3
related_specs: [SE-413, SE-414, SE-415, SE-416, SE-410]
origin: línea L33 de Savia Labs (privada), slice de cifrado en reposo; decisiones de la operadora del 2026-09-30 (clave en fichero aparte, índice RAG cifrado, N3/N4 siempre, backup incluido)
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-417 — Savia Files: cifrado en reposo, borrado criptográfico y copia de seguridad

## Problema

Hoy todo lo que guarda Savia Files está en claro en disco:

- **Originales** (`blobs/`) y **texto extraído** (`extract/`).
- **Metadatos** (`docs/<id>.json`): nombre, etiquetas y SHA-256 del original.
- **Índice de Savia RAG**: una copia del texto de cada chunk más sus vectores.
- **Copias temporales** que se pasan al extractor y a ClamAV.

Una cúpula N3/N4 puede contener contratos o datos personales. Cualquiera que copie
el disco, el almacén o un backup los lee. Además, **los originales no tienen copia
de seguridad**: el backup nocturno solo copia los repos markdown de tres cúpulas.

## Decisiones (operadora, 2026-09-30)

| Tema | Decisión |
|---|---|
| Dónde vive la clave de cúpula (KEK) | Fichero `0600` en `~/.savia-vaults/keys/files/<cúpula>/`, fuera del almacén y de git |
| Índice RAG de cúpulas cifradas | Se cifra también; solo se descifra en memoria |
| Qué cúpulas | N3/N4 siempre; N1/N2 si `files.encryption: true` |
| Copia de seguridad | En esta spec: almacén en el backup nocturno; la clave, por otro canal |

## Modelo de amenazas

**Protege frente a:**

- copia o filtración del almacén, del índice RAG o del backup (Nextcloud incluido)
  sin la carpeta de claves;
- manipulación de cualquier fichero cifrado, que se detecta y falla cerrado;
- recuperación de un documento borrado desde un backup antiguo (borrado criptográfico).

**No protege frente a:** alguien con acceso a la cuenta del usuario, que puede leer la
KEK; ni frente a un proceso de Savia comprometido, que ve el texto en memoria. Se
dice así en la documentación.

## Solución

### 1. Claves (`src/files/keys.ts`)

```
~/.savia-vaults/keys/files/<cúpula>/     (0700; nunca dentro de git)
  kek                 32 bytes aleatorios (0600)
  wraps/<revisionId>  DEK de la revisión envuelta con la KEK (0600)
```

- **DEK por revisión**: 32 bytes aleatorios, envuelta con la KEK mediante
  `crypto_aead_xchacha20poly1305_ietf`. Los datos asociados (AAD) son
  `{schemaVersion, domeId, documentId, revisionId, artifactKind:"dek"}` serializados
  en JSON canónico (RFC 8785).
- **Subclaves de la cúpula** derivadas de la KEK con `crypto_kdf`: `meta` (metadatos),
  `index` (índice RAG) y `name` (nombres de blob por HMAC).
- **Borrado criptográfico**: borrar o deshacer una revisión borra su `wraps/<id>`. Sin
  ella, el original y la extracción son irrecuperables en cualquier copia.
- **Rotación**: `files keys rotate --dome` genera una KEK nueva, re-envuelve todas las
  DEK y re-sella metadatos e índice. Las identidades no cambian.

### 2. Formatos cifrados (libsodium, sin criptografía propia)

- **Originales**: `blobs/<HMAC(name, revisionId)>`, con
  `crypto_secretstream_xchacha20poly1305`.
  - Estructura: cabecera de 24 bytes, después frames de `uint32BE longitud` +
    ciphertext; cada frame lleva como mucho 1 MiB en claro.
  - `TAG_FINAL` obligatorio en el último frame, aunque esté vacío.
  - AAD con `artifactKind:"original"`.
  - Al leer se verifica el SHA-256 del original descifrado (el del manifiesto).
- **Extracción**: `extract/<revisionId>.json` cifrado con la DEK de la revisión
  (`artifactKind:"extract"`). El digest de SE-414 se calcula sobre el ciphertext.
- **Metadatos**: `docs/<id>.json` = `{id, v:1, sealed}`, donde `sealed` es el
  documento completo cifrado con la subclave `meta`. En claro solo quedan el id y la
  versión del formato.
- **Sin deduplicación** entre documentos en cúpulas cifradas.
- La criptografía viene de `libsodium-wrappers` (npm, ISC; dependencia autorizada por
  la operadora).

### 3. Copias temporales

El worker y ClamAV necesitan el fichero en claro. Se descifra en `/dev/shm`
(memoria, `0700`/`0600`) si existe; si no, en `<files home>/.work` (`0700`). Se borra
al terminar, también si falla. Nunca queda un original en claro en disco persistente
en Linux.

### 4. Índice RAG cifrado (`src/rag/store.ts`)

`FlatVectorStore` acepta un cifrador opcional. En las cúpulas cifradas, `chunks`,
`vectors` y `bm25` se escriben sellados con la subclave `index`
(`crypto_aead_xchacha20poly1305_ietf`, AAD con cúpula, generación y `seq`) y se
descifran solo en memoria al cargar. El manifiesto de la generación queda en claro
porque solo contiene ids opacos, hashes y el contrato.

### 5. Política y migración

- Cúpula N3/N4 con `files.enabled`: cifrado obligatorio. Cúpula N1/N2: si
  `files.encryption: true`.
- **Migración automática** bajo lock en el primer acceso de escritura o con
  `files encrypt --dome`:
  - se cifran los originales, extracciones y metadatos existentes;
  - se borran los ficheros en claro;
  - se reconstruye el índice RAG de la cúpula.

  `status` informa de la cúpula y de su estado de cifrado.
- **Sin KEK en una cúpula ya cifrada** (clave perdida): todas las operaciones fallan
  con `KEY_MISSING` y un mensaje que remite a la restauración de claves. Nunca se crea
  una clave nueva en silencio.

### 6. Copia de seguridad

- **Almacén**: el backup nocturno (`scripts/vaults-backup-cron.sh`) añade
  `~/.savia-vaults/files` completo en un tar por día, rotado igual que las cúpulas y
  subido a Nextcloud. Las cúpulas cifradas viajan cifradas; las N1/N2 sin cifrar
  viajan como hoy sus notas markdown.
- **Claves**, por otro canal y nunca a Nextcloud:
  - copia local rotada `~/.savia-vaults/backups/keys/` (`0600`);
  - `files keys export --out <fichero>`: fichero de recuperación de todas las KEK,
    cifrado con una frase de recuperación (Argon2id `crypto_pwhash` +
    `crypto_secretbox`) que Savia genera y muestra una sola vez.

  Savia explica al PM que guarde el fichero y la frase fuera del ordenador (gestor
  de contraseñas).
- **Restauración**: `files keys import <fichero>` y la guía de restauración en
  `docs/files.md`.

## Criterios de aceptación

- **AC1** En una cúpula N3, tras `put` de un PDF, ningún fichero bajo el almacén, el
  índice RAG ni `/tmp` contiene el texto, el nombre ni el SHA-256 del original
  (búsqueda de bytes en disco). `download` devuelve bytes idénticos y `vault_rag`
  cita la página.
- **AC2** Un bit cambiado en un original, una extracción, un manifiesto o un fichero
  del índice, o un frame reordenado o truncado, falla cerrado (`INTEGRITY`) sin
  servir datos parciales.
- **AC3** Borrado criptográfico: tras `delete`, una copia previa del almacén (backup)
  no permite recuperar el original aunque se tenga la KEK.
- **AC4** Rotación: tras `files keys rotate` todo sigue legible, la KEK antigua ya no
  descifra nada y las identidades (`documentId`, `revisionId`) no cambian.
- **AC5** Migración de una cúpula en claro con documentos (incluido el formato de
  SE-414) sin pérdida; no quedan ficheros en claro y el RAG vuelve a citar.
- **AC6** Sin KEK en una cúpula cifrada: `KEY_MISSING` con mensaje llano; no se crea
  una clave nueva.
- **AC7** Backup y restauración: el tar nocturno del almacén y el fichero de
  recuperación de claves permiten restaurar en un directorio vacío y descargar
  bytes idénticos. Nextcloud nunca recibe la carpeta de claves.
- **AC8** Las copias temporales en claro se crean en `/dev/shm` y desaparecen
  también si el worker falla o se agota el tiempo.
- **AC9** Coste medido: `put` y `download` de un PDF de 10 MB y consulta RAG en una
  cúpula cifrada frente a una sin cifrar. Se publican los números.
- **AC10** Las cúpulas N1/N2 sin `files.encryption` no cambian; la suite existente
  sigue en verde.

## Entregables (rutas)

- Código: `projects/savia-vaults/src/files/keys.ts`, `projects/savia-vaults/src/files/crypto.ts`,
  `projects/savia-vaults/src/files/store.ts`, `projects/savia-vaults/src/files/extract.ts`,
  `projects/savia-vaults/src/files/service.ts`, `projects/savia-vaults/src/files/rag-source.ts`,
  `projects/savia-vaults/src/files/setup.ts`, `projects/savia-vaults/src/files/types.ts`,
  `projects/savia-vaults/src/rag/store.ts`, `projects/savia-vaults/src/rag/indexer.ts`,
  `projects/savia-vaults/src/rag/service.ts`, `projects/savia-vaults/src/registry/domes.ts`,
  `projects/savia-vaults/src/cli/files.ts`, `projects/savia-vaults/src/server/mcp.ts`,
  `projects/savia-vaults/package.json`, `scripts/vaults-backup-cron.sh`.
- Tests: `projects/savia-vaults/tests/unit/files/keys.test.ts`, `projects/savia-vaults/tests/unit/files/crypto.test.ts`,
  `projects/savia-vaults/tests/unit/files/store.test.ts`, `projects/savia-vaults/tests/unit/rag/store.test.ts`,
  `projects/savia-vaults/tests/integration/files/encryption.test.ts`, `projects/savia-vaults/tests/unit/files/setup.test.ts`.
- Documentación: `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/CHANGELOG.md`,
  `.claude/skills/savia-vaults/SKILL.md`, `CHANGELOG.d/se417-savia-files-encryption.md`,
  `docs/propuestas/planning-state.json`, `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Esfuerzo

Agente 9 h · humano 1 h (revisión de seguridad del formato y del modelo de amenazas).

## Dependencias

SE-413 a SE-416 y SE-410. npm `libsodium-wrappers` 0.8.4 (ISC).

## Fuera de alcance

- Cifrado de las notas markdown de la cúpula (siguen en su repo git).
- Llavero del sistema y contraseña de arranque.
- Backend S3.
- Acceso aleatorio a rangos de un original cifrado (se descifra en secuencia).
- Restauración verificada automática y ensayos de caos (slice S7 de L33).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files`, `vault_rag`) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files encrypt/keys` | bash | idéntico |

### Verification protocol

- [ ] `vault_files put`/`download` en una cúpula N3 devuelven bytes idénticos en ambos frontends

### Portability classification

- [x] **PURE_NODE** (libsodium en WebAssembly; `/dev/shm` si existe)
