---
version_bump: patch
section: Fixed
---

### Fixed

- SE-362: risk-tier.py clasificaba por el último fichero del diff (un script seguido de un .md salía tier 1); ahora evalúa cada fichero y un diff vacío es tier 3 (fail-closed).

