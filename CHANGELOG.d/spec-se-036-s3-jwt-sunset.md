# CHANGELOG — SPEC-SE-036 Slice 3: JWT Sunset + PAT Migration Tools

**Fecha**: 2026-06-24
**Spec**: `docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`
**Slice**: 3 — Migration + Sunset PAT Files

## Ficheros creados

- `.opencode/hooks/block-pat-file-write.sh` — PreToolUse hook (matcher Write|Edit).
  Master switch `SAVIA_PAT_BLOCK=on|off` (default `on`). Bloquea writes a paths con
  `pat`/`token`/`secret` en el nombre que no estén en .gitignore ni en carpetas de test/docs.
  Registrado en `.claude/settings.json` PreToolUse.

- `tests/bats/test-jwt-sunset-migration.bats` — 12 tests BATS. Todos pasan (12/12).

## Ficheros modificados

- `docs/rules/domain/savia-enterprise/agent-jwt-mint.md` — añadida sección completa
  "Migración PAT → JWT (Slice 3)" con subsecciones:
  - Verificar estado actual
  - Proceso de migración (pasos 1-5)
  - Después de 1 sprint (borrar archivo de credencial de forma segura)
  - Rollback (cómo volver al modelo anterior si algo falla)
  - Infraestructura de bloqueo activa (tabla resumen)

- `.opencode/hooks/block-credential-leak.sh` — añadido patrón `PAT_SHAPED_PATTERN`
  para detectar strings de 40+ caracteres `[A-Za-z0-9+/]{40,}` en comandos bash.
  El patrón excluye contextos seguros (`$(cat ...)`, `$VAR`, base64 encode/decode) y
  ya-detectados (AKIA, ghp_, eyJ, etc.) para minimizar falsos positivos.
  Referencia: SPEC-SE-036-S3 — añadido 2026-06-24.

- `.claude/settings.json` — registrado `block-pat-file-write.sh` en PreToolUse
  con matcher `Write|Edit`, timeout 5s.

## Acceptance criteria cubiertos (Slice 3)

- AC-06: Hook `block-pat-file-write.sh` bloquea escrituras a paths PAT. ✓
- AC-07: `block-credential-leak.sh` detecta PAT-shaped strings (40+ chars hex/base64). ✓
- AC-08: Tests BATS ≥8 → 12 tests, todos pasan. ✓
- AC-09: Doc `docs/rules/domain/savia-enterprise/agent-jwt-mint.md` con guía completa. ✓
- AC-11: CHANGELOG entry (este fichero). ✓

## No incluido en este CHANGELOG (Slices 1 y 2, ya implementados)

- `scripts/jwt-mint.sh` (S1)
- `scripts/enterprise/` api-key-create/list/revoke (S2)
- SQL template `docs/propuestas/savia-enterprise/templates/api-keys.sql` (S1)
