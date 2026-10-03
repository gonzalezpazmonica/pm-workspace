---
version_bump: patch
section: Fixed
---

### Fixed

- prospectiva-basica: micmac calcula la clasificación indirecta de Godet con potencias exactas (el tope de saturación aplanaba a «enlace» 189 de 200 matrices aleatorias), exige diagonal nula y enteros, informa converged; mactor rechaza poder total 0 (antes ZeroDivisionError), duplicados, ejes vacíos y umbral fuera de 0..1, y no declara alianza a pares sin stake común. Test certificado 98.

