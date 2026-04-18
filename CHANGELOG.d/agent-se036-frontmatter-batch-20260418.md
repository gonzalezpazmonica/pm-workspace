---
version_bump: minor
section: multiple
---

SE-036 Slice 1 — frontmatter migration tooling + primer batch 15 specs. Era 234.

### Added
- **`scripts/spec-frontmatter-migrate.sh`**: herramienta mecánica para migrar specs con status en prosa (`> Status: **DRAFT**`) a YAML frontmatter canónico. Mapping fijo: DRAFT→Proposed, ACTIVE/IMPLEMENTING→IN_PROGRESS, READY→ACCEPTED, COMPLETE/DONE/PHASE N DONE→Implemented, REJECTED→Rejected, resto→UNLABELED. Preserva body intact (prepend-only). Modos --dry-run / --apply / --spec PATH / --limit N (max 50).
- **`tests/test-spec-frontmatter-migrate.bats`**: 32 tests — safety, CLI, mapping canónico (7 status types), estructura frontmatter, idempotencia, single-spec mode, negatives, edges. Auditor score 89.

### Changed
- **15 specs `docs/propuestas/SPEC-003..017`**: migradas a frontmatter YAML via la herramienta. Source of truth body-prose preservada. `status:` canónico + `origin_date:` + `migrated_at:` + `migrated_from: body-prose` (auditable).

### Resultados
`spec-status-normalize.sh --audit` reporta missing 111→96 (reducción 15 specs). Herramienta idempotente: `--apply` sobre specs ya migradas es no-op.

### Motivacion
ROADMAP Tier 1.4. Automation mecánica en vez de 30 edits manuales — cero judgment humano sustituido: si body dice DRAFT, frontmatter dice Proposed. Habilita grep/jq-tooling sobre 15+ specs previamente invisibles.
