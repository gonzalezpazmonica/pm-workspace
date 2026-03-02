---
name: company-edit
description: Editar secciones del perfil de empresa — identity, structure, strategy, policies, technology, vertical
developer_type: all
agent: none
context_cost: low
---

# /company-edit

> 🦉 Savia actualiza el perfil de tu empresa.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre, rol

---

## Subcomandos

- `/company-edit identity` — editar nombre, sector, misión, valores
- `/company-edit structure` — editar organigrama, equipos
- `/company-edit strategy` — editar OKRs, prioridades, iniciativas
- `/company-edit policies` — editar políticas de IA, compliance
- `/company-edit technology` — editar stack, herramientas
- `/company-edit vertical` — editar sector, regulaciones

---

## Flujo

### Paso 1 — Verificar permisos

Solo CEO, CTO o usuarios con rol admin pueden editar.

### Paso 2 — Cargar fichero actual

Leer el fichero correspondiente de `.claude/profiles/company/`.

### Paso 3 — Edición guiada

Mostrar contenido actual y preguntar qué cambiar.
Savia sugiere actualizaciones basadas en cambios detectados.

### Paso 4 — Guardar y confirmar

```
✅ Company profile actualizado

  Fichero: {sección}.md
  Campos modificados: {lista}
  Fecha: {timestamp}
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: company_edit
section: "{sección}"
fields_modified: 3
```

---

## Restricciones

- **NUNCA** modificar sin confirmación del usuario
- **NUNCA** borrar secciones completas — solo actualizar campos
- Mantener historial de cambios como comentario YAML al final
- Cada fichero ≤100 líneas
