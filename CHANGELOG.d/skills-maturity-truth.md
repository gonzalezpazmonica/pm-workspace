---
bump: patch
section: Fixed
---

- Madurez de skills alineada con la evidencia: `stable` solo en las 9 skills con test certificado; 123 pasan a `beta` (incluidas las plantillas, que hacían nacer `stable` a toda skill nueva). Se elimina la clave `savia.maturity` duplicada en 107 frontmatters y se retiran el último test de presencia y `add-maturity-levels.sh`.
- Los informes de madurez (executive-audit, generate-index, workspace-health) vuelven a contar el campo anidado.
- `skill-creator.sh` admite `SAVIA_SKILL_TESTS_DIR`; su suite ya no deja tests generados en `tests/`.
