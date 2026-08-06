---
version_bump: patch
section: Fixed
---

### Fixed

- SE-305: corregidos nombres de tests se253 en el selector dinámico de BATS. Las reglas y core_tests referenciaban `test-se-253-*` (con guion) pero los archivos reales son `test-se253-*`. El selector generaba tests inexistentes → CI fallaba con "Test file does not exist" en PRs que tocan agentes/skills.
