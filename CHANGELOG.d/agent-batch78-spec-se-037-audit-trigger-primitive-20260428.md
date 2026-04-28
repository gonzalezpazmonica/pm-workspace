---
version_bump: minor
section: Added
---

## [6.17.0] — 2026-04-28

Batch 78 — SPEC-SE-037 IMPLEMENTED. Append-only JSONB audit trigger as compliance primitive — primer ítem cerrado de Era 232 (Savia Enterprise Balance Extensions). Critical Path #6 cerrado.

### Added

#### Regla canónica

- `docs/rules/domain/savia-enterprise/audit-trigger-primitive.md` — define el primitive de compliance: trigger function genérico `audit_trigger_fn()` adjuntable a cualquier tabla regulada via `CALL attach_audit('table'::regclass)`. Captura `{table_name, record_id, operation, old_row, new_row, user_id, agent_id, session_id, tenant_id, created_at}` en JSONB. Append-only por constraint (`REVOKE UPDATE, DELETE`). Multi-tenant RLS heredado de SPEC-SE-002. Diseño AFTER (no BEFORE). `current_setting(..., true)` silencia settings missing. Atribución MIT a `dreamxist/balance` `00006_audit_log.sql` (clean-room, no wholesale import).
- `docs/rules/domain/savia-enterprise/audit-retention.md` — retention policy obligatoria con 7 categorías regulatorias:
  - **Compliance evidence** (ISO-42001) → 5 años
  - **Billing / financial** → 10 años (EU commercial + tax law)
  - **Project / contract** → 10 años
  - **Agent activity / session** → 90 días
  - **User actions on personal data** → 3 años (GDPR Art. 30 + Recital 82)
  - **API keys / authentication** → 2 años
  - **System / DB schema** → forever (no PII, archived value)

#### CLI inspectors

- `scripts/enterprise/audit-search.sh` — búsqueda tabular con filtros `--tenant <uuid> / --table / --agent / --since` (acepta `Nd`, `Nh`, `Nm`, ISO-8601). Output con diff column computado de `old_row` vs `new_row` (claves cuyos valores cambiaron). Modo `--json` para integration. Falla graceful si `SAVIA_ENTERPRISE_DSN` ausente (exit 3 con mensaje documentado).
- `scripts/enterprise/audit-purge.sh` — DELETE selectivo con guards de seguridad:
  - REFUSES sin `--table` (no bulk purge)
  - REFUSES sin `--before <date|duration>`
  - REFUSES sin `--confirm` (default es dry-run con count + categoría preview)
  - REFUSES si retention policy doc ausente (exit 5)
  - REFUSES `--table all` / `--table *` / `--table audit_log` (self-purge, exit 6)
  - REFUSES si tabla no clasificada en retention doc (exit 7)
  - Post-purge log forensics en `output/audit-purge-log/YYYY-MM-DD.log` con sha256 hash de la retention policy al momento de la purga

#### Tests

- `tests/structure/test-audit-trigger-primitive.bats` — 36 tests certified. Cubre safety (×4), template SQL structure (×7), CLI negative cases (×8), edge cases (×5), retention doc structure (×3), rule doc structure (×4), spec ref reinforcement (×5).

### Re-implementation attribution

`dreamxist/balance` (MIT) — patrón fuente del trigger genérico. Clean-room: el SQL template se inspira en `00006_audit_log.sql` pero NO copia código verbatim — la lógica equivalente se reescribe respetando convenciones pm-workspace (RLS multi-tenant SPEC-SE-002, settings savia.* en lugar de Supabase-specific).

### Acceptance criteria

#### SPEC-SE-037 (8/12 + 4 deferred)
- ✅ AC-01 Tabla `audit_log` append-only (REVOKE UPDATE/DELETE en template)
- ✅ AC-02 Función `audit_trigger_fn()` table-agnostic capturando 9 campos
- ✅ AC-03 Procedure `attach_audit(regclass)` para agregar a tabla nueva
- ✅ AC-04 RLS multi-tenant respetado (SPEC-SE-002)
- ✅ AC-05 Doc retention policy en `audit-retention.md` con tabla por categoría
- ✅ AC-06 CLI `audit-search.sh` con filter tenant/table/agent/since
- ✅ AC-07 CLI `audit-purge.sh` requires --confirm + retention policy file
- 〰 AC-08 Tests pgTAP ≥8 — **DEFERRED**: pm-workspace no tiene Postgres en CI; pgTAP queda pendiente del repo Savia Enterprise. BATS ≥6 SÍ cumplido (36 tests certified).
- ✅ AC-09 SQL template `docs/propuestas/savia-enterprise/templates/audit-trigger.sql` (ya existía desde batch 71)
- ✅ AC-10 Doc `docs/rules/domain/savia-enterprise/audit-trigger-primitive.md`
- 〰 AC-11 Migration: attach_audit a 5 tablas regulated existentes — **DEFERRED**: pm-workspace es repo de config Claude Code; las migrations a tablas reales se aplican en el repo Savia Enterprise post-deploy.
- ✅ AC-12 CHANGELOG entry

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` en ambos CLI.
- `audit-purge.sh` con 6 layers de safety: --table required, --before required, --confirm required, retention doc required, no bulk purge, no self-purge, table-must-be-classified.
- Cero red, cero git operations, cero modificación a `audit_log` desde el script search-only.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-se-037-...`, sin push automático ni merge.

### Spec ref

SPEC-SE-037 (`docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md`) → IMPLEMENTED 2026-04-28. AC-08 pgTAP + AC-11 attach a tablas reales DEFERRED hasta repo Enterprise. Era 232 abierto con primer item; próximos #7 SPEC-SE-036 (M 10-14h JWT mint) y #10 SPEC-SE-035 (M 12-16h reconciliation delta).
