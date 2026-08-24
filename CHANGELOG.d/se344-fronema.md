---
version_bump: minor
section: Added
---

### Added

- **SE-344 Frónesis como Código (FxC)** — `scripts/fronema.py`:
  - Sistema de **fronemas**: casos de juicio con consecuencia verificada
    (tensión entre principios · señales RPD · deliberación · decisión/razón ·
    consecuencia en T+30/90/180 · límites). Schema entity `phronesis-case`.
  - CLI determinista: `register` (draft o seed `verified`), `verify`
    (promueve draft→verified con consecuencia real), `overrule` (la revocación
    es historial, nunca se borra), `calibrate` (uso en formación;
    sugerencia de graduación si rate≥90%), `graduate` (lo obvio migra a
    regla), `query` (gate de precedentes por tensión×dominio×madurez, exit
    1 sin resultados), `list`, `train` (loop de formación: caso enmascarado →
    predicción con confianza → revelación; determinista por sesión; registro
    local JSONL).
  - Validación estricta: campos obligatorios, nivel SOLO N1/N2 (los casos
    N3+/N4 jamás entran en la cúpula de frónesis — CRIT-001), madurez
    escalonada por consecuencia verificada.
  - Persistencia: notas markdown con frontmatter en la cúpula de frónesis
    (`~/.savia-vaults/fronesis` por defecto); cero egress, stdlib Python.
  - Seed: 6 fronemas reales del historial propio registrados como verified
    (gate nocturno/SE-343, PR #749, auditoría doc inversor, L1, L13,
    commit-guardian).
  - 17 tests BATS (AC-1..AC-11).