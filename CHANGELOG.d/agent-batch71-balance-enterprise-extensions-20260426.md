## [6.22.0] — 2026-04-26

Batch 71 — Savia Enterprise extensions desde análisis `dreamxist/balance` (MIT). 3 specs nuevas (SPEC-SE-035/036/037), 3 SQL templates de referencia, 1 helper bash compartido, 28 tests certified.

### Added (specs Era 232 PROPOSED)
- `docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md` — Drift detector tier verde/ámbar/rojo entre estado declarado y computado. 4 slices (M, 12-16h). P2 federation hardening. Generaliza el patrón position-vs-accumulated de Balance a `tenant_reconciliation_status()` reusable across knowledge-federation (SE-023), billing (SE-018), capacity (SE-022).
- `docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md` — API keys hashed (SHA-256 + key_prefix UI) + JWT efímero ≤900s con scope downscoping. 3 slices (M, 10-14h). P1 sovereignty. Sustituye PATs file-based de larga duración. CLAUDE.md Rule #1 pasa de "convención" a "infraestructura".
- `docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md` — 1 trigger function `audit_trigger_fn()` adjuntable a cualquier tabla regulada vía `CALL attach_audit('...')`. Slice único (S, 6-8h). P1 compliance baseline. Captura {table, record_id, op, old_row, new_row, user_id, agent_id, session_id, tenant_id} append-only por constraint. Cubre ISO-42001 Annex A, EU AI Act Art. 12, GDPR Art. 30 sin código repetido por superficie.

### Added (templates SQL)
- `docs/propuestas/savia-enterprise/templates/audit-trigger.sql` (137 LOC) — implementación completa lista para deploy. Append-only (REVOKE UPDATE,DELETE), RLS multi-tenant (SPEC-SE-002 contract), `attach_audit(regclass)` helper.
- `docs/propuestas/savia-enterprise/templates/reconciliation.sql` (108 LOC) — `tenant_reconciliation_status()` JSONB output, registry `reconciliation_dimensions` para 4 dimensiones seed, materialised view dashboard, alerts table.
- `docs/propuestas/savia-enterprise/templates/api-keys.sql` (123 LOC) — tabla `api_keys` (hash + prefix + scope[]), audit `api_key_mints`, función `api_key_verify()` (SHA-256), `api_key_scope_is_subset()`, `api_key_record_mint()`, `api_key_revoke(prefix, actor)`.

### Added (quick win — helper compartido)
- `scripts/enterprise/delta-tier.sh` — implementación bash del patrón verde/ámbar/rojo. Reutilizable desde cualquier comando pm-workspace (sprint-status, portfolio-overview, client-health, billing). Modos: text default / `--json` / `--color` (ANSI). 28 BATS tests, score 83 certified.
- `tests/enterprise/test-delta-tier.bats` — cobertura tier classification, custom thresholds, edge cases (negative delta, decimals, zero thresholds, non-numeric input rejection).

### Updated
- `docs/propuestas/savia-enterprise/README.md` — paso 9 incluye SE-035/036/037, sección "Templates SQL".
- `docs/ROADMAP.md` — bloque "Era 232 — Savia Enterprise Balance Extensions" añadido bajo Era 189.

### Why dreamxist/balance importa para Savia Enterprise

Balance es self-hosted personal finance (Supabase + TS) MIT, beta activa. La mayoría es irrelevante (Fintual, F29 chileno). Pero 3 patterns infra son domain-agnostic y llenan huecos reales en SPEC-SE-001…SPEC-SE-034:

- Reconciliation status (delta tier) → drift detector que falta en SE-023
- Hashed API key + JWT mint → ciclo de credencial que falta en SE-004 / Rule #1
- Audit JSONB trigger genérico → primitive reusable que falta entre SE-006 y SE-026

Re-implement, **NO** importar código wholesale (acoplado a su dominio peso/account_type). Vendor lock-in patterns rechazados explícitamente: Fintual (Chile-specific), Supabase como dependency (viola SE-005 sovereignty).

### License compatibility

Balance es MIT. Compatible con Savia Core MIT. Re-implementación clean-room, atribución explícita en cada template SQL y en cada spec.

### No incluye

- Implementación Postgres viva — los SQL templates son blueprints, no se aplican a una DB en este PR
- pgTAP tests reales — placeholders en specs; el cliente que despliegue los integra en su CI
- CLI scripts `audit-search.sh`, `audit-purge.sh`, `api-key-create.sh`, `jwt-mint.sh` — descritos en specs, implementación deferida a aprobación

### Spec ref
- `docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md` (PROPOSED)
- `docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md` (PROPOSED)
- `docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md` (PROPOSED)
