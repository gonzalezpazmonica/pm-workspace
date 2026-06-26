## SE-086 — Ubiquitous-language extractor (2026-06-24)

### Added
- `.opencode/skills/ubiquitous-language/SKILL.md`: 5-step DDD glossary skill (≤92 LOC, SE-084 compliant). Triggers: "extrae glosario", "ubiquitous language", "/glossary", or >5 repeated domain terms without CONTEXT.md. Clean-room re-implementation of mattpocock/skills/ubiquitous-language + domain-model (MIT).
- `scripts/extract-domain-entities.py` (370 LOC): reads memory-store JSONL or arbitrary input, extracts domain term candidates, cross-references against CONTEXT.md, outputs report with `new/existing/inconsistent` status columns. Modes: --report (default), --auto-update (adds [REVIEW]-marked terms), --export-glossary, --sync-graph.
- `scripts/knowledge-graph-domain-bridge.py`: emits DOMAIN_TERM edges between episodic memory entities and CONTEXT.md terms.
- `docs/rules/domain/ubiquitous-language.md`: canonical rule doc referencing script and CONTEXT.md format.
- CONTEXT.md format standardized: `# Domain Glossary — <Project>` header, `term|definition|status` table, status values: stable/[REVIEW]/[INCONSISTENT].

### Tests
- 47 BATS tests in `tests/test-se-086-ubiquitous-language.bats` (all pass).
- 30 BATS tests in `tests/test-ubiquitous-language.bats` (all pass).

### Status
- SE-086 APPROVED → IMPLEMENTED
