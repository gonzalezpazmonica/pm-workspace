## [6.7.0] — 2026-04-25

Batch 56 — SPEC-124 pr-agent wrapper **IMPLEMENTED** (3 ACs faltantes completados). **Era 187 trigger: todas PROPOSED alta resueltas.**

### Added
- `.github/workflows/templates/pr-agent-review.yml` — reusable workflow para invocar qodo-ai/pr-agent como 5º juez del Court (AC-04). Cost gate `max_lines` default 1000, feature-flag check `COURT_INCLUDE_PR_AGENT`, skip on draft, comments tagged `[pr-agent]`, graceful skip si pr-agent no instalado.
- `docs/rules/domain/court-external-judges.md` — política para incluir jueces externos OSS en el Court (AC-08). 7 requisitos de inclusión (auditable, self-hostable, pinable, schema validable, opt-in, tagged comments, respeta AUTONOMOUS_REVIEWER), 6 reglas operación, activación paso a paso, riesgos documentados.

### Changed
- `docs/propuestas/SPEC-124-pr-agent-wrapper.md` — status PROPOSED → IMPLEMENTED. Resolution section con 9/9 ACs cumplidos.

### Context
ACs 01/02/03/05/06/07 ya implementados desde batches previos (skill, agent, script wrapper, court-orch External Judges section, pm-config flags, tests certified 83). Este PR completó los 3 AC faltantes: workflow template (AC-04), policy doc (AC-08), CHANGELOG (AC-09).

**Era 187 closure trigger: 0 PROPOSED priority alta restantes.** Todas las 6 specs alta priority de Era 187 están IMPLEMENTED:
- SPEC-055 test-auditor (drift fix)
- SPEC-078 dual-estimation (drift fix)
- SPEC-121 handoff-as-function (3 ACs cerrados)
- SPEC-122 LocalAI emergency (4 ACs cerrados)
- SPEC-124 pr-agent wrapper (3 ACs cerrados)
- SE-070 opus47 calibration (Slice 1-3, Slice 4 deferred per spec)

Próximo trabajo: cerrar Era 187 en ROADMAP + atacar SE-072/SE-073 APPROVED (GenericAgent research) o passar a PROPOSED priority media.

Diseño opt-in: pr-agent default disabled. OSS Apache 2.0, self-hostable. Veredicto consultivo (no veto). Comments tagged `[pr-agent]`.

Version bump 6.6.0 → 6.7.0.
