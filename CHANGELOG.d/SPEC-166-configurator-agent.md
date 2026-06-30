# SPEC-166 — Explicit Configurator Agent

**Date:** 2026-06-24

## Implementado

- `.opencode/agents/configurator.md`: fast-tier dispatch agent
  - Centralizes dispatch decisions: agents, skills, rules, memory queries per turn
  - Input: prompt, command, profile_slug, recent_memory
  - Output: JSON `{agents_to_invoke, skills_to_load, rules_to_attach, memory_queries, rationale}`
  - Dispatch heuristics table covering 10+ intent patterns
  - Fallback: if uncertain → `smart-routing` skill; if agent fails → full context load
  - Shadow mode documented (14 days observe-only before applying)
  - Telemetry: `output/configurator-decisions.jsonl`
  - < 100 lines per spec constraint
- `tests/bats/test-spec-166-configurator.bats`: 5 BATS tests

## Tests: 5 passed (BATS)
