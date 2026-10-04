### Fixed
- merge-sprint: si main avanza mientras el sprint espera la CI de un PR, el merge ya no se aparca. Se re-sincroniza y se reintenta, hasta 3 veces.
- merge-sprint: `docs/rules/INDEX.md` y `rule-manifest.json` cuentan como derivados. Sus conflictos se regeneran y ya no aparcan el PR como conflicto real.
