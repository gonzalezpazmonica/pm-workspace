# /sheets-setup — Crear spreadsheet de seguimiento

**Descripción:** Crea una hoja de cálculo Google Sheets preconfigurada para seguimiento de tareas, métricas y riesgos de un proyecto, con sincronización bidireccional a Azure DevOps.

**Uso:**
```
/sheets-setup {proyecto}
```

**Parámetros:**
- `{proyecto}` (obligatorio) — Nombre del proyecto o clave de Azure DevOps (ej: `alpha`, `sala-reservas`)

## Razonamiento

1. Crear spreadsheet en Google Sheets con 3 hojas
2. Configurar validación de datos y formato
3. Establecer conexión MCP con google-sheets
4. Retornar URL para compartir con stakeholders

## Ejecución

1. **Crear spreadsheet**: Nombre: `[Proyecto] — Seguimiento de Tareas y Métricas`
2. **Hoja 1 — Tasks**: Columnas (ID, Title, Status, Assignee, Estimate, Actual, Sprint, PBI-ref)
3. **Hoja 2 — Metrics**: Columnas (Sprint, Velocity, Burndown, Blockers, Completion%)
4. **Hoja 3 — Risks**: Columnas (ID, Description, Score, Mitigation, Owner, Status)
5. **Validación**: Dropdowns en Status, Score; formatting automático
6. **URL**: Mostrar link para compartir

## Template de Output

```
📋 Spreadsheet creado: [Proyecto] — Seguimiento

🔗 Acceso: https://docs.google.com/spreadsheets/d/{ID}
   (compartir con team → "Editor")

✅ Hoja 1: Tasks (8 columnas)
✅ Hoja 2: Metrics (5 columnas)
✅ Hoja 3: Risks (6 columnas)

🔄 Sincronización: lista para /sheets-sync
```
