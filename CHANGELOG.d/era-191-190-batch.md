# Era 191 + Era 190 — skill quality, vendor-agnostic, cross-audit

**Date:** 2026-06-06
**PR:** #823

## Era 191 — OpenCode/SCM alignment

- `scripts/opencode-cross-audit.sh` — drift detection .claude/ vs .opencode/ with --fix unidirectional sync (SPEC-OPC-CROSS-AUDIT)
- 83 files vendor-agnostic: replace exclusive "Claude Code" refs with OpenCode/AI-coding-assistant; CLAUDE_PROJECT_DIR fallback (SPEC-OPC-VENDOR-REFS)

## Era 190 — Skill discipline

- `scripts/skill-catalog-auditor.sh` — 9-criteria auditor, 99 skills (PASS:89 WARN:10 FAIL:0); --json/--skill/--fix-report flags (SE-084 Slice 1)
- G14 gate in `pre-push-bats-critical.sh` — blocks push if modified skill fails quality audit (SE-084 Slice 2)
- `extract-domain-entities.py` --export-glossary + --sync-graph — generates CONTEXT.md and syncs concepts to knowledge graph (SE-086 Slices 1+2)
- SE-081 (caveman/zoom-out/grill-me), SE-082 (architectural-vocabulary), SE-083 (tdd-vertical-slices) marked IMPLEMENTED

## Tests

+57 tests across 4 new BATS suites: test-opencode-cross-audit (20), test-skill-catalog-auditor (25), test-se-086-ubiquitous-language (12)
