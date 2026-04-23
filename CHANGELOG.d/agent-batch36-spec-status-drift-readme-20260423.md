# Batch 36 — Spec status drift sweep + README refresh + drift auditor

**Date:** 2026-04-23
**Version:** 5.80.0

## Summary

Post-merge batches 31-35 (Opus 4.7 calibration), analisis revelo 20 specs con `status: PROPOSED` en `docs/propuestas/` que en realidad estaban IMPLEMENTED en batches anteriores. Evidencia: cada uno tenia scripts/skills/artifacts on disk y >=3 referencias en `CHANGELOG.d/`. Batch 36 sweep + nuevo auditor para prevenir recurrencia.

## Cambios

### A. 20 frontmatters actualizados PROPOSED a IMPLEMENTED

| Spec | Batch cierre | Artifacts |
|---|---|---|
| SE-029 | slices 2-4 | context-task-classifier + frozen hook + operational point |
| SE-032 | 19 | scripts/rerank.py + skill |
| SE-033 | 20 | scripts/topic-cluster.py + skill |
| SE-035 | 18 | mutation testing skill + wrapper |
| SE-036 | 8 | 125 specs frontmatter normalizados |
| SE-041 | 21 | scripts/memvid-backup.py + skill |
| SE-043 | 6 | scripts/claude-md-drift-check.sh |
| SE-044 | 7 | adr-001 + SPEC-110 collision fix |
| SE-047 | 6, 7 | scripts/agents-catalog-sync.sh |
| SE-048 | 6, 7 | scripts/rule-orphan-detector.sh |
| SE-050 | 9 | emergency-mode skill |
| SE-051 | 6 | scripts/spec-approval-gate.sh |
| SE-052 | 8 | scripts/agent-size-remediation-plan.sh |
| SE-053 | 7 | scripts/changelog-consolidate.sh |
| SE-054 | 8 | frontmatter migration 4/4 |
| SE-056 | 23 | python SBOM virtualenv setup |
| SE-058 | 12 | scripts/mcp-security-audit.sh |
| SE-059 | 10 | scripts/permissions-wildcard-audit.sh |
| SE-061 | 14-17, 22 | Scrapling 4 slices complete |
| SE-062 | 24-27 | Era 184 consolidation 5/5 slices |

Cada frontmatter anade `applied_at: YYYY-MM-DD` + `batches: [N, M]`.

### B. Nuevo drift auditor

`scripts/spec-status-drift-audit.sh`:
- Flags: `--min-refs N` (default 2), `--json`
- Lee `docs/propuestas/SE-*.md` con `status: PROPOSED`
- Cuenta referencias en `CHANGELOG.d/*.md`
- Si refs >= cutoff, flag drift
- Exit 0 clean, 1 drift, 2 usage error

Tests BATS 26 casos (positive, negative, edge, coverage, isolation). Valida:
- Synthetic fixtures con drift detectado
- IMPLEMENTED specs no flagged aunque tengan refs
- Missing directories error gracefully
- High cutoff filtra
- Edge cases (empty dir, missing id, invalid --min-refs)

### C. README refresh

Counts actualizados: 64 a 65 agents, 76 a 86 skills, 55 a 58 hooks, 160 a 283+ test suites. Cierra G8 WARN del PR batches 31-35.

## Validacion

- `bash scripts/spec-status-drift-audit.sh`: VERDICT PASS (0 drift post-sweep)
- `bats tests/test-spec-status-drift-audit.bats`: 26/26 PASS
- `scripts/readiness-check.sh`: PASS

## Compliance

- Memory `feedback_no_overrides_no_bypasses`: el auditor NO modifica frontmatters automaticamente. Solo detecta y reporta. Remediation es manual / batch-approved.
- Rule #8 autonomous safety: sweep ejecutado tras merge + aprobacion "continuamos desarrollando".
- Zero project leakage: metricas internas abstraidas como "cutoff configurable" sin numeros especificos en public-facing sections.

## Pendiente

- Futuros specs que acumulen refs pero queden en PROPOSED: el auditor los detecta proactivamente. Integracion en `readiness-check.sh` o `pr-plan.sh` opcional si Monica lo pide.
