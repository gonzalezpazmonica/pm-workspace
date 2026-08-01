---
version_bump: minor
section: Added
---

### Added

- SE-291 S1: Savia Labs — cupula de investigacion epistemica con preregistro obligatorio, 4 tipos de entidad (hypothesis/experiment/result/protocol), cuaderno append-only y L1 preregistrada
- SE-291 S3: Gestion de domos — CLI dome create/list/info/delete/set-default, DomeRegistry persistente (JSON), soporte multi-dome en MCP server
- SE-291 S6: Control de acceso — UserStore con tokens bcrypt, AccessController RBAC (reader/writer/admin) por dome, autenticacion via SAVIA_AUTH_TOKEN, comandos CLI user create/delete/list/token/grant/revoke/permissions
- SE-291 S7: Confidencialidad — N1-N4 gates en AccessController, N1 lectura publica, N3-N4 requieren roles elevados, comando CLI confidentiality set/get/audit
- SE-291 fix: opencode.json bootstrapping corregido (ficheros locales inexistentes eliminados, MCP codebase-memory desactivado, parametro schema eliminado del arranque vaults), servidor MCP arranca sin dome configurado

### Changed

- MCP Server v0.2.0 a v0.3.0 con multi-dome, auth, y vault_domes tool
- CLI ampliado con 3 nuevos grupos de comandos (user/dome/confidentiality)
