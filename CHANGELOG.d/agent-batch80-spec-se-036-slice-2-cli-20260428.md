---
version_bump: minor
section: Added
---

## [6.19.0] — 2026-04-28

Batch 80 — SPEC-SE-036 Slice 2 IMPLEMENTED. Tres CLIs operacionales para gestionar API keys (create / list / revoke). Cierra AC-03 de SPEC-SE-036; completa el flujo CRUD que faltaba sobre la primitiva del Slice 1 (jwt-mint). Slice 3 (sunset PAT files + hooks) follow-up.

### Added

#### Operational CLIs

- `scripts/enterprise/api-key-create.sh` — genera key fresca de 32 bytes urandom (base64url, prefijo `savia_`), inserta `sha256(plaintext)` + `key_prefix` (8 chars UX) en `api_keys`, e **imprime el plaintext exactamente una vez** con warning destructivo. Soporta `--tenant <uuid>` (validado RFC4122 shape), `--scope <csv>`, `--desc "..."`. Exit codes 2 (usage) / 3 (DSN) / 4 (psql/openssl) / 5 (insert fail).
- `scripts/enterprise/api-key-list.sh` — inventario tabular o JSON. Filtros: `--tenant <uuid>`, `--active`, `--revoked`, `--json`. NUNCA muestra `key_hash` ni plaintext (zero-leakage por construcción). Mutually exclusive `--active` y `--revoked`. Validación UUID antes de DSN/psql checks.
- `scripts/enterprise/api-key-revoke.sh` — revoca por prefix de 8 chars con 4 safety layers:
  - `--prefix` requerido (no bulk)
  - REFUSES `all` / `*` / `%` / `""` (exit 6)
  - REFUSES wildcard chars (exit 6)
  - Dry-run por defecto (preview row + exit 0); requiere `--confirm` para ejecutar `CALL api_key_revoke(prefix, actor)`
  - `--actor` default `${USER}`, override para service accounts
  - WARNING explícito post-revoke: JWTs ya minteados sobreviven hasta TTL expiry (≤ 60 min)

#### Tests

- `tests/structure/test-api-key-cli-suite.bats` — 35 tests certified. Cubre file-level safety×6, create negative×5, list negative×4, revoke negative×5, edge×8 (boundary, no-leak, dry-run, ttl-warning), spec ref×3, exit code documentation×3.

#### Doc updates

- `docs/rules/domain/savia-enterprise/agent-jwt-mint.md` — sección "CLIs operacionales (Slice 2)" añadida; "No hace" actualizado para reflejar que solo Slice 3 queda pendiente.

### Acceptance criteria

#### SPEC-SE-036 Slice 2 cierre

- ✅ AC-03 4 CLI commands (create, list, revoke, mint) — Slice 1 ya hizo `mint`; Slice 2 completa los 3 restantes
- 〰 AC-06 Hook `block-pat-file-write.sh` — **DEFERRED** Slice 3
- 〰 AC-07 `block-credential-leak.sh` PAT-shaped detection — **DEFERRED** Slice 3
- ✅ AC-09 Doc actualizado con Slice 2

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` en los 3 CLIs.
- `api-key-create.sh`: plaintext printado exactamente UNA vez, sin escritura a disco. Recuperación = revoke + recreate.
- `api-key-list.sh`: zero-leakage — la SQL SELECT explícitamente excluye `key_hash` y plaintext (`grep -qE "SELECT.*key_hash"` falla, enforced por test).
- `api-key-revoke.sh`: 4 safety layers (prefix required, no bulk, no wildcards, dry-run default + actor logging).
- Cero red, cero git operations.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-se-036-slice-2-...`, sin push automático ni merge.

### Spec ref

SPEC-SE-036 Slice 2 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`) → IMPLEMENTED 2026-04-28. Status spec: Slice 1 ✓ (batch 79), Slice 2 ✓ (batch 80), Slice 3 (hooks + sunset PAT) follow-up. Era 232: SE-037 closed (batch 78), SE-036 ~80% closed (queda Slice 3), próximo SE-035 reconciliation delta.
