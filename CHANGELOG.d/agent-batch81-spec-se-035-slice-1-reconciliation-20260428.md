---
version_bump: minor
section: Added
---

## [6.21.0] — 2026-04-28

Batch 81 — SPEC-SE-035 Slice 1+3 IMPLEMENTED. Reconciliation Delta Engine: primitive `tenant_reconciliation_status()` (template SQL ya existente desde batch 71) + CLI wrapper `reconciliation-status.sh` que renderiza tabla colored o JSON con tier verde/ámbar/rojo por dimensión + canonical rule doc. Cierra Era 232 (SE-035 + SE-036 + SE-037 todos parcial o totalmente cerrados). Critical Path #10 partial. Slice 2 (dispatch registry seed), Slice 4 (webhook+alerting), Slice 5 (CI ratchet baseline) follow-up.

### Added

#### CLI wrapper

- `scripts/enterprise/reconciliation-status.sh` — wrapper bash que itera dimensiones activas para un tenant y renderiza:
  - Tabla colored ANSI (verde/ámbar/rojo símbolo `●`) por defecto
  - `--json` mode con `jsonb_agg` para integración con dashboards externos
  - `--fail-on red|amber|green` modo CI gate: exit 7 si ≥1 dimensión está en el tier solicitado (precursor del Slice 5 ratchet baseline)
  - `--dimension <name>` filtra a una sola dimensión (útil para CI gates específicos)
  - Validación UUID antes de DSN/psql checks (fail-fast en arg validation)
  - 6 exit codes documentados: 2 (usage), 3 (DSN), 4 (psql), 5 (DB error), 7 (alarm triggered)

#### Canonical rule

- `docs/rules/domain/savia-enterprise/reconciliation-delta-engine.md` — define el modelo:
  - Tesis: dos imágenes del mundo (declared / computed), drift silencioso erosiona credibilidad/margen, primitive convierte drift en alerta del mismo día
  - Storage: `reconciliation_dimensions` registry + `reconciliation_alerts` append-only log
  - Primitive: `STABLE` no `IMMUTABLE` (queries leen tablas vivas) ni `VOLATILE` (permite cache intra-statement)
  - Plan de seed Slice 2: 4 dimensiones con queries conceptuales (backlog_sp, budget, capacity, knowledge_catalog_hash)
  - Estrategia recompute (on-demand / materialized view / trigger AFTER) con coste y trade-off por opción
  - Mitigaciones de recursión + race + webhook abuse (deferred a Slice 4)
  - Cross-refs SPEC-SE-002 (RLS), SPEC-SE-018 (billing consumer), SPEC-SE-022 (resource-bench consumer), SPEC-SE-023 (knowledge-federation consumer), SPEC-SE-024 (client-health rollup), SPEC-SE-037 (audit attach)

#### Tests

- `tests/structure/test-reconciliation-delta-engine.bats` — 40 tests certified. Cubre file-level safety×7, SQL template structure×5, delta-tier helper positive+edge×8, status CLI negative×6, edge structural×5, rule doc structure×6, exit codes + spec ref×3.

### Re-implementation attribution

`dreamxist/balance` (MIT) — patrón fuente position-vs-accumulated y función `get_reconciliation_status()`. Clean-room: el SQL template `reconciliation.sql` (batch 71) y el CLI `reconciliation-status.sh` son re-implementación; aquí se **generaliza** a una primitiva tenant-aware con dispatch por dimensión, no se copia código verbatim. Helper `delta-tier.sh` también pre-existente.

### Acceptance criteria

#### SPEC-SE-035 Slice 1+3 (4/10 + 4 deferred a Slices 2/4/5)

- ✅ AC-01 Función `tenant_reconciliation_status()` definida con 3 tiers (en template, batch 71)
- 〰 AC-02 4 dimensiones seed — **DEFERRED** Slice 2 (rule doc lista plan conceptual)
- 〰 AC-03 Vista materializada — **DEFERRED** Slice 3 follow-up (Slice 1+3 entregan on-demand CLI; vista materializada es optimización posterior)
- ✅ AC-04 CLI `reconciliation-status.sh <tenant>` con output ANSI
- 〰 AC-05 Trigger recompute on-write con webhook — **DEFERRED** Slice 4
- 〰 AC-06 Baseline ratchet bloquea regresión — **DEFERRED** Slice 5 (precursor: `--fail-on` exit 7 ya implementado)
- 〰 AC-07 pgTAP ≥10 — **DEFERRED** (no Postgres en pm-workspace CI); BATS ≥8 ✅ cumplido (40 tests certified)
- ✅ AC-08 Doc `docs/rules/domain/savia-enterprise/reconciliation-delta-engine.md`
- ✅ AC-09 SQL template `docs/propuestas/savia-enterprise/templates/reconciliation.sql` (batch 71)
- ✅ AC-10 CHANGELOG entry (este fragmento)

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` en `reconciliation-status.sh` y `delta-tier.sh`.
- UUID validation antes de DSN/psql checks (fail-fast en arg validation).
- `--fail-on` solo acepta `green|amber|red` (no levels custom; mantiene API limpia).
- Cero red, cero git operations.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-se-035-...`, sin push automático ni merge.

### Spec ref

SPEC-SE-035 (`docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md`) → Slice 1+3 IMPLEMENTED 2026-04-28. Status spec: Slice 1 ✓, Slice 3 ✓ on-demand CLI, Slice 2 (seed) + Slice 3 (materialized view) + Slice 4 (webhook) + Slice 5 (ratchet) follow-up. Era 232 cierra: SE-037 ✓ (batch 78), SE-036 Slice 1+2 ✓ (batches 79+80, Slice 3 follow-up), SE-035 Slice 1+3 ✓ (batch 81). Critical Path #6 + #7 + #10 todos parcial o totalmente cerrados.
