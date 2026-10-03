---
version_bump: patch
section: Fixed
---

### Fixed

- devops-validation: validate-devops.sh deja de dar PASS/WARN sin red o con PAT rechazado (fail-closed), sale con 1 si hay FAIL y 2 en error de uso, ya no pasa el PAT en los argumentos de curl, codifica proyecto y equipo con espacios en la URL (el equipo por defecto rompía backlog e iteraciones) y admite PATs de 84 caracteres; test certificado (25 casos, 85).

