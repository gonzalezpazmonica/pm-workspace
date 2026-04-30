---
version_bump: patch
section: Fixed
---

## [6.24.1] — 2026-04-30

Batch 86 — SPEC-SE-001 close-out. Audit del business-analyst (item #3 del top 10 Critical Path post-audit) reveló que SPEC-SE-001 estaba **funcionalmente IMPLEMENTED** en disco — `.claude/enterprise/` con subdirs + manifest.json + manifest.schema.json + extension-points.md + scripts/validate-layer-contract.sh + .claude/hooks/validate-layer-contract.sh registrado como PreToolUse Edit|Write — pero el frontmatter seguía PROPOSED. Este batch cierra formalmente el spec y añade BATS regression suite que enforce los 6 AC para evitar futuro drift.

### Fixed

#### Spec frontmatter

- `docs/propuestas/savia-enterprise/SPEC-SE-001-foundations.md` — PROPOSED → IMPLEMENTED. Todos los 6 AC verificados en disco con evidencia.

### Added

#### Tests de regresión

- `tests/structure/test-spec-se-001-foundations.bats` — 30 tests certified. Estructura por AC:
  - **AC-1 ×6**: `.claude/enterprise/` + 4 subdirectorios + README presente
  - **AC-2 ×5**: validator existe + bash -n syntax + detecta Core→Enterprise import + no false positive en Core limpio + real workspace pass
  - **AC-3 ×4**: manifest.json valid JSON + schema valid JSON Schema + version/savia_core_min_version/modules presentes + cada módulo tiene enabled+spec+description (schema compliance)
  - **AC-4 ×2**: extension-points.md exists + documenta los 6 EPs (agent registry, hook registry, RBAC, audit, tenant, compliance)
  - **AC-5 ×2**: contrato unidirectional documentado en validator + zero violaciones reales en workspace
  - **AC-6 ×3**: hook file exists + registrado como PreToolUse Edit|Write en settings.json + set -uo pipefail
  - Edge ×3: graceful con file inexistente, empty manifest modules object, zero módulos enabled (default)
  - Spec ref + frontmatter ×2: SPEC-SE-001 IMPLEMENTED + ref en test file
  - Coverage ×2: validator scan_file helper + CORE_PATHS array

### Why this matters

SPEC-SE-001 es el cimiento arquitectónico — Era 232+ y todos los specs SE-002+ asumen que el contrato Core ↛ Enterprise está activo. Sin frontmatter actualizado, el spec aparecía PROPOSED en el roadmap aunque el cimiento ya soportaba batches 78-83 implícitamente. El BATS regression catches futuro drift: si alguien borra `.claude/enterprise/`, deshabilita el hook PreToolUse, modifica manifest.schema.json sin migrar manifest.json, o introduce un import Core→Enterprise, los tests fallan en CI antes de mergear.

### Hard safety boundaries

- Cero modificación de código existente — solo el status frontmatter (1 línea) y nuevo BATS test.
- El BATS test usa subdirectorios temporales en `mktemp -d` para no modificar el workspace real durante runs.
- `set -uo pipefail` semantics aplicado en bats subshells.
- Cero red, cero git operations.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-se-001-foundations-slice-1-...`, sin push automático ni merge.

### Spec ref

SPEC-SE-001 (`docs/propuestas/savia-enterprise/SPEC-SE-001-foundations.md`) → IMPLEMENTED 2026-04-30 (close-out post-audit). Critical Path post-audit item #3 cerrado. Próximo per ROADMAP.md §6: SPEC-SE-008 licensing (item #5, ~16h Slice 1) o SPEC-SE-028 prompt-injection-guard (item #6, ~12h Slice 1) — ambos paralelizables y desbloquean fan-out del DAG SE.
