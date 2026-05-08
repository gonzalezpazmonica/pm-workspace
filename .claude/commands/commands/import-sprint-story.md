---
name: import-sprint-story
description: >
  Extrae el historial completo de uno o varios sprints desde Azure DevOps:
  work items, revisiones (cambios de estado y tags) y relaciones (commits, PRs).
  Genera un JSON detallado por sprint en ~/.savia/sprint-history/.
---

# /import-sprint-story

> Extrae la "foto real" de un sprint desde Azure DevOps: qué items había,
> cuándo entraron en cada estado, qué tags de despliegue recibieron y
> qué commits/PRs están enlazados.

## 1. Qué hace

Para cada PBI, Bug y Feature en los sprints indicados:

1. Obtiene campos completos (Effort, State, Tags, AssignedTo, IterationPath, fechas).
2. Descarga el historial de **revisiones**: permite reconstruir cuándo entró
   el item en cada estado y qué tags se fueron añadiendo (QA, PRE, PRO).
3. Obtiene **relaciones**: commits y PRs enlazados al work item.
4. Calcula métricas agregadas por sprint: esfuerzo total, completado,
   porcentaje de avance, distribución por estado.

## 2. Uso

```
/import-sprint-story {proyecto} --sprints 22 23 24 25 26 [opciones]
```

### Opciones

| Parámetro | Obligatorio | Descripción |
|---|---|---|
| `{proyecto}` | Sí | Slug del proyecto (ej. `Project Aurora`). Usa las constantes de `pm-config.local.md`. |
| `--sprints N1 N2 ...` | Sí | Números de sprint a procesar. |
| `--output-dir` | No | Directorio de salida (default: `~/.savia/sprint-history`). |
| `--tags-qa` | No | Tags que evidencian subida a QA (default: `qa,testing_qa,reportado_qa,devuelto-qa`). |
| `--tags-pre` | No | Tags que evidencian subida a PRE (default: `pre,pre-nb`). |
| `--tags-pro` | No | Tags que evidencian subida a PRO (default: `subido a pro,desplegar a pro,pendiente de subida pro`). |

## 3. Configuración requerida

El comando lee las siguientes constantes de `pm-config.local.md`:

- `PROJECT_{PROYECTO}_AZDO_ORG` — Organización de Azure DevOps
- `PROJECT_{PROYECTO}_AZDO_PROJECT` — Nombre del proyecto
- `PROJECT_{PROYECTO}_AZDO_ITERATION` — Raíz de iteraciones (ej. `Project Beacon\Product Development`)
- `PROJECT_{PROYECTO}_AZDO_PAT_FILE` — Ruta al fichero con el PAT

## 4. Flujo de ejecución

### Paso 1 — Resolver configuración del proyecto

1. Leer `.claude/rules/pm-config.local.md` para obtener org, project, iteration root y PAT.
2. Si el proyecto no está configurado, mostrar error y abortar.
3. Validar que el fichero PAT existe y no está vacío.

### Paso 2 — Ejecutar el script de extracción

```bash
python3 scripts/import_sprint_story.py \
  --org "$PROJECT_XXX_AZDO_ORG" \
  --project "$PROJECT_XXX_AZDO_PROJECT" \
  --iteration-root "$PROJECT_XXX_AZDO_ITERATION" \
  --pat-file "$PROJECT_XXX_AZDO_PAT_FILE" \
  --sprints {SPRINTS} \
  [--output-dir {OUTPUT_DIR}] \
  [--tags-qa "{TAGS_QA}"] \
  [--tags-pre "{TAGS_PRE}"] \
  [--tags-pro "{TAGS_PRO}"]
```

### Paso 3 — Mostrar resumen

Tras la ejecución, mostrar un resumen con:

- Número de items por sprint.
- Esfuerzo total y completado.
- Porcentaje de avance.
- Ruta de los ficheros generados.

## 5. Output generado

```
~/.savia/sprint-history/
├── sprint_22_full.json    # Items del sprint 22 con revisiones y relaciones
├── sprint_23_full.json    # Items del sprint 23 con revisiones y relaciones
├── ...
└── summary.json           # Resumen agregado de todos los sprints procesados
```

Cada `sprint_N_full.json` contiene:

```json
{
  "resumen": {
    "sprint": 22,
    "total_items": 45,
    "esfuerzo_total": 120,
    "esfuerzo_completado": 95,
    "porcentaje_completado": 79.2,
    "esfuerzo_por_estado": {"Done": 95, "In Progress": 20, "New": 5}
  },
  "items": [
    {
      "item": { /* campos completos del work item */ },
      "revisiones": [ /* historial de cambios de estado y tags */ ],
      "relaciones": [ /* commits y PRs enlazados */ ],
      "resumen": { /* métricas extraídas del item */ }
    }
  ]
}
```

## 6. Ejemplo

```
/import-sprint-story "Project Aurora" --sprints 22 23 24 25 26

Organización : Acme Corp-digital-team
Proyecto     : Project Beacon
Raíz iter.   : Project Beacon\Product Development
Sprints      : [22, 23, 24, 25, 26]
Salida       : /home/usuario/.savia/sprint-history
---
=== Sprint 22 ===
  IDs obtenidos: 52
  Items con campos: 52
  -> guardado en sprint_22_full.json

=== Sprint 23 ===
  IDs obtenidos: 48
  ...
```

## 7. Restricciones

- Solo operaciones de **lectura** contra Azure DevOps (GET y POST WIQL). No modifica datos.
- La API de Azure DevOps tiene rate limiting; el script incluye pausas entre peticiones.
- Si un sprint no tiene items, se genera un JSON con `total_items: 0`.
- Los ficheros se sobrescriben en cada ejecución (no se versionan; son snapshots puntuales).
