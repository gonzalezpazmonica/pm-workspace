## SE-151 — content-fingerprint skill + bioquimica frontmatter pilot (2026-06-19)

### Added
- scripts/content-fingerprint.sh: deterministic short content hash skill (sha256 truncated, lengths 8/16/32/64)
- .claude/skills/content-fingerprint/SKILL.md: skill with declarative bioquimica frontmatter (DOIs validated against api.crossref.org)
- tests/scripts/content-fingerprint.bats: 14 tests covering determinism, avalanche, length validation, dataset
- tests/fixtures/fingerprint/: 30 etiquetated fixtures (5 identical / 5 near-duplicate / 5 distinct pairs)
- tests/scripts/failure-pattern-memory-pattern-id.bats: 6 tests including byte-for-byte equivalence vs pre-SE-151
- docs/specs/SE-151-content-fingerprint-consolidation.spec.md: SDD spec with falsifiable AC
- docs/learning/biomimetic-investigation-protocol.md: reusable discipline from 2 sessions

### Changed
- scripts/failure-pattern-memory.sh:37 (compute_pattern_id) migrated to content-fingerprint skill
- scripts/test-auditor.sh:49 (audit hash) migrated to content-fingerprint skill
- scripts/ado-bridge.sh:36 documented as NOT migrated (cksum fallback retained)
- scripts/semantic-map.sh:78 documented as NOT migrated (shasum/nohash00 chain retained)

Both migrations verified byte-for-byte equivalent vs pre-SE-151 hash output.
