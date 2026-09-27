---
status: APPROVED
approved_at: 2026-09-27
approval: "Operadora 2026-09-27: 'Redacta todas las specs que necesites y adelante con todas las propuestas en sprint nocturno'"
priority: P1
developer_type: agent-single
created: 2026-09-27
phase: A
risk: L2
related_specs: [SE-384, SE-343, SE-401]
origin: output/research/harness-mejoras-20260927.md (P2, inspirado en gentle-shell "Gentle Changes")
---

# SE-402 — Attributed Edit Ledger (registro de ediciones atribuidas)

## 1. Problema

En el sprint 2026-09-27 cuatro suites de test mutaban el repo real sin que nada
avisara: `.scm/` regenerado y restaurado con `git checkout`, `config/test-coverage.conf`
reescrito hasta 999, `output/` escrito por L27 y `.gitkeep` sembrados. Se
descubrieron por casualidad, días después. Hoy Savia no distingue un cambio que
hizo un agente a propósito de uno que apareció como efecto lateral.

## 2. Objetivo

Registrar cada escritura **exitosa** de una herramienta de edición (Edit, Write,
NotebookEdit) con su autor, y avisar en `pr-plan` de los ficheros cambiados que
nadie registró. No escanea el repo en cada turno: compara el diff del árbol con
el registro solo al preparar el PR.

## 3. Diseño

### 3.1 Registro

- Hook PostToolUse `Edit|Write|NotebookEdit` → `scripts/edit-ledger.sh record`.
- Destino: `~/.savia/edits/<session_id>.jsonl` (local, fuera del repo, CRIT-001).
  Override `SAVIA_EDIT_LEDGER_DIR` para tests.
- Registro por línea (JSON cerrado):
  `{"ts","session","agent","tool","path","sha256_after","repo_root","branch"}`.
  - `path` relativo a `repo_root`; ficheros fuera del repo se ignoran.
  - `agent` = `CLAUDE_AGENT_NAME` / `SAVIA_AGENT` si existe, si no `main`.
  - `sha256_after` del fichero tras la escritura (vacío si se borró).
- Solo tool calls exitosas: si `tool_response` indica error, no se registra.
- Nunca bloquea (exit 0 siempre); un fallo del ledger no rompe la sesión.
- Sin contenido del fichero en el ledger: solo ruta y hash.

### 3.2 Verificación (`edit-ledger.sh verify`)

- Entrada: `--base <ref>` (defecto `origin/main`) y `--since <ts>` opcional.
- Calcula ficheros cambiados en el árbol (commits `base..HEAD` + working tree).
- Un fichero está **atribuido** si existe un registro de cualquier sesión en ese
  `repo_root`/rama cuyo `sha256_after` coincide con el contenido actual, o con el
  contenido en algún commit de la rama.
- Exclusiones deterministas (derivados regenerados por herramientas conocidas):
  `.scm/**`, `.confidentiality-signature`, `docs/rules/INDEX.md`,
  `docs/rules/domain/INDEX.md`, `CHANGELOG.md`, `AGENTS.md`. La lista vive en
  `config/edit-ledger-exclusions.txt` y es auditable.
- Salida: lista de "cambios no atribuidos" y JSON con `--json`. Exit 0 siempre en
  modo advisory; `--strict` → exit 1 si hay no atribuidos.

### 3.3 Gate en pr-plan

- G19 "Edit attribution (advisory)": ejecuta `verify`, muestra WARN con la lista.
  No bloquea en v1. Promoción a bloqueante: decisión de la operadora tras 2
  semanas de datos (tasa de falsos positivos < 5%).

## 4. Criterios de aceptación

- AC1: Una escritura exitosa con Write/Edit añade exactamente un registro con los
  campos del §3.1; una fallida no añade ninguno.
- AC2: El ledger nunca contiene contenido de fichero, solo ruta y hash.
- AC3: `verify` marca como no atribuido un fichero modificado por un proceso que
  no pasó por Edit/Write (p. ej. `echo >> f` desde un test) y no marca uno escrito
  con Write.
- AC4: Las exclusiones de §3.2 no aparecen como no atribuidas.
- AC5: G19 existe en pr-plan, es advisory y no cambia el veredicto global.
- AC6: Hook < 50 ms p95 (medido con `benchmark-hook-dispatch.sh`).
- AC7: Tests BATS con fixture de repo git temporal; auditor ≥ 80.

## 5. Fuera de alcance

- Atribución de cambios hechos con Bash (sed, python). Quedan como no atribuidos:
  es la señal deseada; si generan ruido, se añade `edit-ledger.sh record --path`
  explícito en los scripts generadores (slice futuro).
- Bloqueo en v1.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Hook de registro | `.opencode/hooks/edit-ledger-record.sh` en `settings.json` PostToolUse `Edit\|Write\|NotebookEdit` | `tool.execute.after` en `savia-foundation.ts` invoca el mismo script vía bridge bash |
| Verificación | `scripts/edit-ledger.sh verify` | idéntico |
| Gate | `scripts/pr-plan-gates.sh` G19 | idéntico |

### Verification protocol

- [ ] El registro se produce en runtime OpenCode (test del plugin con payload simulado)
- [ ] Tests cubren ambos payloads (Claude Code `tool_input.file_path`, OpenCode `args.filePath`)
- [ ] Hook registrado en plugin `savia-foundation`

### Portability classification

- [x] **DUAL_BINDING**: script bash común; binding Claude Code (settings.json) y OpenCode (plugin) desde Slice 1.
