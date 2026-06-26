# SPEC-INSTALLER-OPENCODE-MIGRATION: Instaladores Claude Code a OpenCode

**Date**: 2026-06-24
**Spec**: SPEC-INSTALLER-OPENCODE-MIGRATION
**Status**: IMPLEMENTED

## Que se implemento

Migracion de los instaladores de Savia para usar OpenCode como frontend primario.

## Ficheros creados

- `scripts/detect-frontend.sh` — Detecta frontends AI disponibles (opencode, claude, codex, cursor). Output JSON con campo `recommended`.
- `docs/setup/frontend-migration-guide.md` — Guia completa: que cambia, que no cambia, como migrar, rollback.
- `tests/bats/test-spec-installer-migration.bats` — 8 tests BATS.

## Ficheros modificados

- `.opencode/install.sh` — Cambiado `SAVIA_HOME` default de `~/claude` a `~/savia` (3 ocurrencias: header comment, help text, asignacion).

## Estado de los instaladores

| Fichero | Estado |
|---|---|
| `install.sh` | Ya estaba OpenCode-first (SAVIA_HOME=~/savia, step 3 OpenCode, banner opencode) |
| `.opencode/install.sh` | Corregido: SAVIA_HOME default ~/claude -> ~/savia |
| `install.ps1` | Fuera del alcance de esta sesion (Windows) |
| `.opencode/install.ps1` | Fuera del alcance de esta sesion (Windows) |

## Notas

- Claude Code NO se elimina. Solo se reordena la prioridad (opencode > claude_code > codex).
- `detect-frontend.sh` puede usarse por scripts de setup y documentacion para detectar el frontend disponible.
- Los scripts de setup (session-init-bootstrap.sh, setup-memory.sh, etc.) no contenian ~/claude hardcodeado en el momento de la implementacion; se verifica en los tests.
