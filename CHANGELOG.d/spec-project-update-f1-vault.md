---
version_bump: minor
section: Added
---

### Added

- SPEC-PROJECT-UPDATE: macro spec for 6-phase project digestion pipeline (vault, captures, cross-source digest, knowledge graph, hybrid RAG).
- SPEC-PROJECT-UPDATE F1: per-project vault layout (projects/{slug}_main/{slug}-{user}/vault/) with 8-folder structure (00-Index, 10-Tasks, 20-Specs, 30-Decisions, 40-Risks, 50-Digests, 60-Inbox, 70-People, 80-Sessions).
- scripts/vault-init.py: idempotent vault scaffolder with 10 entity templates (pbi, decision, meeting, person, risk, spec, session, digest, moc, inbox).
- scripts/vault-validate.py: standalone YAML frontmatter validator (no pip deps), schema for 6 common + per-entity required fields, enum validation.
- .opencode/hooks/vault-frontmatter-gate.sh: PreToolUse hook (Edit|Write) blocking writes to vault/ without valid frontmatter.
- docs/rules/domain/vault-frontmatter.md: canonical rule for vault frontmatter requirements.
- SPEC-SPECIES-EVAL: binary checklist + LLM-as-judge framework for evaluating all Savia specs (inspired by Carrion species/eval pattern).
- SPEC-PROJECT-UPDATE §3.12: Quality Gate Vault — BQ-1..BQ-7 (binary) + LQ-1..LQ-5 (LLM-judge), implemented by scripts/vault-quality.py.
- SPEC-PROJECT-UPDATE §6.6, §7.6: spec-gaps.md deliverable for F4 agents and graph-build.py F5.
- SPEC-PROJECT-UPDATE §8.2: Hybrid RAG architecture (tree index + reasoning + embeddings rerank) replacing pure-embedding approach.

