---
name: executive-reporting
description: Generación de informes ejecutivos multi-proyecto para dirección
context: fork
agent: tech-writer
---

# Skill: executive-reporting

> Generación de informes ejecutivos multi-proyecto para dirección: PowerPoint y Word con formato corporativo.

**Prerequisito:** Leer `.claude/skills/azure-devops-queries/SKILL.md` y `.claude/skills/sprint-management/SKILL.md`

## Constantes de esta skill

```bash
OUTPUT_DIR="./output/executive"
CORPORATE_COLOR_PRIMARY="#0078D4"     # Azul corporativo (ajustar a colores de la empresa)
CORPORATE_COLOR_SECONDARY="#F3F3F3"   # Gris claro fondo
CORPORATE_FONT="Calibri"              # Fuente corporativa
LOGO_PATH="./assets/logo.png"         # Logo (crear carpeta assets/ y añadir logo)

# Umbrales de semáforo
VELOCITY_GREEN_THRESHOLD=0.90         # ≥ 90% de media → verde
VELOCITY_YELLOW_THRESHOLD=0.70        # 70-89% → amarillo; < 70% → rojo
BLOCKED_ITEMS_RED_THRESHOLD=2         # ≥ 2 bloqueos activos → rojo
```

---

## Flujo 1 — Recopilar Datos Multi-Proyecto

```bash
# Para cada proyecto activo, ejecutar el flujo de sprint-management
PROYECTOS=("proyecto-alpha" "proyecto-beta")  # leer de CLAUDE.md raíz

for PROYECTO in "${PROYECTOS[@]}"; do
  echo "Obteniendo datos de: $PROYECTO"

  # Leer configuración del proyecto
  source_project_config "$PROYECTO"   # lee projects/$PROYECTO/CLAUDE.md

  # Obtener sprint actual
  az devops configure --defaults organization=$ORG_URL project=$PROJECT_AZDO_NAME
  az boards iteration team list \
    --team "$TEAM_NAME" --timeframe current \
    --output json > /tmp/${PROYECTO}-sprint.json

  # Obtener work items con WIQL
  # [usar la query del flujo 2 de sprint-management/SKILL.md]
  # Guardar en /tmp/${PROYECTO}-items.json

  echo "✅ $PROYECTO: datos obtenidos"
done
```

---

## Flujo 2 — Calcular Semáforo de Estado

```python
def calcular_semaforo(datos_sprint, velocity_media, bloqueados):
    """
    Devuelve: 'verde', 'amarillo', 'rojo'
    """
    sp_completados = datos_sprint['sp_completados']
    sp_planificados = datos_sprint['sp_planificados']
    dias_restantes = datos_sprint['dias_restantes']

    ratio_velocity = sp_completados / velocity_media if velocity_media > 0 else 0
    riesgo_tiempo = (sp_planificados - sp_completados) / (sp_planificados + 1)

    # Lógica de semáforo
    if bloqueados >= 2 or ratio_velocity < 0.70:
        return '🔴', 'Rojo — Sprint en riesgo'
    elif bloqueados >= 1 or ratio_velocity < 0.90 or riesgo_tiempo > 0.6:
        return '🟡', 'Amarillo — Vigilar de cerca'
    else:
        return '🟢', 'Verde — En buen camino'
```

---

## Flujo 3 — Generar PowerPoint Ejecutivo

```bash
node scripts/report-generator.js \
  --type executive \
  --format pptx \
  --proyectos "proyecto-alpha,proyecto-beta" \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-executive-report.pptx"
```

**Estructura de diapositivas:**

| # | Diapositiva | Contenido |
|---|-------------|-----------|
| 1 | Portada | Título, fecha, responsable, logo |
| 2 | Resumen Ejecutivo | Semáforos de todos los proyectos en una vista |
| 3 | Proyecto Alpha | Estado sprint, velocity trend, riesgos |
| 4 | Proyecto Beta | Estado sprint, velocity trend, riesgos |
| 5 | KPIs Consolidados | Tabla comparativa de métricas clave |
| 6 | Hitos Próximos | Timeline de las próximas 4 semanas |
| 7 | Decisiones Requeridas | Items que necesitan atención de dirección |
| 8 | Próximos Pasos | Acciones planificadas para la próxima semana |

---

## Flujo 4 — Generar Word Ejecutivo

```bash
node scripts/report-generator.js \
  --type executive \
  --format docx \
  --proyectos "proyecto-alpha,proyecto-beta" \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-executive-report.docx"
```

**Estructura del Word:**

```
1. Resumen Ejecutivo (1 página)
   - Semáforo global
   - Alertas críticas
   - Logros de la semana

2. Estado por Proyecto (1 página por proyecto)
   - Sprint actual: objetivo, progreso, días restantes
   - Velocity: valor actual vs media
   - Riesgos activos y estado de mitigación
   - Próximos hitos

3. Métricas Consolidadas
   - Tabla KPIs comparativa
   - Análisis de tendencias

4. Plan de la Próxima Semana
   - Ceremonias Scrum programadas
   - Hitos y entregables
   - Decisiones pendientes de dirección
```

---

## Flujo 5 — Enviar por Email (Graph API)

```bash
TOKEN=$(obtener_graph_token)

# Construir email con informe adjunto (en base64)
ATTACHMENT=$(base64 < "$OUTPUT_DIR/$FILENAME")

curl -s -X POST \
  "https://graph.microsoft.com/v1.0/users/$REMITENTE_EMAIL/sendMail" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": {
      \"subject\": \"Informe Ejecutivo PM — $(date '+%d/%m/%Y')\",
      \"body\": { \"contentType\": \"HTML\", \"content\": \"<p>Adjunto el informe semanal de estado de proyectos.</p>\" },
      \"toRecipients\": [{ \"emailAddress\": { \"address\": \"direccion@empresa.com\" } }],
      \"attachments\": [{
        \"@odata.type\": \"#microsoft.graph.fileAttachment\",
        \"name\": \"$FILENAME\",
        \"contentType\": \"application/vnd.openxmlformats-officedocument.presentationml.presentation\",
        \"contentBytes\": \"$ATTACHMENT\"
      }]
    }
  }"
```

> ⚠️ Operación de envío externo — confirmar destinatarios con el usuario antes de enviar.

---

## Plantilla Visual de PowerPoint (esquema de colores)

```
Portada:        Fondo azul corporativo (#0078D4), título blanco, logo esquina superior derecha
Diapositivas:   Fondo blanco, barra superior azul con título blanco, numeración inferior derecha
Semáforos:      Círculo verde (#00B050) / amarillo (#FFC000) / rojo (#FF0000) + texto de estado
Gráficos:       Paleta corporativa, fuente Calibri 10pt, leyenda a la derecha
Tablas:         Cabecera azul oscuro (#003865) texto blanco, filas alternas blanco/#F3F3F3
```

---

## Referencias
→ Skill de datos: `sprint-management/SKILL.md`
→ KPIs calculados: `docs/kpis-equipo.md`
→ Plantillas: `docs/plantillas-informes.md`
→ Script generador: `scripts/report-generator.js`
→ Comando: `/report-executive`
