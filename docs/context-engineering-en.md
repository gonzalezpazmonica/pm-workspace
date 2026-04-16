# Context Engineering Improvements — Documentation

> Improvements based on research from the AI Engineering Guidebook (2025), Anthropic Skills repo, and prompt structure best practices.

---

## Summary

This module introduces 5 improvements to pm-workspace's Context Engineering system, aligning it with best practices documented in the AI Engineering Guidebook and the 10-layer prompt structure model.

---

## Improvement 1: Example Patterns (Few-shot in Commands)

Concrete input/output examples are the most powerful context type for guiding LLM behavior. An `## Ejemplos` section with positive (✅) and negative (❌) pairs is added to the most critical commands.

**Rule:** `docs/rules/domain/example-patterns.md`
**Pilot commands:** `project-audit`, `sprint-plan`, `spec-generate`, `debt-track`, `risk-log`

---

## Improvement 2: /eval-output (LLM-as-a-Judge)

New command implementing G-Eval — output evaluation with quantitative scoring (1-10) against defined criteria. Includes Arena mode for A/B comparison of two outputs.

**Command:** `.claude/commands/eval-output.md`
**Criteria:** `docs/rules/domain/eval-criteria.md` (4 types: report, spec, code, plan)

---

## Improvement 3: Entity Memory

Extends the memory system with Entity Memory — structured memory that tracks specific entities (stakeholders, components, decisions) persistently across sessions.

**Command:** `.claude/commands/entity-recall.md`
**Script:** `scripts/memory-store.sh` (new `entity` subcommand)

---

## Improvement 4: Tool Discovery (Capability Groups)

Groups the 360+ commands into 15 semantic capability groups to reduce tool overload. Agents and the NL-resolver search within the relevant group first.

**Rule:** `docs/rules/domain/tool-discovery.md`
**Map:** `docs/capability-groups.md`

---

## Improvement 5: Prompt Structure Compliance

Aligns pm-workspace with the 10-layer optimal prompt structure, adding the missing layers: Reasoning Guidance (step-by-step thinking) and Output Templates (concrete output formatting).

**Rule:** `docs/rules/domain/prompt-structure.md`

---

## Tests

```bash
bash scripts/test-context-eng-improvements.sh
```

The test suite validates: file existence, frontmatter, required sections, line limits, entity memory functionality, cross-references between files, and documentation presence.

---

## Sources

- AI Engineering Guidebook (Pachaar & Chawla, 2025) — Context Engineering, AI Agents, MCP, LLM Evaluation
- Anthropic Skills repo (github.com/anthropics/skills) — official skill format
- Prompt structure image — 10-layer model for optimal prompts
