---
version_bump: minor
section: Added
---

### Added (Plan unificado + Batch 1 L14)

**Plan unificado Labs × General**
- `docs/propuestas/ROADMAP-UNIFIED-20260827.md` — cruz de prioridades entre
  `labs/ROADMAP.md` y `docs/ROADMAP.md`; un solo orden de ejecución
  (L14 → SE-344 → L23 → backlog general → L26/L27). Cross-reference añadida a
  `docs/ROADMAP.md` (el roadmap de Labs vive en el repo vault separado).

**Batch 1 — L14 deuda estructural**
- `scripts/rule-manifest-generate.sh` (SE-338) — generador determinista de
  `rule-manifest.json` (schema `{tier: tier1|tier2|dormant, consumers}`),
  `--check` integrado en `readiness-check.sh`. Integrity: 0 missing, 0 phantom
  (302 reglas).
- `scripts/test-coverage-ratchet.sh` (SE-339) — ratchet no-decreciente de
  cobertura sobre hooks críticos (`tests/hooks/critical-hooks.txt`, 11 hooks,
  100% cubiertos); umbral persistente en `config/test-coverage.conf`; doc de
  ejecución de tests TS (`bun test`) en `.opencode/plugins/README.md`.
- SE-264 (memory consolidation): **verificado ya implementado en #905** — no se
  añade código duplicado. La consolidación del store JSONL
  (`output/.memory-store.jsonl`) queda como propuesta futura.

Specs SE-338/339 → **IMPLEMENTED**.
