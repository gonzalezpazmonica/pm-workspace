---
version_bump: minor
section: Added
---

### Added (SE-344 — Frónesis como Código, Batch 2 del plan unificado)

- `scripts/fronema.py` — CLI de fronemas: `register` (validación bloqueante:
  tensión/prototipo/deliberación/decisión/razón/límites/fuente/dominio L23,
  nivel solo N1/N2), `verify`, `overrule` (marca, no borra), `calibrate`
  (sugiere graduación ≥90% en ≥3 sesiones), `graduate` (→ regla, historial),
  `query` (gate de precedentes por tensión×dominio×madurez), `list`, `train`
  (loop de formación con Brier, determinista por sesión). Stdlib puro, sin red
  (CRIT-001).
- Cúpula **Fronesia** (N2) en SaviaVaults con 6 fronemas seed del historial
  propio (verified): permiso expreso/SE-343, PR #749, doc inversor v2, L1
  confianza, L13 metacognición, commit-guardian leak.
- Protocolo de destilación (CRIT-001): `docs/rules/domain/fronesis-destilacion.md`
  — el caso completo vive en la cúpula del proyecto (N4, jamás sale); a la
  cúpula de frónesis solo entra la versión destilada N2.
- `tests/test-fronema.bats` — 13 tests (AC-1..AC-10 + determinismo + calibrate).
- Spec SE-344 → **IMPLEMENTED**.
