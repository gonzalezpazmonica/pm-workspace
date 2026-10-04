### Fixed
- merge-sprint: si main avanza mientras el sprint espera la CI de un PR, el merge ya no se aparca. Se re-sincroniza y se reintenta, hasta 3 veces.
- merge-sprint: `docs/rules/INDEX.md` y `rule-manifest.json` cuentan como derivados. Sus conflictos se regeneran y ya no aparcan el PR como conflicto real.
- merge-sprint `plan`: si el head actual no tiene revisión propia, acepta la revisión más reciente cuyo sha sea equivalente (§2.6). El workflow remoto integra main en todas las ramas tras cada merge, y sin esto el plan salía vacío.
