# Regla: Configuración BacklogGit
# ── Versionado de backlogs con snapshots en SaviaHub ─────────────────────────

> BacklogGit captura snapshots periódicos del backlog de cualquier PM tool
> y los almacena como markdown en SaviaHub, dentro del directorio del proyecto.
> Permite auditar cambios, detectar desvíos y restaurar estados anteriores.

## Ubicación de snapshots

```
$SAVIA_HUB_PATH/clients/{client-slug}/projects/{project-slug}/
└── backlog-snapshots/
    ├── 20260301-090000.md    ← Snapshot ordenado por fecha
    ├── 20260305-100000.md
    └── ...
```

## Fuentes soportadas

| Fuente | Extracción | Detección |
|--------|-----------|-----------|
| Azure DevOps | WIQL query via API | `AZURE_DEVOPS_ORG_URL` definida |
| Jira | JQL query via API | `JIRA_BASE_URL` definida |
| GitLab | Issues API | `GITLAB_URL` definida |
| Savia Flow | Leer `projects/{name}/backlog/` | Directorio `backlog/` existe |
| Manual | PM dicta items | Fallback si no hay tool |

Detección automática: comprobar env vars en orden. Si ninguna → modo manual.

## Formato de snapshot

```yaml
---
source: "azure-devops"
client: "acme-corp"
project: "erp-migration"
timestamp: "2026-03-05T10:00:00Z"
total_items: 42
by_state: { new: 10, active: 15, resolved: 12, closed: 5 }
total_estimation_hours: 320
version: 1
---
```

### Tabla de items

```markdown
| ID | Título | Estado | Asignado | Estimación | Prioridad | Tags |
|----|--------|--------|----------|------------|-----------|------|
```

- ID: identificador del PM tool (o secuencial si manual)
- Estimación: en horas (convertir story points si es necesario)
- Prioridad: 1-critical, 2-high, 3-medium, 4-low

## Algoritmo de diff

1. Parsear frontmatter + tabla de ambos snapshots
2. Crear mapa ID→item para cada snapshot
3. Calcular:
   - **Añadidos**: IDs en `to` que no están en `from`
   - **Eliminados**: IDs en `from` que no están en `to`
   - **Modificados**: IDs en ambos con campos diferentes
4. Para modificados, detectar campos cambiados: estado, asignado, estimación, prioridad
5. Calcular métricas: scope creep %, re-estimación total, velocity delta

## Deviation report

Métricas calculadas sobre la serie temporal de snapshots:

- **Scope creep**: `(items_final - items_inicial) / items_inicial × 100`
- **Re-estimación**: `Σ |estimación_actual - estimación_original|` por item
- **Completion rate**: `items_closed / items_total` por snapshot
- **Velocity trend**: items cerrados entre snapshots consecutivos

## Reglas de integridad

- Snapshots son INMUTABLES una vez commiteados (append-only)
- NUNCA modificar un snapshot existente
- NUNCA borrar snapshots sin confirmación explícita del PM
- Rollback genera INFORME, no modifica el backlog original
- El PM aplica cambios manualmente en el PM tool

## Frecuencia recomendada

- Sprint planning → snapshot al inicio
- Sprint review → snapshot al cierre
- Cambios masivos al backlog → snapshot antes y después
- Mínimo recomendado: 1 snapshot por sprint

## Seguridad

- Datos de negocio del cliente → SaviaHub (repo separado, datos reales OK)
- NUNCA incluir credentials del PM tool en snapshots
- Respetar regla PII-Free de pm-workspace para commits en el repo principal
