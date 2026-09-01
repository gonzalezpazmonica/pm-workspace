---
version_bump: patch
section: Added
---

### Added

- SE-365 Company as Code: estándar de entidades organizacionales como código (renumerado de SE-265). `org-registrar.py` valida entidades (frontmatter común, vocabulario de relaciones cerrado, consistencia referencial, origin/source SE-352), indexa el grafo (company/projects/resources) y prepara propuestas de escritura mediada. Skill `org-registrar` + grafo piloto (5 entidades). 6 pytest + 5 bats tests.
