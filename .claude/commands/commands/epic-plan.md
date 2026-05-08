---
name: epic-plan
description: >
  Planificación de épicas multi-sprint con roadmap, descomposición
  en PBIs, distribución en sprints y mapeo de dependencias.
agent: business-analyst
skills:
  - pbi-decomposition
  - capacity-planning
  - azure-devops-queries
---

# /epic-plan

Planifica una épica completa: descomposición en PBIs, distribución en sprints,
dependencias y roadmap visual.

---

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **PBI & Backlog** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tools.md`
3. Adaptar output según `identity.rol`, `workflow.sdd_active` y disponibilidad de `tools.azure_devops`
4. Si no hay perfil → continuar con comportamiento por defecto

---

## 2. Flujo

### 2.1. Banner inicio

```
╔══════════════════════════════════════╗
║  🗺️ Epic Plan                        ║
╚══════════════════════════════════════╝
```

### 2. Obtener épica

Leer epic/feature del proyecto usando Azure DevOps API.
Verificar que el work item sea de tipo Epic o Feature.

### 3. Analizar alcance

- Descomponer épica en PBIs (si no existen)
- Estimar Story Points para cada PBI
- Identificar dependencias entre PBIs
- Identificar dependencias externas (otros equipos, APIs, infra)

### 4. Distribuir en sprints

Usando capacity del equipo:

- Ordenar PBIs por: dependencias → prioridad → valor
- Asignar a sprints respetando capacity
- Generar Gantt visual con Mermaid

### 5. Formato de salida

```markdown
## Roadmap: {épica}

### Sprint 1 (DD/MM - DD/MM)
- PBI #X: {título} (SP: Y) → {responsable}
- PBI #Z: {título} (SP: W) → {responsable}
  ⚠️ Depende de: PBI #X

### Sprint 2 ...
```

+ Diagrama Mermaid Gantt

### 6. Guardar output

Fichero: `output/epic-plans/{proyecto}-epic-{id}-{YYYYMMDD}.md`

### 7. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Epic Plan — Completo            ║
╚══════════════════════════════════════╝
📄 Roadmap: output/epic-plans/{proyecto}-epic-{id}-{YYYYMMDD}.md
⚡ /compact
```

