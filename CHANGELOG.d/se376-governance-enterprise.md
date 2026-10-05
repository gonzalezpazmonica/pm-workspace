---
version_bump: patch
section: Fixed
---

### Fixed

- governance-enterprise: el audit trail SE-006 vuelve a verificar cadenas legítimas (fallaba con 2+ entradas), detecta spec manipulado, desplazamiento de fronteras, claves duplicadas, bytes NUL, timestamps imposibles o que retroceden, entradas de otro tenant y última línea sin salto, valida tenant y campos, escribe bajo lock y admite verify --anchor/--tenant; compliance-check ya no da 100 a un workspace hueco: exige documentos con contenido y tema, model cards completas, postmortems, manifiestos JSON no vacíos y trails verificados, y valida tenant, anclas, flags sin valor y --output-file.

