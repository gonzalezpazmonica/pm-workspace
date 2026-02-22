# Plantillas de Informes

> Define las plantillas y estructura de cada tipo de informe que genera Claude Code. Actualizar con feedback del cliente/dirección.

## Constantes de Reporting

```
REPORT_AUTHOR         = "Equipo PM"                       # ← poner nombre real
REPORT_LOGO           = "./assets/logo.png"
CORPORATE_COLOR       = "#0078D4"
REPORT_FOOTER         = "Confidencial — uso interno"
DATE_FORMAT           = "DD/MM/YYYY"
REPORT_OUTPUT_DIR     = "./output"
UPLOAD_SHAREPOINT     = false                              # cambiar a true cuando Graph API esté configurado
EMAIL_DESTINATARIOS   = ["pm@empresa.com"]                 # ← configurar destinatarios reales
```

---

## Tipo 1 — Informe de Sprint (post-Review)

**Cuándo:** Al finalizar cada Sprint Review
**Formato:** Word (.docx) + resumen en Markdown
**Destino:** `output/sprints/YYYYMMDD-sprint-review-[proyecto]-[sprint].docx`
**Comando:** `/sprint:review`

### Estructura

```
1. PORTADA
   - Nombre del proyecto
   - Sprint: [nombre] ([fechas])
   - Sprint Goal: [objetivo acordado]
   - Fecha de generación
   - Responsable: [PM]

2. RESUMEN EJECUTIVO (½ página)
   - Sprint Goal: ✅ Cumplido / ⚠️ Parcial / ❌ No cumplido
   - Story Points completados: X/Y (Z%)
   - Velocity: X SP (media últimos 5: Y SP)
   - Items completados: X | Items no completados: Y

3. ITEMS COMPLETADOS
   Tabla: ID | Título | SP | Responsable | Estado
   Total: X items, Y SP

4. ITEMS NO COMPLETADOS → BACKLOG
   Tabla: ID | Título | SP | Motivo de no completar | Sprint propuesto

5. BUGS DEL SPRINT
   Tabla: ID | Título | Severidad | Estado | Responsable

6. MÉTRICAS DEL SPRINT
   - Cycle Time medio: X días
   - Capacity Utilization: X%
   - Bug Escape Rate: X%
   - Horas imputadas vs planificadas

7. IMPEDIMENTOS Y RIESGOS
   - Impedimentos activos y estado de resolución
   - Riesgos identificados para el siguiente sprint

8. RETROSPECTIVA — ACTION ITEMS
   Tabla: Acción | Responsable | Fecha límite

9. PREVIEW DEL PRÓXIMO SPRINT
   - Sprint Goal propuesto
   - PBIs candidatos
   - Capacity estimada
```

---

## Tipo 2 — Informe Semanal para Dirección

**Cuándo:** Cada viernes antes de las 18:00
**Formato:** PowerPoint (.pptx) — máximo 8 diapositivas
**Destino:** `output/executive/YYYYMMDD-weekly-report.pptx`
**Comando:** `/report:executive`

### Estructura de diapositivas

```
Diapositiva 1 — PORTADA
  Título: "Estado de Proyectos — Semana WW/YYYY"
  Subtítulo: Fecha | Responsable | Logo

Diapositiva 2 — SEMÁFORO GLOBAL
  Grid de proyectos con semáforo: 🟢🟡🔴
  Tabla: Proyecto | Sprint | Semáforo | Sprint Goal | Días restantes

Diapositiva 3 — PROYECTO ALPHA (repetir por cada proyecto)
  - Sprint actual: objetivo + progreso (barra)
  - Velocity trend: gráfico barras últimos 5 sprints
  - Riesgos activos: tabla (riesgo, impacto, mitigación)
  - Próximos hitos: 30 días

Diapositiva N — KPIs CONSOLIDADOS
  Tabla comparativa de los 8 KPIs entre proyectos

Diapositiva N+1 — HITOS PRÓXIMAS 4 SEMANAS
  Timeline visual o tabla: Semana | Proyecto | Hito | Responsable

Diapositiva N+2 — DECISIONES REQUERIDAS
  Tabla: Decisión | Contexto | Fecha límite | Propietario

Diapositiva N+3 — PRÓXIMOS PASOS
  Lista de acciones para la próxima semana
```

---

## Tipo 3 — Informe de Imputación de Horas

