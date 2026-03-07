# /sdlc-policy

**Alias:** none
**Descripción:** Ver y configurar políticas de puertas por proyecto.
**$ARGUMENTS:** [project] [--view|--configure|--reset]

## Parámetros

- `project` — Nombre del proyecto
- `--view` — Mostrar política actual (defecto)
- `--configure` — Editar política de puertas
- `--reset` — Restaurar política por defecto

## Flujo

**--view:** Mostrar transiciones y puertas configuradas

**--configure:** Presentar cada transición y permitir activar/desactivar puertas

**--reset:** Eliminar política de proyecto y volver a global

## Ejemplo

Proyecto: sala-reservas
BACKLOG → DISCOVERY: ✅ Aceptación criteria presentes (requerida)
SPEC_READY → IN_PROGRESS: ✅ Spec aprobada ✅ Revisión seguridad
