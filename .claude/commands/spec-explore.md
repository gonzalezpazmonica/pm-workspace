---
name: spec-explore
description: Explore and analyze specification documents
---

---

# /spec-explore

Fase de exploración pre-spec. Analiza el codebase para identificar ficheros afectados, patrones existentes y enfoques posibles antes de generar la spec.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **SDD & Agentes** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/projects.md`
3. Adaptar output según `identity.rol` (tech lead vs PM), `workflow.reviews_agent_code`, `workflow.specs_per_sprint`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/spec-explore {task-id} [--project {nombre}]
```

- `{task-id}`: ID de la Task en Azure DevOps (ej: `1234`)
- `--project`: Proyecto (default: proyecto activo de CLAUDE.md)

## 3. Pasos de Ejecución

### 3.1 — Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 /spec-explore — Fase de exploración pre-spec
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Paso 2 — Leer Task de Azure DevOps

```bash
curl -s -u ":$PAT" "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task-id}?api-version=7.1" | jq '{
  id: .id,
  title: .fields["System.Title"],
  description: .fields["System.Description"],
  activity: .fields["Microsoft.VSTS.Common.Activity"]
}'
```

### Paso 3 — Lanzar subagente de exploración

Usar `Task` (subagente) para explorar sin saturar contexto principal:

**Búsqueda de ficheros relacionados:**
- Extraer entidad/módulo del título (ej: "B3: CreateSala" → módulo="Sala")
- Buscar: `*Sala*.cs`, `*SalaHandler*`, `*SalaService*`
- Buscar patrones similares: otros handlers, servicios, repos del mismo patrón

**Análisis de patrones existentes:**
- Patrones arquitectónicos encontrados
- Convenciones de naming/estructura
- Approach de testing (xUnit, FluentAssertions, TestContainers)

**Comparar 3 enfoques posibles:**
1. Enfoque A (ventajas/desventajas)
2. Enfoque B (ventajas/desventajas)
3. Enfoque C (ventajas/desventajas)

### Paso 4 — Guardar resultado

```
output/explorations/{task-id}-exploration.md
```

Formato: Listado de ficheros afectados, patrones identificados, enfoques comparados.

### Paso 5 — Banner de finalización

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /spec-explore — Exploración completada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Resultado: output/explorations/{task-id}-exploration.md

Ficheros afectados ..................... N
Patrones identificados ................. N
Enfoques posibles ....................... 3

Complejidad estimada: BAJA | MEDIA | ALTA

Siguiente: /spec-generate {task-id}
⚡ /compact — Liberar contexto antes del siguiente paso
```

## Notas

- La exploración usa subagente para no saturar contexto
- Output está limitado a 30 líneas de resumen en chat
- Fichero completo guardado para referencia
