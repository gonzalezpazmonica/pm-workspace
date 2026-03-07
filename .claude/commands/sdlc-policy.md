# /sdlc-policy

**Alias:** none
**Descripción:** Ver y configurar las políticas de puertas (gates) por proyecto.
**$ARGUMENTS:** [project] [--view|--configure|--reset]

## Parámetros

- `project` — Nombre del proyecto (ej: sala-reservas)
- `--view` — Mostrar política actual (defecto)
- `--configure` — Editar política de puertas
- `--reset` — Restaurar política por defecto

## Flujo

**--view** (defecto):
1. Cargar `projects/{proyecto}/policies/sdlc-gates.json` si existe
2. Si no existe → mostrar política global (`sdlc-gates.md`)
3. Mostrar tabla de transiciones y sus puertas configuradas

**--configure**:
1. Presentar cada transición (BACKLOG→DISCOVERY, etc.)
2. Permitir activar/desactivar puertas por transición
3. Guardar en `projects/{proyecto}/policies/sdlc-gates.json`
4. Confirmar cambios

**--reset**:
1. Eliminar `projects/{proyecto}/policies/sdlc-gates.json`
2. Volver a política global

## Ejemplo

```
Proyecto: sala-reservas

BACKLOG → DISCOVERY
  ✅ Aceptación criteria presentes (requerida)
  ❌ Epic vinculado (desactivada en este proyecto)

SPEC_READY → IN_PROGRESS
  ✅ Spec aprobada (requerida)
  ✅ Revisión seguridad (requerida)

Para configurar: /sdlc-policy sala-reservas --configure