**Cuándo:** Al finalizar cada sprint o bajo demanda
**Formato:** Excel (.xlsx) — 4 pestañas
**Destino:** `output/reports/YYYYMMDD-hours-[proyecto]-[sprint].xlsx`
**Comando:** `/report:hours`

### Estructura

```
Pestaña 1 — RESUMEN
  Cabecera: Proyecto | Sprint | Período | Equipo
  Tabla por persona:
    Persona | Email | Estimado (h) | Imputado (h) | Restante (h) | Desviación | % Utilización
  Fila totales con suma y porcentaje de desviación global
  Gráfico de barras: estimado vs imputado por persona

Pestaña 2 — DETALLE POR PERSONA
  Para cada persona, tabla completa de work items:
    ID | Título | Tipo | Estado | Actividad | Estimado | Completado | Restante | Desviación
  Subtotal por persona al final de cada bloque

Pestaña 3 — POR ACTIVIDAD
  Tabla de agrupación:
    Actividad | Total items | Horas totales | % del total
  Gráfico circular (donut) de distribución de horas por actividad
  (Development, Testing, Documentation, Meeting, Design, DevOps)

Pestaña 4 — COMPARATIVA SPRINTS
  Tabla histórica (últimos 5 sprints):
    Sprint | Total Horas | Capacity | % Utilización | Velocity (SP)
  Gráfico de línea: evolución de horas imputadas y capacity
```

---

## Tipo 4 — Dashboard de Proyecto

**Cuándo:** Bajo demanda o como adjunto al informe semanal
**Formato:** HTML interactivo o Excel
**Destino:** `output/reports/YYYYMMDD-dashboard-[proyecto].html`
**Comando:** `/kpi:dashboard`

### Widgets del dashboard

```
Widget 1 — Burndown del sprint actual
  Gráfico de líneas: remaining ideal vs remaining real (día a día)

Widget 2 — Velocity trend
  Gráfico de barras: últimos 8 sprints con línea de tendencia

Widget 3 — Cumulative Flow Diagram
  Gráfico de área apilada: New | Active | In Review | Done (últimas 2 semanas)

Widget 4 — Bug trend
  Gráfico: bugs abiertos vs cerrados por sprint

Widget 5 — Semáforo de KPIs
  Grid: 8 KPIs con valor actual, referencia y semáforo

Widget 6 — Carga del equipo
  Tabla: persona | WIP | Remaining Work | % capacity
```

---

## Tipo 5 — Informe de Capacidad

**Cuándo:** Al inicio de cada sprint (para el planning) y bajo demanda
**Formato:** Markdown o tabla en terminal
**Destino:** `output/reports/YYYYMMDD-capacity-[proyecto]-[sprint].md`
**Comando:** `/report:capacity`

### Estructura

```
1. CAPACITY POR PERSONA
   Tabla: Persona | Días disponibles | Días off | Horas disponibles | Actividad principal
   + Días off detallados (vacaciones, festivos)

2. CARGA ASIGNADA
   Tabla: Persona | Horas asignadas (sum RemainingWork) | % Utilización | Estado

3. ALERTAS
   - Personas sobre-cargadas
   - Personas sin capacidad configurada en Azure DevOps
   - Festivos del período no configurados

4. RECOMENDACIONES
   - Redistribución de carga si hay sobre/sub-asignación
   - Ajuste de SP planificados si capacity es limitada
```

---

## Guía de Estilo Visual

### Colores del semáforo (usar siempre estos)
```
Verde:    #00B050 (fondo) / texto negro
Amarillo: #FFC000 (fondo) / texto negro
Rojo:     #FF0000 (fondo) / texto blanco
```

### Formato de tablas en Excel
```
Cabecera:         fondo #003865 (azul oscuro) + texto blanco + negrita
Filas impares:    fondo blanco
Filas pares:      fondo #F3F3F3
Fila de totales:  fondo #E6EFF7 + negrita
Bordes:           #CCCCCC, 1pt, todos los lados
Fuente:           Calibri 10pt (cuerpo), Calibri 11pt negrita (cabecera)
```

### Nomenclatura de ficheros generados
```
YYYYMMDD-[tipo]-[proyecto]-[sprint/periodo].[ext]

Ejemplos:
  20260222-sprint-review-alpha-sprint2026-04.docx
  20260222-hours-beta-sprint2026-04.xlsx
  20260222-weekly-report.pptx
  20260222-dashboard-alpha.html
  20260222-capacity-alpha-sprint2026-05.md
```
