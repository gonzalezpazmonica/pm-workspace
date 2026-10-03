---
version_bump: patch
section: Fixed
---

### Fixed

- setup-memory.sh (cadena de onboarding-dev vía /project-new): el nombre del proyecto se inserta literal (antes '&' y 'FECHA' corrompían la plantilla), se rechazan '/', '..' y nombres inválidos con exit 2 (antes path traversal fuera de ~/.savia/projects y MEMORY.md a medias), escritura atómica segura con ejecuciones simultáneas y error claro sin HOME; SKILL.md y comandos sin el /onboarding-ask inexistente

