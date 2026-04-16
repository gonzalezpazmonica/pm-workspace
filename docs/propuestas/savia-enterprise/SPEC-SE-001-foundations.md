# SPEC-SE-001 — Savia Enterprise Foundations & Layer Contract

> **Prioridad:** P0 · **Estima:** 3 días · **Tipo:** arquitectura + contrato

## Objetivo

Definir el contrato arquitectónico que separa Savia Core de Savia Enterprise
de forma que Core siga siendo 100% usable sin Enterprise y Enterprise no pueda
introducir acoplamientos ocultos. Establecer la estructura de directorios,
los puntos de extensión y las reglas de importación.

## Principios afectados

- #1 Soberanía del dato (Core nunca depende de servicios Enterprise)
- #2 Independencia del proveedor (extensión, no sustitución)
- #7 Protección de identidad (Savia sigue siendo Savia)

## Diseño

### Estructura de directorios
```
.claude/
├── enterprise/                    ← NUEVO (opt-in, MIT)
│   ├── agents/                    ← agentes exclusivos Enterprise
│   ├── commands/                  ← comandos exclusivos Enterprise
│   ├── skills/                    ← skills exclusivos Enterprise
│   ├── rules/                     ← reglas extendidas
│   └── manifest.json              ← módulos activos
├── agents/ commands/ skills/ rules/   ← Core intocable
```

### Contrato de importación (unidireccional)

- Core NUNCA hace `@.claude/enterprise/...`
- Enterprise PUEDE hacer `@docs/rules/domain/...` (extiende)
- Enterprise PUEDE sobrescribir comportamiento vía **registry pattern**
- `validate-layer-contract.sh` verifica la regla en pre-commit

### Manifest

`manifest.json` declara qué módulos Enterprise están activos por instalación.
Sin manifest → Enterprise dormido, Core funciona igual.

```json
{
  "version": "1.0.0",
  "modules": {
    "multi-tenant": { "enabled": false },
    "sovereign-deployment": { "enabled": true },
    "governance-pack": { "enabled": true }
  }
}
```

### Extension points

Seis puntos de extensión formales:

1. **Agent registry** — Enterprise puede añadir agentes sin tocar Core
2. **Hook registry** — hooks Enterprise se encadenan detrás de los de Core
3. **RBAC gate** — interceptor opcional para comandos sensibles
4. **Audit sink** — stream adicional de audit trail
5. **Tenant resolver** — resuelve `$TENANT_ID` si multi-tenant activo
6. **Compliance validator** — validadores opcionales (AI Act, NIS2)

## Criterios de aceptación

1. `ls .claude/enterprise/` existe con subdirectorios vacíos + README
2. `scripts/validate-layer-contract.sh` existe y detecta imports ilegales
3. `manifest.json` schema definido y validable
4. Documentados los 6 extension points en `extension-points.md`
5. Test regresión: desactivar Enterprise → `/sprint-status` y flujos Core siguen funcionando
6. Hook `validate-layer-contract.sh` registrado en PreToolUse para Edit|Write

## Out of scope

- Implementación concreta de módulos (specs siguientes)
- Lógica de RBAC (SE-002)
- Marketplace federado (SE-008)

## Dependencias

Ninguna. Es el cimiento.
