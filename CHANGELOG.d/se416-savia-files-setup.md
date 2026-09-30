---
version_bump: minor
section: Added
---

### Added

- SE-416: Savia instala por sí misma, sin consola ni permisos de administrador, las dos dependencias de Savia Files: el lector de documentos y el antivirus ClamAV oficial, con versiones y huellas fijadas. Lo hace con `savia-vaults files setup` o desde el chat (`vault_files setup`, en segundo plano). Mantiene las firmas del antivirus al día sola y explica en lenguaje llano qué falta y qué supone. Por ahora solo Linux x86_64 (probado: instalación en 31 s; un PDF queda leído y el fichero de prueba EICAR, en cuarentena).
