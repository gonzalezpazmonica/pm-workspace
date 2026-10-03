---
version_bump: patch
section: Fixed
---

### Fixed

- dependency-scan: el fallback Docker funcionaba mal (pasaba la primera bandera como ruta), --security-checks pasa a --scanners, un fallo de Trivy ya no se informa como «vulnerabilidades» (exit 2), una sola pasada de Trivy con los hallazgos listados, y un SBOM fallido ya no se sustituye por uno vacío fabricado.

