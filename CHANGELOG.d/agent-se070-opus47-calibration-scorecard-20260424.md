# SE-070 Opus 4.7 calibration scorecard — IMPLEMENTED (Slice 1-3)

**Date:** 2026-04-24
**Version:** 5.98.0

## Summary

SE-070 Slices 1-3 implementados. Slice 4 (actual A/B evals) deferido per spec's own deferral criteria ("defer execution until batch budget allows").

Queue APPROVED: 5 → 4 (4 restantes todos GPU-blocked). **Ningún APPROVED ejecutable en dev sin GPU. Backlog activo cerrado.**

## Cambios

### A. Slice 1 — Scorecard script (NUEVO)

`scripts/opus47-calibration-scorecard.sh`:
- Escanea `.claude/agents/*.md`, identifica 37 sonnet-4-6 candidates
- Lookup de golden-set en `tests/golden/opus47-calibration/<agent-name>/`
- Emit YAML + MD outputs con recommend flag (eval si tiene golden, defer si no)
- Cost delta: +1025% per I/O unit (sonnet default → opus-4-7 xhigh con 2.5x thinking mult)
- CLI: `--help`, `--quiet`, `--json`, unknown flag exits 2

### B. Slice 2 — Golden-set template (NUEVO)

`tests/golden/opus47-calibration/`:
- README.md con structure + workflow + scoring rubric (5 dimensions × 0-10 = 50 max)
- TEMPLATE/prompt.txt: template de input prompt
- TEMPLATE/expected.md: acceptance criteria template
- TEMPLATE/score.yaml: dual-score structure (sonnet + opus) con cost/quality/ratio derivados

### C. Slice 3 — Playbook doctrine (NUEVO)

`docs/rules/domain/opus47-calibration-playbook.md`:
- 6-step workflow per agent: scorecard → bootstrap golden → A/B run → blind-eval → metrics → decision
- Decision matrix:
  - `quality_cost_ratio >= 2.0` → upgrade
  - `1.0 - 2.0` → keep sonnet
  - `< 1.0` → keep OR downgrade to haiku
  - `< 0 quality_delta` → underperforms, keep/downgrade
- Cost guidance: ~$0.72 per agent × 3 cases, $27 for full 37-agent suite, $30/quarter budget
- 5 anti-patterns documentados (no-blind, single-case, parallel-upgrade, skip-failure-mode, judge-bias)
- Rollback + re-eval cadence

### D. Slice 4 — DEFERRED

Per spec's explicit deferral criterion ("run only when batch budget allows"). Pre-identified candidates (business-analyst, drift-auditor, tech-writer), infrastructure ready. Execute in future sprint when API budget ~$2.20 + human eval time allows.

### E. Tests (NUEVO)

`tests/test-opus47-calibration-scorecard.bats`: **45 tests certified (score 98)**. Coverage:
- CLI (help/quiet/json/unknown arg)
- Execution (YAML + MD outputs, summary line)
- JSON mode (valid JSON, required keys, sonnet_count matches repo)
- Cost model constants (sonnet/opus/xhigh mult)
- Golden-set detection (has_golden function, GOLDEN_DIR path)
- Output content (Summary section, YAML fields)
- Slice 2 template files exist with required fields
- Slice 3 playbook exists with decision matrix, blind-eval anti-pattern, cost guidance
- Negative (empty agents, non-sonnet NOT in list)
- Edge (missing model frontmatter, empty golden dir, 65+ agents no timeout)
- Isolation (no agent frontmatter modification, exit codes {0,1,2}, output/ only)

### F. SE-070 status: APPROVED → IMPLEMENTED

Resolution section added. 4/5 AC cumplidos (AC-03 Slice 4 evals deferred).

## Validacion

- `bats tests/test-opus47-calibration-scorecard.bats`: 45/45 PASS
- `bash scripts/opus47-calibration-scorecard.sh --json`: emits valid JSON with 37 sonnet agents
- Manual smoke: YAML + MD outputs generated successfully
- `scripts/readiness-check.sh`: PASS

## Progreso backlog APPROVED

Post-merge de este PR:
- APPROVED: **5 → 4** (-1 SE-070 resolved)
- IMPLEMENTED: **59 → 60** (+1)

**Ningún APPROVED ejecutable sin GPU queda en queue.**

Queue APPROVED restante (4, TODOS GPU-blocked):
- SE-028 oumi — GPU required for training pipeline
- SE-042 Voice training pipeline — GPU required
- SPEC-023 Savia LLM Trainer — GPU required
- SPEC-080 Unsloth training — GPU required

## Próximos pasos autónomos

Con el queue APPROVED sin-GPU cerrado, las opciones son:
1. **Hook coverage ratchet** continuar hacia 85% (50/58) — batches 49-50 (+3 hooks each)
2. **PROPOSED priority alta** (8 specs): SE-034, SPEC-055, SPEC-078, SPEC-121, SPEC-122, SPEC-124, SE-030→baja, SE-040→baja (los 2 demoted hoy)
3. **Triage adicional**: review de PROPOSED media/baja buscando quick wins
4. **Research opportunities**: identificar nuevos specs emergentes

## Referencias

- SE-070: `docs/propuestas/SE-070-opus47-eval-scorecard.md`
- Scorecard: `scripts/opus47-calibration-scorecard.sh`
- Golden template: `tests/golden/opus47-calibration/`
- Playbook: `docs/rules/domain/opus47-calibration-playbook.md`
- Complementary: SE-066..SE-069 (Opus 4.7 immediate adaptations)
