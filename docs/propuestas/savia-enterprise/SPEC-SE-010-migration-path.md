# SPEC-SE-010 — Migration Path & Backward Compat

> **Prioridad:** P0 · **Estima:** 4 días · **Tipo:** compatibilidad + migración

## Objetivo

Garantizar que **cualquier usuario actual de Savia Core** (community)
puede activar módulos Enterprise de forma incremental y reversible, sin
romper sus workflows, sin forzar cambios en sus proyectos existentes, y
sin obligarle a aceptar nada que no haya pedido. La migración es opt-in
módulo por módulo.

## Principios afectados

- #5 El humano decide (nada se activa sin confirmación)
- #2 Independencia del proveedor (Enterprise siempre desinstalable)
- #7 Protección de identidad (Savia sigue siendo Savia en ambos modos)

## Diseño

### Estados de instalación

```
                 activar Enterprise
Community  ◀──────────────────────▶  Enterprise
    ▲       desactivar Enterprise        │
    │                                    │
    └──── `savia-enterprise uninstall` ──┘
```

Reversibilidad estricta: desactivar Enterprise devuelve exactamente al
estado Community, sin residuos. Los datos del cliente permanecen intactos
en cualquier sentido.

### Comando `/savia-enterprise`

```
/savia-enterprise status              ← estado actual
/savia-enterprise modules             ← lista módulos disponibles
/savia-enterprise enable <modulo>     ← activar opt-in
/savia-enterprise disable <modulo>    ← desactivar
/savia-enterprise uninstall           ← volver a Core puro
/savia-enterprise migrate-data        ← migración asistida si aplica
```

### Migración de datos

La mayoría de módulos Enterprise NO necesitan migración de datos porque:
- Usan el mismo formato `.md` (principio #1)
- Extienden, no reemplazan
- Los datos del cliente viven en `projects/` (N4), intocables

Los pocos que sí (multi-tenant SE-002) incluyen un wizard:
```
/savia-enterprise migrate-data multi-tenant
→ "Vas a mover projects/ existentes a tenants/default/projects/"
→ "Se mantendrán symlinks de compatibilidad durante 30 días"
→ "Confirmar? [s/N]"
```

### Feature flags

Cada módulo Enterprise tiene flag en `manifest.json`. Comandos Core
comprueban el flag antes de invocar lógica Enterprise:

```bash
if enterprise_enabled "multi-tenant"; then
  resolve_tenant
else
  # Core behavior
fi
```

Si un hook Enterprise falla o está mal configurado, **degradar a Core**,
nunca bloquear al usuario.

### Backward compat tests

Golden set de 30 flujos Core que deben pasar idénticamente con Enterprise
activo o inactivo:
- `/sprint-status`
- `/daily-routine`
- `/pr-plan`
- `/spec-generate`
- `/memory-recall`
- ... etc.

CI ejecuta ambos modos en cada PR a main.

### Aviso de breaking changes

Enterprise sigue semver. Breaking changes en módulos Enterprise:
- Anuncian con 60 días de antelación
- Migration script automático si es posible
- Nunca afectan a Core

## Criterios de aceptación

1. `/savia-enterprise` comando implementado con 6 subcomandos
2. `manifest.json` respetado por todos los módulos Enterprise
3. Golden set de 30 flujos Core con tests en CI (modo on/off)
4. Test: activar → usar → desactivar → estado idéntico al inicial
5. `docs/migration-guide.md` en inglés con pasos reproducibles
6. Uninstall completo no deja ficheros residuales fuera de `tenants/`

## Out of scope

- Migración desde herramientas externas (Jira → Savia, etc. — fuera de Enterprise)
- Auto-update sin confirmación

## Dependencias

- SE-001 (manifest)
- SE-002 (migración multi-tenant como caso más complejo)
