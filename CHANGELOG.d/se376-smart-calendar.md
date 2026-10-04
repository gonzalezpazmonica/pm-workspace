---
version_bump: patch
section: Fixed
---

### Fixed

- smart-calendar: el motor de criticidad ya no ejecuta comandos inyectados en el frontmatter, encuentra el item exacto (PBI-1 no es PBI-12) y en todos los proyectos, no marca como vencidos los deadlines entre comillas o invalidos, acepta decimales con coma (es_ES), acota impacto y dependencias a 1-5, excluye archive/ y items cerrados del dashboard y devuelve exit 2 en usos invalidos; tests/test-smart-calendar.bats certificado 84.

