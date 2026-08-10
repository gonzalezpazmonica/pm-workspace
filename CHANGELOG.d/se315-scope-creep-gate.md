---
version_bump: minor
section: Added
---

### Added

- SE-315 Scope Creep Gate — detección de diffs fuera del alcance de la spec:
  - `scripts/scope-declare.sh`: extrae el alcance declarado de una spec
    (`declared_paths`, `root_dirs`, `spec_id`) desde tablas markdown de
    ficheros o menciones inline de paths. Output JSON.
  - `scripts/scope-creep-check.sh`: compara `git diff base..head` contra el
    alcance de la spec y clasifica cada fichero en `declared | related |
    unrelated`. Veredicto `IN_SCOPE | EXTRA_FILES | MIXED_SCOPE |
    NO_DECLARED` con recomendación accionable (keep/split/justify).
  - Gate G17 en `pr-plan-gates.sh` (report-only, nunca bloquea — AC-S2.4) que
    resuelve la spec del PR desde `.pr-summary.md`/commits/branch.
  - Job CI `Scope Creep (report-only)` con `continue-on-error: true`
    (AC-S3.2), emite veredicto como notice de GitHub Actions.
  - 18 tests BATS (`tests/test-scope-creep.bats`): AC-S1, AC-S2, AC-S3.

### Fixed

- Corregido el número de gate: la propuesta original usaba "G16", ya ocupado
  por el eval-lint de SE-316; se implementa como G17.

### Notes

- Pendiente de calibración (AC-S3.3 telemetría `scope.verdict`, AC-S3.4 5 PRs
  históricos) antes de promover a bloqueante.
