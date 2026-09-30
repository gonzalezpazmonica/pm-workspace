---
version_bump: minor
section: Added
---

### Added

- SE-421: Savia Files guarda y descarga ficheros de hasta 10 GiB (1 GiB por defecto, configurable por cúpula) sin cargarlos en memoria. Medido con 2 GiB: unos 160 MiB de memoria, también cifrando. `files get` admite `--range`. El antivirus analiza hasta 4.000 MB y lee los ficheros cifrados grandes por su entrada estándar, sin copia en claro. Los ficheros por encima del tope de extracción (256 MiB) se guardan y se descargan, pero sin texto. Es la base de la API HTTP con subida reanudable (SE-422).
