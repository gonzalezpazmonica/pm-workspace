# RBAC Management -- Dominio

## Por que existe esta skill

Sin control de acceso, cualquier usuario puede ejecutar cualquier comando, incluyendo operaciones destructivas o de infraestructura. Esta skill implementa RBAC basado en ficheros con 4 roles jerarquicos, auditoria de cada accion y verificacion de permisos pre-comando.

## Conceptos de dominio

- **4 roles**: Admin (todo), PM (sprint/backlog/reports), Contributor (code/specs/tests), Viewer (solo lectura). Herencia estricta.
- **Scope**: global (todos los proyectos) o project-specific (lista de proyectos autorizados).
- **Audit trail JSONL**: registro append-only de cada accion ejecutada con timestamp, usuario, comando, resultado y motivo.
- **Grant/Revoke**: asignacion y revocacion de roles; solo Admin puede asignar; revocacion degrada a Viewer.
- **Pre-command check**: hook que verifica rol + scope antes de ejecutar cualquier comando.

## Reglas de negocio que implementa

- rbac-model.md: matriz de permisos por rol y categoria de comando.
- Solo Admin puede modificar roles; no se puede revocar a Admin sin eliminacion manual.
- Audit trail es append-only: nunca se modifica ni se borra (rotacion a historico a 10MB).
- Deteccion de modificacion manual de role.md genera alerta al humano.

## Relacion con otras skills

- **Upstream**: profile-setup (creacion de perfiles donde se asigna rol).
- **Downstream**: governance-enterprise (audit trail alimenta controles ISO/GDPR), team-coordination (roles mapeados a estructura de equipos).
- **Paralelo**: audit-export (exportar audit trail para auditores externos).

## Decisiones clave

- Ficheros .md sobre base de datos: coherente con .md-is-truth; auditable con git.
- 4 roles sobre permisos granulares: simplicidad operativa; proyectos pueden override con rbac-overrides.md.
- Pre-command hook sobre validacion inline: garantiza enforcement determinista sin depender del LLM.
