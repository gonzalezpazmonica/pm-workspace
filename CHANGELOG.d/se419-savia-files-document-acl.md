---
version_bump: minor
section: Added
---

### Added

- SE-419: permisos por documento en Savia Files. Cada fichero puede limitarse a unas personas concretas (`readers`/`writers`) dentro de su cúpula. Quien no tiene permiso no lo ve en la lista, en el texto, en la descarga ni en `vault_rag`, y el cambio vale al instante, sin reindexar. Lo cambia quien puede escribir el documento, con comprobante firmado. El nivel del documento se aplica también si la cúpula se reclasifica a la baja, y `vault_rag` deja de devolver los documentos borrados antes del siguiente sync. En un servidor local sin usuarios nada cambia. Coste medido: despreciable (`vault_rag` ~7 ms con 300 ficheros).
