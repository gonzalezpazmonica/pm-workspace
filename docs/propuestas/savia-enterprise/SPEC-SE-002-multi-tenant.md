# SPEC-SE-002 — Multi-Tenant & RBAC

> **Prioridad:** P0 · **Estima:** 5 días · **Tipo:** aislamiento + permisos

## Objetivo

Permitir que una instalación de Savia Enterprise sirva a múltiples departamentos
u organizaciones internas con **aislamiento estricto de datos, contexto y
agentes**, sin que Core necesite saber que el multi-tenancy existe. RBAC
granular por rol y por tenant.

## Principios afectados

- #4 Privacidad absoluta (aislamiento N4 por tenant)
- #5 El humano decide (gates humanos por rol)
- #6 Igualdad (Equality Shield aplicado cross-tenant)

## Diseño

### Modelo de tenants

Reutilizar el comando `/tenant-create` existente. Un tenant es un subdirectorio
aislado bajo `tenants/{tenant-slug}/`:

```
tenants/
├── juridico/
│   ├── projects/           ← N4 aislado
│   ├── agent-memory/       ← memoria aislada
│   ├── secrets/            ← credenciales del tenant (gitignored)
│   └── rbac.yaml           ← roles y permisos
├── salud/
└── banca/
```

### RBAC declarativo

`rbac.yaml` por tenant define roles y permisos:

```yaml
roles:
  reader:
    commands: [sprint-status, help, memory-recall]
  developer:
    inherits: reader
    commands: [spec-*, pbi-*, dev-session-*]
  admin:
    inherits: developer
    commands: [tenant-*, rbac-*, backup-*]
    gates: [confirm_destructive]
```

### Tenant resolver (extension point #5 de SE-001)

Hook `tenant-resolver.sh` determina el tenant activo desde:
1. Variable `$SAVIA_TENANT`
2. Working directory (si está bajo `tenants/{slug}/`)
3. Perfil activo (`tenant: <slug>` en identity.md)
4. Fallback: single-tenant mode (Core puro)

### Cross-tenant enforcement

- Comandos que tocan ficheros fuera del tenant → BLOQUEAR (hook)
- Memory recall no puede cruzar tenants
- Agent memory por tenant en `tenants/{slug}/agent-memory/`
- Audit trail registra `tenant_id` en cada entrada

## Criterios de aceptación

1. `/tenant-create juridico` crea estructura aislada con `rbac.yaml`
2. Cambiar `$SAVIA_TENANT` aísla automáticamente workspace efectivo
3. Hook `tenant-isolation-gate.sh` bloquea lecturas cross-tenant
4. Savia Shield (`data-sovereignty-gate.sh`) respeta tenant boundaries
5. `/rbac-manager grant <role> <user>` funciona y persiste en `rbac.yaml`
6. Audit log incluye `tenant_id` en todas las entradas
7. Test: 2 tenants con perfiles distintos, comandos idénticos, cero filtración

## Out of scope

- SSO/SAML (SE-007)
- Federación cross-instalación (SE-008)
- Billing por tenant (nunca — Savia no es SaaS)

## Dependencias

- SE-001 (extension points)
