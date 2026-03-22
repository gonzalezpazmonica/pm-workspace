---
name: client-profile-manager
description: "Gestión CRUD de perfiles de cliente en SaviaHub"
summary: |
  Gestion CRUD de perfiles de cliente en SaviaHub.
  Crear, actualizar, listar y buscar clientes con datos de contacto,
  proyectos vinculados y notas. Datos en nivel N4 (proyecto).
maturity: stable
context_cost: medium
dependencies: ["savia-hub-sync"]
category: "pm-operations"
tags: ["client", "profile", "crud", "savia-hub"]
priority: "medium"
---

# Skill: Client Profile Manager

> Regla: @.claude/rules/domain/client-profile-config.md
> Hub: @.claude/rules/domain/savia-hub-config.md

## Prerequisitos

SaviaHub debe existir. Verificar:
```bash
[ -d "$SAVIA_HUB_PATH/.git" ] || echo "ERROR: Run /savia-hub init first"
```
Variable `SAVIA_HUB_PATH` default: `$HOME/.savia-hub`

## Flujo: Crear cliente

1. Recibir nombre del cliente
2. Generar slug: minúsculas, sin acentos, kebab-case
3. Verificar unicidad: `[ ! -d "$SAVIA_HUB_PATH/clients/$SLUG" ]`
4. Crear directorio: `mkdir -p "$SAVIA_HUB_PATH/clients/$SLUG/projects"`
5. Crear `profile.md` con plantilla:
   ```yaml
   ---
   name: "{nombre}"
   slug: "{slug}"
   sector: ""
   since: "{YYYY-MM}"
   status: "active"
   sla_tier: "standard"
   primary_contact: ""
   last_updated: "{YYYY-MM-DD}"
   ---
   ## Descripción
   (Completar con datos del cliente)
   ## Dominio
   (Área de negocio, terminología, conceptos clave)
   ## Stack tecnológico
   (Lenguajes, frameworks, infraestructura)
   ## Metodología
   (Scrum/Kanban/Savia Flow, sprint duration)
   ```
6. Crear `contacts.md` con plantilla:
   ```markdown
   # Contactos — {nombre}
   | Nombre | Rol | Área | Email | Notas |
   |--------|-----|------|-------|-------|
   ```
7. Crear `rules.md` con plantilla:
   ```markdown
   # Reglas — {nombre}
   ## Reglas de negocio
   (Definir reglas del dominio del cliente)
   ## Restricciones técnicas
   (Limitaciones de infraestructura, compatibilidad)
   ## Convenciones de comunicación
   - Idioma:
   - Horario:
   - Canal preferido:
   ```
8. Actualizar `.index.md`: añadir fila con slug, nombre, sector, 0 proyectos, fecha
9. Git commit: `[savia-hub] client: create {slug}`
10. Si remote + no flight-mode → push (delegar a savia-hub-sync skill)

## Flujo: Mostrar cliente

1. Verificar existencia: `[ -d "$SAVIA_HUB_PATH/clients/$SLUG" ]`
2. Leer frontmatter de `profile.md` → extraer campos
3. Contar líneas en `contacts.md` (excluir header) → N contactos
4. Contar reglas en `rules.md` → N reglas
5. Listar subdirectorios en `projects/` → N proyectos
6. Obtener última fecha commit: `git log -1 --format=%ci -- "clients/$SLUG/"`
7. Formatear output con banner 🏢

## Flujo: Editar cliente

1. Verificar existencia del slug
2. Mapear sección al fichero: profile→profile.md, contacts→contacts.md, rules→rules.md
3. Leer fichero actual → mostrar al PM
4. Aplicar ediciones solicitadas
5. Actualizar `last_updated` en profile.md si se modificó cualquier fichero
6. Commit: `[savia-hub] client: update {slug}/{section}`
7. Si remote + no flight-mode → push

## Flujo: Listar clientes

1. Leer `clients/.index.md`
2. Verificar coherencia: comparar con directorios reales en `clients/`
3. Si hay discrepancias → regenerar índice:
   - Recorrer cada `clients/*/profile.md`
   - Extraer name, sector del frontmatter
   - Contar subdirs en projects/
   - Obtener fecha último commit
4. Mostrar tabla formateada con total

## Flujo: Añadir proyecto a cliente

1. Verificar existencia del slug del cliente
2. Generar project-slug: kebab-case
3. Crear `clients/{slug}/projects/{project-slug}/metadata.md`:
   ```yaml
   ---
   name: "{project-name}"
   slug: "{project-slug}"
   status: "active"
   stack: []
   pm_tool: ""
   created: "{YYYY-MM-DD}"
   ---
   ```
4. Actualizar conteo en `.index.md`
5. Commit: `[savia-hub] client: add project {slug}/{project-slug}`

## Errores y recuperación

| Error | Mensaje | Acción |
|-------|---------|--------|
| SaviaHub no existe | `❌ SaviaHub no inicializado` | Sugerir `/savia-hub init` |
| Cliente ya existe | `⚠️ Cliente {slug} ya existe` | Mostrar `/client-show` |
| Slug no encontrado | `❌ Cliente {slug} no encontrado` | Listar similares con fuzzy match |
| Profile sin frontmatter | `⚠️ profile.md sin frontmatter` | Regenerar desde plantilla |

## Seguridad

- NUNCA escribir secrets, tokens o passwords en ficheros de cliente
- SIEMPRE confirmar con PM antes de push al remote
- contacts.md con PII → informar que puede añadirse a `.gitignore`
