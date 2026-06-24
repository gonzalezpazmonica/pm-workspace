## SE-222-S0 — resource: URI convention validator (2026-06-23)

### Added

- `scripts/spec-validator.sh` — Frontmatter validator for resource: URI convention. Scans `docs/propuestas/*.md` and `docs/rules/domain/*.md` and emits WARN findings when:
  - `origin:` field is present but `resource:` is absent (MISSING_RESOURCE)
  - `resource:` field is present but not a valid URI (INVALID_RESOURCE_URI)
- `docs/rules/domain/spec-resource-uri.md` — Canonical rule documenting the convention.
- `tests/test-spec-validator.bats` — Tests covering argument parsing, frontmatter detection, both rules (positive + negative paths), `--strict` mode, `--json` output, and `--batch` mode. Certified by test-auditor (≥80).

### Changed

- `docs/propuestas/SE-216-evo-patterns.md` — Added `resource: "https://github.com/evo-hq/evo"`.
- `docs/propuestas/SE-217-autoresearch-patterns.md` — Added `resource: "https://github.com/karpathy/autoresearch"`.
- `docs/propuestas/SE-218-codebase-memory-patterns.md` — Added `resource: "https://github.com/DeusData/codebase-memory-mcp"`.
- `docs/propuestas/SE-219-abtop-patterns.md` — Added `resource: "https://github.com/graykode/abtop"`.
- `docs/ROADMAP.md` — Added Era 208 OKF Adoptable Patterns section + repriorized backlog 2026-06-20 with SE-222 S0-S3 entries.

### New

- `docs/propuestas/SE-222-okf-adoptable-patterns.md` — Spec proposing OKF v0.1 adoptable patterns (resource: URI, log.md convention, index.md auto-gen). Discarded: portability inter-org, OKF as export bundle, external SDK. S0 implemented in this PR; S1+S2 in follow-up PRs; S3 (back-fill 20 specs) is P3.

### Rationale

SE-222 S0 first slice of Era 208 in backlog priorizado 2026-06-20. Inspired by Google Cloud OKF v0.1 (2026-06-12) as formalization of the LLM-wiki pattern. Three OKF conventions adopted (resource:, log.md, index.md) without touching the N1-N4b dome model. See `docs/propuestas/SE-222-okf-adoptable-patterns.md` for the discarded patterns and why.

### Tests

- `bats tests/test-spec-validator.bats`: full suite passing
- `bash scripts/test-auditor.sh tests/test-spec-validator.bats`: certified
- `bash scripts/spec-validator.sh --batch docs/propuestas/`: backfill reduces total findings; full back-fill deferred to S3

### Ref

- Spec: `docs/propuestas/SE-222-okf-adoptable-patterns.md`
- Origin: análisis comparativo OKF Google Cloud 2026-06-20 vs modelo de cúpulas Savia
- Resource: https://github.com/GoogleCloudPlatform/knowledge-catalog
