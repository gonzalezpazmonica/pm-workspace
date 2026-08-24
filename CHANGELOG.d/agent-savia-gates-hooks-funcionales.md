---
version_bump: patch
section: Fixed
---
- **`.opencode/hooks` / `savia-gates`**: los hooks bash de seguridad vuelven a ejecutarse en OpenCode. El puente `savia-gates` ahora bloquea de verdad los commits en `main` (contrato `{decision:block}` de SE-337), resuelve matchers por comando (`Bash(git commit*)`), ejecuta hooks con `cwd(projectRoot)` y cierra el gap de eventos sin binding (quedan 0 de 113 injustificados).