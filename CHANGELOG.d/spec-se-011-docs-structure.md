# SPEC-SE-011 — docs/ restructuring & navigation scaffold

**Date:** 2026-06-24  
**Spec:** SPEC-SE-011-docs-restructuring (PROPOSED → IMPLEMENTED)

## Added

- `scripts/docs-audit.sh` — audits docs/ structure, detects orphans, root-level candidates,
  and subdirs with >20 files. Outputs Markdown report or JSON (`--json`).
  CLI: `bash scripts/docs-audit.sh [--json] [--output PATH|auto]`

- `docs/STRUCTURE.md` — official taxonomy of docs/: Nivel 1 root files + 13 subcategory
  definitions with classification rules and frontmatter policy.

- `docs/INDEX.md` — navigable index: top 10 documents + grouped by use-case
  (sprint, implementation, architecture, security, enterprise, operations).

- `tests/bats/test-spec-se-011-docs-structure.bats` — 5 BATS tests verifying:
  script existence/executability, JSON validity, STRUCTURE.md sections,
  INDEX.md with ≥10 links, candidate detection >10 files.

## Notes

- No files moved. Zero reference breakage.
- docs/ root still has 109 .md files — STRUCTURE.md and docs-audit.sh provide
  the scaffold for incremental migration.
- docs-audit.sh detects 105 candidates for subcategory migration in current state.
