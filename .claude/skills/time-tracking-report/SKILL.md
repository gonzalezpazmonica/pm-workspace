---
name: time-tracking-report
description: Generación de informes de imputación de horas a Excel/Word
context: fork
agent: tech-writer
context_cost: medium
---

# Skill: time-tracking-report

> Generación de informes de imputación de horas: extracción de datos, agrupación y exportación a Excel/Word.

**Prerequisito:** Leer primero `.claude/skills/azure-devops-queries/SKILL.md`

## Constantes de esta skill

```bash
OUTPUT_DIR="./output/reports"
ACTIVITIES=("Development" "Testing" "Documentation" "Meeting" "Design" "DevOps")
```

---

## Paso 1 — Extraer Work Items con Horas

```bash
WIQL='{"query": "SELECT [System.Id],[System.Title],[System.WorkItemType],[System.State],[System.AssignedTo],[Microsoft.VSTS.Scheduling.OriginalEstimate],[Microsoft.VSTS.Scheduling.CompletedWork],[Microsoft.VSTS.Scheduling.RemainingWork],[Microsoft.VSTS.Common.Activity],[System.IterationPath] FROM WorkItems WHERE [System.IterationPath] UNDER @CurrentIteration AND [System.TeamProject] = @Project AND [System.WorkItemType] IN ('"'"'Task'"'"','"'"'Bug'"'"') ORDER BY [System.AssignedTo] ASC"}'

PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
curl -s -X POST "$ORG_URL/$PROJECT/_apis/wit/wiql?api-version=7.1" \
  -H "Authorization: Basic $(echo -n ":$PAT" | base64)" \
  -d "$WIQL" | jq '.workItems[].id' > /tmp/task-ids.json

# Obtener detalles en batch (máx 200)
IDS=$(cat /tmp/task-ids.json | tr '\n' ',' | sed 's/,$//')
curl -s "$ORG_URL/$PROJECT/_apis/wit/workitems?ids=$IDS&fields=System.Id,System.Title,System.WorkItemType,System.State,System.AssignedTo,Microsoft.VSTS.Scheduling.OriginalEstimate,Microsoft.VSTS.Scheduling.CompletedWork,Microsoft.VSTS.Scheduling.RemainingWork,Microsoft.VSTS.Common.Activity&api-version=7.1" \
  -H "Authorization: Basic $(echo -n ":$PAT" | base64)" > /tmp/task-details.json
```

---

## Paso 2 — Transformar y Agrupar datos

> Detalle: @references/aggregation-logic.md

Agrupación por: persona → actividad → (estimado, completado, restante, items)

---

## Paso 3 — Calcular Desviaciones

> Detalle: @references/deviation-formula.md

```bash
desviacion_h = (completado + restante) - estimado
desviacion_pct = (desviacion_h / estimado) * 100

Positivo = excede estimación (🔴)
Negativo = va mejor (🟢)
```

---

## Paso 4 — Generar Excel

```bash
node scripts/report-generator.js \
  --type hours --input /tmp/task-details.json \
  --project "$PROJECT_NAME" --sprint "$SPRINT_NAME" \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-hours-$PROJECT_NAME.xlsx"
```

> Detalle: @references/excel-structure.md

Pestañas: Resumen | Detalle | Por Actividad | Comparativa

---

## Paso 5 — Guardar y Notificar

```bash
FILENAME="$(date +%Y%m%d)-hours-${PROJECT_NAME}-${SPRINT_NAME}.xlsx"
OUTPUT_PATH="$OUTPUT_DIR/$FILENAME"
echo "Informe guardado: $OUTPUT_PATH"
```

---

## Subida a SharePoint (Graph API)

```bash
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$GRAPH_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$GRAPH_CLIENT_ID&client_secret=$(cat $GRAPH_CLIENT_SECRET_FILE)&scope=https://graph.microsoft.com/.default&grant_type=client_credentials" \
  | jq -r '.access_token')

curl -s -X PUT "https://graph.microsoft.com/v1.0/sites/$SITE_ID/drives/$DRIVE_ID/root:/$SHAREPOINT_REPORTS_PATH/$FILENAME:/content" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" \
  --data-binary @"$OUTPUT_PATH"
```

> ⚠️ Confirmar con usuario antes de subir.

---

## Formato Word Alternativo

```bash
node scripts/report-generator.js \
  --type hours --format docx --input /tmp/task-details.json \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-hours-$PROJECT_NAME.docx"
```

Contenido: Portada | Resumen por persona | Detalle items | Análisis desviaciones

---

## Referencias

- `references/aggregation-logic.md` — Lógica agrupación
- `references/deviation-formula.md` — Fórmula desviaciones
- `references/excel-structure.md` — Estructura Excel
- Comando: `/report-hours`
