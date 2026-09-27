---
bump: patch
section: Fixed
---

- Triage de suites (Fase A, grupo 2): el gate G14 de `pr-plan` nunca se ejecutaba (filtraba `.opencode/skills`, pero git informa `.claude/skills` por el symlink); el auditor de catálogo exige ahora `layer` (SE-356) y cuatro skills que nacieron sin él lo declaran. `turn-sdlc-audit.sh` emitía JSON inválido con matcher vacío. `cache-hygiene.sh --validate` leía MEMORY.md de un manifest fijo, aceptaba un manifest vacío y fallaba en checkouts limpios por un path local gitignored. SPEC-SE-036 pasa de `DRAFT` (no canónico) a `PROPOSED`. Tests alineados con los contratos vigentes (imports eager, `model_tier`, SE-371, workflow de changelog por PR, conteo de hooks declarado) y guías de inicio bajo el límite de 150 líneas.
