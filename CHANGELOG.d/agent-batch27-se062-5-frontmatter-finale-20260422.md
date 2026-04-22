# Batch 27 — SE-062.5 Era 184 finale: frontmatter migration cierre

**Date:** 2026-04-22
**Branch:** `agent/batch27-se062-5-frontmatter-finale-20260422`
**Version bump:** 5.75.0

## Summary

Último slice de Era 184. Los 4 specs legacy con `**Status**:` inline documentados como excepción en batch 8 (SE-054) ahora tienen YAML frontmatter canónico. Era 184 CERRADA.

## Hallazgo

Batch 8 (SE-054 SE-036 slices 2-3) normalizó 125 specs pero dejó 4 en excepción documentada:

- `SPEC-066-enhanced-local-llm.md` — "Proposed | Date 2026-03-31"
- `SPEC-067-claudemd-diet.md` — "Approved | Era 165"
- `SPEC-068-hook-enhancement.md` — "Approved | Era 165"
- `SPEC-069-coordinator-mode.md` — "Research | Era 168"

Todos son research specs históricos. Sus findings ya están aplicados en el workspace (Eras 165-174).

## Solución

Frontmatter YAML añadido a cada uno con status inferido del estado real:

| Spec | status | Justificación |
|---|---|---|
| SPEC-066 | `IMPLEMENTED` era 174 | Emergency Watchdog + Gemma 4 instalados (Era 174) |
| SPEC-067 | `IMPLEMENTED` era 165 | CLAUDE.md 121→48 líneas (ROADMAP Era 165) |
| SPEC-068 | `SUPERSEDED` by SPEC-071 era 165 | Reemplazado por Hook Overhaul Era 171 |
| SPEC-069 | `IMPLEMENTED` era 168 | Research cerrado en batch Eras 167-170 (28 tests) |

Inline `**Status**:` eliminado en los 4 ficheros. Cuerpo preservado (1 línea blockquote resume el estado).

## Validación

- `specs-frontmatter-normalize.sh --scan` → PASS (0 drift en 198 specs)
- `claude-md-drift-check.sh` → PASS
- `readiness-check.sh` → PASS

## Era 184 CLOSED

5/5 slices SE-062 completados:

- **SE-062.1** Counter sync (batch 24)
- **SE-062.2** Duplicate SE-056 resolution (batch 24)
- **SE-062.3** Skills aggregator (batch 25)
- **SE-062.4** Changelog workflow activation (batch 26)
- **SE-062.5** Frontmatter finale (batch 27, este)

**Next**: Era 185 (SE-063 ACM enforcement hook) queda listo para arrancar.

## Compliance

- Rule #24 Radical Honesty: statuses inferidos con evidencia ROADMAP (no invento)
- SE-044 spec-id guard: IDs mantenidos inalterados
- SE-054 canonical statuses: todos los valores dentro de `CANONICAL_STATUSES` (IMPLEMENTED, SUPERSEDED)

## Referencias

- SE-062 Era 184: `docs/propuestas/SE-062-era184-consolidation-hygiene.md`
- SE-054 SE-036 batch 8: excepción original documentada
- SPEC-071 Hook Overhaul (supersedes SPEC-068): Era 171
