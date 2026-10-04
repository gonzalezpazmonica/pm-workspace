---
version_bump: patch
section: Fixed
---

### Fixed

- code-improvement-loop: coherence-court.sh valida enteros con cota de longitud y rango antes de evaluar (cerraba ejecución de órdenes vía subíndice aritmético en score/gate/umbrales y el fail-open por desbordamiento de 64 bits: score 2^64-4 daba score=200 pass y threshold 2^64 daba PASS; umbrales y score de gate 0-100, conteos 0-999999, sin ceros a la izquierda), rechaza flujos con '/' (escritura fuera del directorio de premisas) y escapa el YAML del skeleton; savia-double-optin-check.sh resuelve operator-grant.sh y el audit log desde la raíz del repo (un script plantado en el cwd concedía el factor de intención). 33 tests nuevos (incluidos bordes 2^63-1, 2^63, 2^64, 20+ dígitos y ceros a la izquierda); cada guarda de entrada (ocho sumideros aritméticos y la validación del flujo en check y skeleton) tiene un mutante que la suite mata (10/10).

