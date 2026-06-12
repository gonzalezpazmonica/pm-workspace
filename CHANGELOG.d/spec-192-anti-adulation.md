---
version_bump: patch
section: Added
---

### Added

- scripts/anti-adulation/lexical-strip.py + regex-patterns.json: Layer 1 deterministic detector for empty social validation patterns. Hook .opencode/hooks/sycophancy-strip.sh with 5 modes (off/shadow/warn/strip/block) registered in PostToolUse Task. Three new LLM judges added to Recommendation Tribunal (SPEC-125): sycophancy-judge (warn default), concession-judge (shadow), repetition-truth-judge (shadow). aggregate.sh extended fail-soft for the 3 optional SPEC-192 judges. New skill .opencode/skills/epistemic-humility/SKILL.md with replacement protocol. Updated radical-honesty.md with Enforcement section linking the three layers. Updated savia-ethical-principles.md §5 and §10 references. Telemetry to output/anti-adulation-telemetry.jsonl. 51 pytest + 17 bats green covering 20 positive examples, 20 legitimate courtesy negatives, all hook modes, JSON envelope handling. Spec PROPOSED in docs/propuestas/SPEC-192-anti-adulation-illusory-truth.md, P0, 18 ACs.

