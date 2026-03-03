# Guía: Consultora de Software con Jira

> Escenario: equipo de desarrollo que usa Jira como herramienta de gestión de proyectos, posiblemente combinado con GitHub/GitLab para código y CI/CD.

---

## Tu equipo

| Rol | Qué necesita de Savia |
|---|---|
| **PM / Scrum Master** | Sincronización Jira ↔ Savia, informes, sprint management |
| **Tech Lead** | Arquitectura, code review, deuda técnica |
| **Developers** | Foco diario, specs SDD, implementación |
| **Product Owner** | Backlog grooming, priorización, métricas de valor |

---

## Setup inicial

### 1. Instalar pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Conectar Jira

> "Savia, conecta mi proyecto de Jira"

Savia ejecutará `/jira-connect` que te guía por:

- URL de tu instancia Jira (Cloud o Server)
- API token (se guarda en fichero local, nunca en el repo)
- Proyecto a sincronizar
- Mapeo de estados (To Do → New, In Progress → Active, Done → Closed)

### 3. Sincronización bidireccional

```
/jira-sync                         → Sincroniza items Jira ↔ Savia
/jira-connect map                  → Revisa/ajusta el mapeo de campos
```

La sincronización es bidireccional: los cambios en Jira se reflejan en Savia y viceversa. Savia mantiene su propio modelo de datos para análisis avanzado sin depender de la API de Jira en cada operación.

---

## Modo híbrido: Jira + Savia

El patrón más común es usar Jira como "fuente de verdad" para el cliente/stakeholders y Savia como herramienta interna del equipo técnico:

**En Jira** (visible para el cliente):
- Epics, Stories, Bugs
- Sprint board
- Releases

**En Savia** (potencia interna):
- Descomposición inteligente de PBIs → `/pbi-decompose`
- Specs SDD ejecutables → `/spec-generate`
- Code review automatizado → `/pr-review`
- Métricas predictivas → `/sprint-forecast`
- Deuda técnica → `/debt-analyze`

### Flujo típico

1. PO crea Story en Jira
2. `/jira-sync` trae el item a Savia
3. PM descompone con `/pbi-decompose` → tasks quedan en Savia
4. Dev implementa con SDD → `/spec-generate` + `/spec-implement`
5. PR + merge → hooks de calidad automáticos
6. `/jira-sync` actualiza el estado en Jira
7. Cliente ve progreso en su board de Jira

---

## Día a día del PM

### Mañana

> "Savia, sincroniza Jira y dame el estado del sprint"

```
/jira-sync                         → Trae cambios de Jira
/sprint-status                     → Estado con datos frescos
/daily-routine                     → Rutina del día según tu rol
```

### Standup

> "Savia, prepara los datos para la daily"

Savia combina datos de Jira (estados, asignaciones) con métricas propias (velocity, burndown, bloqueos detectados) para darte un resumen completo.

### Fin del sprint

```
/sprint-review                     → Resumen de entrega
/sprint-retro                      → Retrospectiva
/report-executive                  → Informe para stakeholders
/jira-sync                         → Asegurar que Jira refleja todo
```

---

## Día a día del Developer

> "Savia, ¿qué tengo asignado hoy?"

```
/my-sprint                         → Tu vista personal
/my-focus                          → Item más prioritario
```

### Implementación SDD

El flujo SDD funciona igual que con Azure DevOps — la spec es agnóstica de la herramienta de gestión:

1. `/spec-generate {jira-key}` → genera spec desde el Jira issue
2. `/spec-implement {spec}` → implementa
3. `/pr-review` → code review automatizado
4. Al completar, `/jira-sync` actualiza el estado en Jira

---

## Diferencias con Azure DevOps

| Aspecto | Azure DevOps | Jira |
|---|---|---|
| Conexión | Nativa (API REST) | Via `/jira-connect` + sync |
| Pipelines | `/pipeline-*` directo | GitHub Actions / GitLab CI separado |
| Work items | WIQL queries | JQL queries via sync |
| Mapeo de estados | Automático (Agile template) | Configurable con `/jira-connect map` |
| Board | Azure Boards | Jira Board + `/savia-board` local |

---

## Tips específicos para Jira

- Sincroniza con frecuencia (`/jira-sync`) para mantener datos frescos
- Los custom fields de Jira se mapean a campos Savia en la configuración
- Si usas Jira Cloud, la API es más rápida que Jira Server
- Savia puede trabajar con múltiples proyectos Jira simultáneamente
- Los informes de Savia (`/report-executive`, `/kpi-dashboard`) son más ricos que los nativos de Jira porque combinan datos de código, PRs y métricas de flujo
- Si tu cliente solo quiere ver Jira, usa Savia como herramienta interna y sincroniza resultados
