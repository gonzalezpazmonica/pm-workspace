---
version_bump: minor
section: Added
---

## [6.18.0] — 2026-04-28

Batch 79 — SPEC-SE-036 Slice 1 IMPLEMENTED. JWT mint primitive en bash + canonical rule doc para sustituir PATs file-based de larga duración por API keys hashed + JWTs efímeros (default 900s = 15 min). CLAUDE.md Rule #1 pasa de convención a infraestructura. Critical Path #7 (Era 232) parcialmente cerrado: Slice 1 done, Slice 2 (CLI commands) y Slice 3 (sunset PAT files) follow-up.

### Added

#### Mint primitive

- `scripts/enterprise/jwt-mint.sh` — CLI bash que intercambia API key por JWT efímero HS256:
  - Verifica `sha256(key)` contra `api_keys` via `api_key_verify()` (template SQL ya existente desde batch 71)
  - Enforce subset-only (downscoping permitido, **never upscoping** — exit 8 si scope_subset ⊄ stored_scope)
  - TTL clamp `[60, 3600]` segundos, default 900 (15 min, AC-04)
  - Firma HS256 con `JWT_SIGNING_KEY` env (off-repo, mode 600 documentado)
  - base64url RFC 4648 §5 (`+ → -`, `/ → _`, strip `=`)
  - Records mint en `api_key_mints` via `api_key_record_mint()` (audit trail, sinergia SPEC-SE-037)
  - `--key-stdin` para evitar leak vía `ps` (NUNCA pasar key como bash arg)
  - 7 exit codes documentados: 2 (usage), 3 (DSN missing), 4 (signing key missing), 5 (psql/openssl missing), 6 (DB verify fail), 7 (key invalid/revoked), 8 (upscoping intent)

#### Canonical rule

- `docs/rules/domain/savia-enterprise/agent-jwt-mint.md` — define el modelo:
  - Storage: SHA-256 hashed keys + key_prefix (8 chars UX)
  - Mint flow: verify → subset check → HS256 sign → record
  - Diseño: HS256 (no RS256), `JWT_SIGNING_KEY` off-repo en `~/.savia/secrets/jwt-signing-key`, audit non-blocking
  - Cross-refs SPEC-SE-002 (RLS), SPEC-SE-037 (audit), SPEC-SE-004 (consumer)
  - Documenta Slice 2 + Slice 3 deferred items

#### Tests

- `tests/structure/test-jwt-mint-primitive.bats` — 36 tests certified. Cubre safety×3, template SQL structure×6, CLI negative×9 (incluye boundary/empty edge cases), edge×6, rule doc structure×6, spec ref reinforcement×2, exit codes×1, defaults×1.

### Re-implementation attribution

`dreamxist/balance` (MIT) — patrón fuente de hashed-key + key_prefix + RLS isolation. Clean-room: el SQL template `api-keys.sql` (batch 71) y el JWT mint en bash son re-implementación; el original Balance tiene el mint en TS edge function, ortogonal a este workspace.

### Acceptance criteria

#### SPEC-SE-036 Slice 1 (5/11 + 6 deferred a Slices 2/3)

- ✅ AC-01 Tabla `api_keys` con SHA-256 hash + key_prefix UX (template ya existente desde batch 71)
- ✅ AC-02 Función `mint_jwt()` con scope downscoping enforce (split: `api_key_verify` + `api_key_scope_is_subset` SQL helpers + `jwt-mint.sh` bash signer)
- 〰 AC-03 4 CLI commands (create, list, revoke, mint) — **DEFERRED** Slice 2: solo `mint` aquí; create/list/revoke en batch siguiente
- ✅ AC-04 JWT efímero ≤900s, scope mínimo signed (TTL clamp [60,3600])
- ✅ AC-05 Audit trail `api_key_mints` append-only (sinergia SPEC-SE-037)
- 〰 AC-06 Hook `block-pat-file-write.sh` — **DEFERRED** Slice 3
- 〰 AC-07 `block-credential-leak.sh` PAT-shaped detection — **DEFERRED** Slice 3
- 〰 AC-08 BATS ≥12 certified — ✅ cumplido (36 tests certified); pgTAP ≥6 **DEFERRED** (no Postgres en pm-workspace CI)
- ✅ AC-09 Doc `docs/rules/domain/savia-enterprise/agent-jwt-mint.md`
- ✅ AC-10 SQL template `docs/propuestas/savia-enterprise/templates/api-keys.sql` (batch 71)
- ✅ AC-11 CHANGELOG entry (este fragmento)

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` en `jwt-mint.sh`.
- `--key-stdin` flag explícito para evitar leak vía `ps`.
- Refuse de upscoping (exit 8): scope_subset MUST ⊆ stored_scope.
- TTL clamp `[60, 3600]` — refuse fuera de rango (DoS prevention).
- Audit log non-blocking (warning a stderr si `api_key_record_mint` falla, JWT sí emitido — disponibilidad operacional priorizada; auditoría reconstruible off-line).
- Cero red, cero git operations.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-se-036-...`, sin push automático ni merge.

### Spec ref

SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`) → Slice 1 IMPLEMENTED 2026-04-28. Status spec → IN_PROGRESS (Slice 2 + Slice 3 follow-up batches). Era 232 progresa: SE-037 closed (batch 78), SE-036 Slice 1 closed (batch 79), próximo Critical Path #10 SE-035 reconciliation delta o SE-036 Slice 2 (CLI commands).
