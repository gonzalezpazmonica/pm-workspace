---
version_bump: patch
section: Fixed
---

### Fixed

- setup-memory.sh (cadena de onboarding-dev vía /project-new): el nombre del proyecto se inserta literal (antes '&' y 'FECHA' corrompían la plantilla), se rechazan '/', '..' y nombres inválidos con exit 2 (antes path traversal fuera de ~/.savia/projects y MEMORY.md a medias), sin sed -i (causa de la corrupción medida con ejecuciones simultáneas), publicación atómica temporal + ln (fallback mv -n sin hard links) con permisos según la umask y limpieza del temporal ante SIGINT/SIGTERM, rechazo de symlinks en el proyecto o memory/ y de controles bidi Unicode, y error claro sin HOME; SKILL.md y comandos sin el /onboarding-ask inexistente

