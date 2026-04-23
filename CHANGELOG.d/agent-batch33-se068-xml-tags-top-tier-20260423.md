# Batch 33 — SE-068 XML tags in 5 top-tier opus-4-7 agents

**Date:** 2026-04-23
**Version:** 5.79.0 (batch combinado 31-35)

## Summary

Zero agents en Savia usaban XML tags. Opus 4.7 migration guide reporta hasta 30% quality improvement en multi-doc input con estructura XML + query-at-end. 5 top-tier agents migrados.

## Cambios

### A. XML tag block anadido
A cada uno de los 5 agents (architect, dev-orchestrator, court-orchestrator, truth-tribunal-orchestrator, code-reviewer), append de seccion `Structured Context (SE-068)` con los 4 tags requeridos:
- `<instructions>`: operational guidance
- `<context_usage>`: como consumir files/diffs/memoria
- `<constraints>`: permission_level, safety hooks, rules
- `<output_format>`: estructura esperada de output

### B. Canonical doc
`docs/rules/domain/agent-prompt-xml-structure.md` — canonical 6-tag set, orden, migration checklist, anti-patterns. Sirve de referencia para futuras migraciones (no retrofit masivo de 65 agents).

## Validacion

- `scripts/opus47-compliance-check.sh --xml-tags`: PASS
- 5/5 agents contienen 4/4 required tags
- Canonical doc presente en `docs/rules/domain/`
