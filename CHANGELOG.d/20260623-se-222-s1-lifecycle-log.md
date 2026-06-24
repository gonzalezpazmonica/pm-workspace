## SE-222-S1 — LOG.md convention + spec-lifecycle.sh (2026-06-23)

### Added

- `scripts/spec-lifecycle.sh` — Helper that changes the `status:` field of a spec and appends a lifecycle entry to `docs/propuestas/LOG.md`. Modes:
  - `--spec PATH --status NEW_STATUS [--note "text"]` — transition + log entry
  - `--bootstrap` — create `LOG.md` from scratch with header + seed entry
  - `--dry-run` — preview without writing
- `docs/propuestas/LOG.md` — Append-only lifecycle log with header + 3 seed entries (SE-222 S0 PROPOSED→IMPLEMENTED implicit, SE-220 PROPOSED, log creation).
- `tests/test-spec-lifecycle.bats` — Tests covering argument parsing, canonical-status validation, dry-run, bootstrap, real transitions, LOG.md isolation (via `PROPUESTAS_DIR_OVERRIDE` and `LOG_FILE_OVERRIDE` env vars), and reverse-chronological order preservation.

### Rationale

SE-222 S1 second slice of Era 208 OKF Adoptable Patterns. Inspired by OKF's `log.md` convention (Google Cloud, 2026-06-12) and the LLM-wiki pattern. Complements `CHANGELOG.md` (code-centric, repo-wide) and `git log` (per-commit, no conceptual narrative) without replacing either.

The script accepts only canonical statuses (PROPOSED, DRAFT, APPROVED, ACCEPTED, IN_PROGRESS, IMPLEMENTED, REJECTED, DEPRECATED, SUPERSEDED, DONE, DISCARDED) to prevent typo-drift in spec frontmatter.

### Tests

- `bats tests/test-spec-lifecycle.bats`: full suite passing
- `bash scripts/test-auditor.sh tests/test-spec-lifecycle.bats`: certified

### Isolation

The script reads `PROPUESTAS_DIR_OVERRIDE` and `LOG_FILE_OVERRIDE` env vars when set, allowing BATS tests to redirect writes to a temp dir. Without these vars, the script writes to `docs/propuestas/LOG.md` as expected.

### Ref

- Spec: `docs/propuestas/SE-222-okf-adoptable-patterns.md` (Slice S1)
- Previous slice: PR #850 (SE-222 S0 resource: URI convention)
- Next slice: SE-222 S2 (propuestas/INDEX.md auto-generated)
