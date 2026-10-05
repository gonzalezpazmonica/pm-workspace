---
version_bump: patch
section: Fixed
---

### Fixed

- smart-calendar: el motor de criticidad ya no ejecuta comandos inyectados en el frontmatter, encuentra el item exacto (PBI-1 no es PBI-12) y en todos los proyectos, no marca como vencidos los deadlines entre comillas o invalidos, acepta decimales con coma (es_ES), acota impacto y dependencias a 1-5, excluye archive/ y items cerrados del dashboard y devuelve exit 2 en usos invalidos; muestra los deadlines invalidos (assess y ALERT del dashboard) y rechaza un CRITICALITY_TODAY invalido con exit 2.
- smart-calendar: la confianza con decay se calcula en decimas (90% = 4,5) en vez de truncarse a entero, como define spec-task-criticality.md; los scores suben hasta 0,075 y algunos items en la frontera pasan de P1 a P0.
