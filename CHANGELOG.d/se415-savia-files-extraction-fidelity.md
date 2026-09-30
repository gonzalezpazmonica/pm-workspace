---
version_bump: patch
section: Fixed
---

### Fixed

- SE-415: Savia Files ya no da por comprendido un documento del que no extrae nada. Un PDF escaneado queda `ARCHIVE_ONLY` con `page-without-text`, y los JSON grandes declaran lo que omiten. Además, extrae las notas del presentador de PPTX, añade a cada celda XLSX el nombre de su columna y fila, lee CSV y TXT en Windows-1252 y procesa varios ficheros en un solo worker (6 PDF: 73,8 s → 37,1 s). La calidad de recuperación del corpus de evaluación no cambia.
