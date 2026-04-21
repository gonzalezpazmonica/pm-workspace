# Batch 17 — SE-061 Slice 4 MCP opt-in template

**Date:** 2026-04-21
**Branch:** `agent/batch17-scrapling-slice4-20260421`
**Version bump:** 5.65.0

## Summary

Cuarto y último slice SE-061. MCP server opt-in para Scrapling — template documentado con activation steps, sin activación automática.

## Added

- `.claude/mcp-templates/scrapling.json`:
  - Template entry con `command: python3 -m scrapling.ai.mcp`, `env: {}`
  - `activation_steps[]`: 6 pasos explícitos (probe → install → audit → copy → no autoApprove → restart)
  - `compliance` block: `autoApprove: false`, licencia BSD-3 documentada, legal note
  - Metadata references: spec SE-061, research-stack.md, mcp-security-audit.sh

- `tests/test-scrapling-mcp-template.bats` (25 tests certified):
  - Existence + valid JSON + size constraints
  - Structure (template.scrapling, activation_steps, compliance)
  - Compliance rules (autoApprove false, BSD-3, legal, audit reference)
  - Integration (scrapling NOT in active mcp.json)
  - Docs integration (research-stack + security-scanners references)
  - Negative (autoApprove wildcard detectable, bad JSON caught)
  - Edge (no credentials, no HOME paths, env explicit)
  - Isolation

## Changed

- `docs/rules/domain/research-stack.md`: nueva sección "MCP opt-in (SE-061 Slice 4)" con 6 pasos de activación
- `docs/rules/domain/security-scanners.md`: fila "MCP templates (SE-061)" en el catálogo

## Compliance

- Rule #8: Slice 4 sobre spec PROPOSED. Template NO activa el MCP — solo documenta
- MCP-02 (no wildcard autoApprove) enforzada por test de compliance
- `scripts/mcp-security-audit.sh` pasa (0 findings, 2 configs audited: mcp.json + template)

## SE-061 status

Los 4 slices ejecutados (21h planificadas):
- ✅ Slice 1: `scripts/scrapling-probe.sh` + 23 tests (batch 14, PR #655)
- ✅ Slice 2: `scripts/scrapling-fetch.sh` + 29 tests (batch 15, PR #656)
- ✅ Slice 3: skill integration + `research-stack.md` + 26 tests (batch 16, PR #657)
- ✅ Slice 4: MCP template + compliance + 25 tests (batch 17)

Total: 103 tests certified · 4 scripts · 1 template · 2 skills actualizados · 1 rule nueva · 1 rule ampliada.

## Referencias

- Spec: `docs/propuestas/SE-061-scrapling-research-backend.md`
- Research: `output/research/scrapling-20260421.md` (local)
- Roadmap: `docs/ROADMAP.md` §Era 183 Tier 3 Champions
