---
version_bump: minor
section: Added
---

### Added

- SE-417: las cúpulas N3/N4 de Savia Files se cifran en reposo (originales, texto extraído, metadatos e índice RAG) con libsodium. Las N1/N2 pueden activarlo con `files.encryption`. Borrar un fichero destruye su clave (borrado criptográfico). Las claves se pueden rotar sin volver a embeber y las cúpulas existentes se migran solas. El backup nocturno incluye los ficheros y guarda las claves por otro canal, selladas para una clave de recuperación (10 palabras + 4 dígitos). Las claves no se suben a la nube salvo que la configuración local lo pida (`SAVIA_BACKUP_UPLOAD_KEYS`). Medido: guardar 10 MB pasa de 54 a 177 ms y las búsquedas no cambian (6 ms).
