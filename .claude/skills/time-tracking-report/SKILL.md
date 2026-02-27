# Skill: time-tracking-report

> Generación de informes de imputación de horas: extracción de datos, agrupación y exportación a Excel/Word.

**Prerequisito:** Leer primero `.claude/skills/azure-devops-queries/SKILL.md`

## Constantes de esta skill

```bash
OUTPUT_DIR="./output/reports"
REPORT_TEMPLATE="./docs/plantillas-informes.md"    # plantilla de referencia
ACTIVITIES=("Development" "Testing" "Documentation" "Meeting" "Design" "DevOps")

# Actividades a incluir en la agrupación (campo Microsoft.VSTS.Common.Activity)
```

---

## Flujo Completo de Generación

### Paso 1 — Extraer Work Items con Horas

```bash
WIQL='{
  "query": "SELECT [System.Id],[System.Title],[System.WorkItemType],[System.State],[System.AssignedTo],[Microsoft.VSTS.Scheduling.OriginalEstimate],[Microsoft.VSTS.Scheduling.CompletedWork],[Microsoft.VSTS.Scheduling.RemainingWork],[Microsoft.VSTS.Common.Activity],[System.IterationPath] FROM WorkItems WHERE [System.IterationPath] UNDER @CurrentIteration AND [System.TeamProject] = @Project AND [System.WorkItemType] IN ('"'"'Task'"'"','"'"'Bug'"'"') ORDER BY [System.AssignedTo] ASC, [Microsoft.VSTS.Common.Activity] ASC"
}'

PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
curl -s -X POST \
  "$ORG_URL/$PROJECT/_apis/wit/wiql?api-version=7.1" \
  -H "Authorization: Basic $(echo -n ":$PAT" | base64)" \
  -H "Content-Type: application/json" \
  -d "$WIQL" | jq '.workItems[].id' > /tmp/task-ids.json

# Obtener detalles en batch (máx 200 por request)
IDS=$(cat /tmp/task-ids.json | tr '\n' ',' | sed 's/,$//')
curl -s "$ORG_URL/$PROJECT/_apis/wit/workitems?ids=$IDS&fields=System.Id,System.Title,System.WorkItemType,System.State,System.AssignedTo,Microsoft.VSTS.Scheduling.OriginalEstimate,Microsoft.VSTS.Scheduling.CompletedWork,Microsoft.VSTS.Scheduling.RemainingWork,Microsoft.VSTS.Common.Activity&api-version=7.1" \
  -H "Authorization: Basic $(echo -n ":$PAT" | base64)" > /tmp/task-details.json
```

### Paso 2 — Transformar y Agrupar datos

```python
# Usar scripts/report-generator.js o python3 para transformar
# Lógica de agrupación:

import json

with open('/tmp/task-details.json') as f:
    data = json.load(f)

report = {}  # { persona: { actividad: { estimado, completado, restante, items: [] } } }

for item in data['value']:
    fields = item['fields']
    persona = fields.get('System.AssignedTo', {}).get('displayName', 'Sin asignar')
    actividad = fields.get('Microsoft.VSTS.Common.Activity', 'Sin clasificar')
    estimado = fields.get('Microsoft.VSTS.Scheduling.OriginalEstimate', 0) or 0
    completado = fields.get('Microsoft.VSTS.Scheduling.CompletedWork', 0) or 0
    restante = fields.get('Microsoft.VSTS.Scheduling.RemainingWork', 0) or 0

    if persona not in report:
        report[persona] = {}
    if actividad not in report[persona]:
        report[persona][actividad] = {'estimado': 0, 'completado': 0, 'restante': 0, 'items': []}

    report[persona][actividad]['estimado'] += estimado
    report[persona][actividad]['completado'] += completado
    report[persona][actividad]['restante'] += restante
    report[persona][actividad]['items'].append({
        'id': item['id'],
        'titulo': fields.get('System.Title'),
        'estado': fields.get('System.State'),
        'estimado': estimado,
        'completado': completado,
        'restante': restante
    })
```

### Paso 3 — Calcular Desviaciones

```python
def calcular_desviacion(estimado, completado, restante):
    """Calcula la desviación respecto a la estimación original."""
    total_real = completado + restante
    if estimado == 0:
        return None, None  # sin estimación
    desviacion_h = total_real - estimado
    desviacion_pct = (desviacion_h / estimado) * 100
    return desviacion_h, desviacion_pct

# Para cada item: desviacion_h, desviacion_pct = calcular_desviacion(estimado, completado, restante)
# Positivo = excede estimación (rojo), Negativo = va mejor (verde)
```

### Paso 4 — Generar Excel

```bash
# Invocar el generador de informes
node scripts/report-generator.js \
  --type hours \
  --input /tmp/task-details.json \
  --project "$PROJECT_NAME" \
  --sprint "$SPRINT_NAME" \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-hours-$PROJECT_NAME.xlsx"
```

**Estructura del Excel generado:**

| Pestaña | Contenido |
|---------|-----------|
| `Resumen` | Tabla por persona: estimado, completado, restante, desviación, % utilización |
| `Detalle` | Todos los items con todos los campos |
| `Por Actividad` | Agrupación por tipo de actividad con totales |
| `Comparativa` | Horas imputadas vs capacity planificada |

### Paso 5 — Guardar y Notificar

```bash
FILENAME="$(date +%Y%m%d)-hours-${PROJECT_NAME}-${SPRINT_NAME}.xlsx"
OUTPUT_PATH="$OUTPUT_DIR/$FILENAME"

echo "Informe generado: $OUTPUT_PATH"
echo ""
echo "¿Deseas subir el informe a SharePoint? (requiere Graph API configurada)"
echo "Ejecuta: node scripts/report-generator.js --upload --file $OUTPUT_PATH"
```

---

## Subida a SharePoint via Graph API

```bash
# 1. Obtener token de Graph
TOKEN=$(curl -s -X POST \
  "https://login.microsoftonline.com/$GRAPH_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$GRAPH_CLIENT_ID&client_secret=$(cat $GRAPH_CLIENT_SECRET_FILE)&scope=https://graph.microsoft.com/.default&grant_type=client_credentials" \
  | jq -r '.access_token')

# 2. Subir fichero (para ficheros < 4MB)
curl -s -X PUT \
  "https://graph.microsoft.com/v1.0/sites/$SITE_ID/drives/$DRIVE_ID/root:/$SHAREPOINT_REPORTS_PATH/$FILENAME:/content" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" \
  --data-binary @"$OUTPUT_PATH"
```

> ⚠️ Operación de escritura externa — confirmar con el usuario antes de subir.

---

## Formato Word Alternativo

Si se pide formato `.docx` en lugar de `.xlsx`:

```bash
node scripts/report-generator.js \
  --type hours \
  --format docx \
  --input /tmp/task-details.json \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-hours-$PROJECT_NAME.docx"
```

El Word incluye: portada, tabla resumen por persona, tabla detalle con todos los items, y sección de análisis de desviaciones.

---

## Referencias
→ Script generador: `scripts/report-generator.js`
→ Plantilla de informes: `docs/plantillas-informes.md`
→ Comando: `/report-hours`
