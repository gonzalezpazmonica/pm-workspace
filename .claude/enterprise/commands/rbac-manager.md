---
name: rbac-manager
description: Role-based access control for Savia Enterprise tenants — grant, revoke, list and check effective permissions against tenants/{slug}/rbac.yaml
developer_type: all
agent: task
context_cost: low
---

# /rbac-manager — Gestión RBAC por tenant

Administra roles y asignaciones de usuario para un tenant Enterprise.
Edita `tenants/{slug}/rbac.yaml` de forma atómica.

Este comando es parte del módulo `multi-tenant` de Savia Enterprise
(SPEC-SE-002). Requiere que el módulo esté habilitado en
`.claude/enterprise/manifest.json` y un tenant activo.

## Sintaxis

```
/rbac-manager grant  <role> <user> [--tenant <slug>]
/rbac-manager revoke <role> <user> [--tenant <slug>]
/rbac-manager list   [--tenant <slug>]
/rbac-manager check  <user> <command> [--tenant <slug>]
```

Si `--tenant` no se pasa, se usa el tenant activo (resuelto por
`tenant-resolver.sh`: `$SAVIA_TENANT` → cwd → perfil).

## Subcomandos

- **grant**: añade `<user>` a la lista de miembros del rol. Idempotente.
- **revoke**: elimina `<user>` del rol. No-op si no existía (exit 0).
- **list**: imprime roles, comandos y miembros del tenant activo.
- **check**: devuelve exit 0 si el usuario tiene permiso para ejecutar
  `<command>`, exit 1 si está denegado. Considera herencia de roles.

## Schema de rbac.yaml

```yaml
roles:
  reader:
    commands: [sprint-status, help, memory-recall]
    members: [alice]
  developer:
    inherits: reader
    commands: [spec-*, pbi-*, dev-session-*]
    members: [bob]
  admin:
    inherits: developer
    commands: [tenant-*, rbac-*, backup-*]
    members: []
    gates: [confirm_destructive]
```

### Herencia

`inherits` compone comandos recursivamente: `developer` obtiene todos
los comandos de `reader` más los suyos propios. La herencia solo afecta
a los comandos, no a los miembros ni a los gates.

### Globs en commands

Se soportan wildcards tipo shell:
- `spec-*` concede `spec-generate`, `spec-review`, `spec-verify`, ...
- `*` concede cualquier comando (usar con precaución).

## Ejemplos

```
/rbac-manager grant developer alice
/rbac-manager list
/rbac-manager check alice spec-generate       # exit 0 (allowed)
/rbac-manager check alice tenant-create       # exit 1 (denied)
/rbac-manager revoke developer alice
```

## Implementación

Backend: `scripts/rbac-manager.sh`. Escribe `tenants/{slug}/rbac.yaml`
con patrón temp + `mv` (atómico). Usa `yq` si está disponible y hace
fallback a un parser bash mínimo para claves planas y listas.

## Seguridad

- El comando NUNCA toca ficheros fuera de `tenants/<slug>/rbac.yaml`.
- El hook `tenant-isolation-gate.sh` impide escrituras cross-tenant.
- Cada operación queda en `output/tenant-audit.jsonl` vía el gate.
- Rule #25 aplica: cambios irreversibles en producción se promueven
  solo con aprobación humana explícita.

## Out of scope

- Políticas a nivel de fichero dentro del tenant (SE-004).
- Integración SSO/SAML (SE-007).
- RBAC cross-tenant o federación (SE-008).
