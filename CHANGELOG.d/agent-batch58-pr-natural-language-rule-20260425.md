## [6.9.0] — 2026-04-25

Batch 58 — Nueva regla: cada PR requiere párrafo en lenguaje no técnico.

### Added
- `docs/rules/domain/pr-natural-language-summary.md` — regla canónica con 4 puntos obligatorios (qué cambia, por qué importa, riesgos, activación), lenguaje prohibido (spec IDs, jergas, métricas), excepciones explícitas (commits sign, reverts puros, hotfixes documentados).
- `scripts/pr-plan-gates.sh:g_summary` — gate G11 valida `.pr-summary.md` existe, ≥300 chars, contiene título canónico `## Qué hace este PR (en lenguaje no técnico)`.

### Changed
- `scripts/pr-plan.sh` — invoca G11 tras G10.
- `scripts/push-pr.sh` — lee `.pr-summary.md` y lo prepend al PR body antes de la sección Summary auto-generada.
- `.gitignore` — excluye `.pr-summary.md` (vive solo local).
- `CLAUDE.md` — referencia lazy a la nueva regla en la tabla.

### Context
Solicitud explícita de la usuaria: PRs autónomos crecen rápido, sin párrafo plano dejan de ser auditables. Hard gate en pr-plan + auto-inject del fichero al body. Slice 1 — sin LLM, solo longitud + título. Excepciones documentadas.

PR #701 (batch 57) editado retroactivamente para añadir el párrafo. A partir de #702 (este) la regla aplica vía gate.

Version bump 6.8.0 → 6.9.0.
