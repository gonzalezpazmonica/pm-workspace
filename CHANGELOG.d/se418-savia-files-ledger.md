---
version_bump: minor
section: Added
---

### Added

- SE-418: cada operación de Savia Files (guardar, borrar, reprocesar) queda registrada en un repo git privado de la cúpula, sin remoto y sin nombres ni texto, con un comprobante firmado (Ed25519). Reintentar con la misma `idempotencyKey` es seguro. Las operaciones cortadas por una caída o un fallo de git se completan o cancelan solas, y lo pendiente de extraer se extrae una vez. `files verify` comprueba ledger, documentos, originales y firmas. Sin dependencias nuevas (`node:sqlite`). Coste medido: unos 27 ms por operación; un lote de 300 ficheros hace un solo commit.
