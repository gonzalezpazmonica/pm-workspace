---
version_bump: minor
section: Added
---

### Added

- SE-413: Savia Files (MVP) en SaviaVaults. Guarda ficheros originales (PDF, DOCX, PPTX, XLSX, TXT, MD, CSV, JSON) por cúpula fuera de git, inmutables y verificados por SHA-256, con revisiones y borrado real. Extrae su texto citando página, diapositiva, elemento o celda (Docling sin OCR y openpyxl en un worker Python aislado) y lo publica en `vault_rag` con procedencia. El escaneo ClamAV es opcional. Se usa con la tool MCP `vault_files` y la CLI `savia-vaults files`; está desactivado por defecto (`files.enabled`).
