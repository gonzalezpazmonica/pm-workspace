# Tier 1 batch — SE-151/152/073 + SPEC-181/159/160

**Date:** 2026-06-06
**PR:** #825

## SE-151 — KG project_id index

scripts/knowledge-graph.py: --project flag on all subcommands; project_id column in entities table

## SE-152 — Skill routing semantic index

scripts/skill-routing-index.sh: generates output/skill-routing-index.json; --check mode
skills/_template/SKILL.md: optional consumes/produces fields
5 representative skills annotated

## SE-073 — Memory index 2-tier cap

scripts/memory-tier-rotate.sh: rotates entries to MEMORY-ARCHIVE.md; Tier A/B; cap 30 entries

## SPEC-181 — L0-L3 context budgets

docs/rules/domain/context-tier-budgets.md: L0/L1/L2/L3 enum
221 docs/rules/domain files: context_tier + token_budget frontmatter (L0+L1 = 2940 of 3000)
scripts/audit-context-budget.sh: validates invariant

## SPEC-159 — Async tribunal fan-out

scripts/tribunal-async-runner.sh: parallel judges, BLOCK propagation, per-judge timeout
docs/rules/domain/tribunal-async-protocol.md: protocol for orchestrators

## SPEC-160 — Tool ergonomics audit

scripts/tool-ergonomics-audit.sh: scans agent-runs jsonl, error_rate detection, dry-run/json flags

## Tests: 105 new across 6 BATS suites

SCM: 556 commands, 102 skills, 70 agents, 490 scripts
