---
name: figma-extract
description: >
  Extraer componentes UI y especificaciones de diseño desde Figma.
  Genera PBIs de UI, inventario de componentes y guías de implementación.
---

# Extraer Diseño desde Figma

**Argumentos:** $ARGUMENTS

> Uso: `/figma-extract {url} --project {p}` o `/figma-extract --project {p} --page {nombre}`

## Parámetros

- `{url}` — URL del fichero o frame de Figma
- `--project {nombre}` — Proyecto de PM-Workspace
- `--page {nombre}` — Filtrar por página dentro del fichero Figma
- `--type {tipo}` — Tipo de extracción:
  - `components` → inventario de componentes UI (nombre, props, variantes)
  - `screens` → lista de pantallas/vistas con descripción
  - `design-tokens` → colores, tipografía, spacing, breakpoints
  - `user-flows` → flujos de usuario extraídos de frames
  - `all` → extracción completa
- `--generate-pbis` — Generar PBIs de UI desde los componentes/pantallas extraídos
- `--dry-run` — Solo mostrar extracción, no crear PBIs

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Figma habilitado
2. `projects/{proyecto}/CLAUDE.md` — `FIGMA_DEFAULT_PROJECT`

## Pasos de ejecución

1. **Verificar conector** — Comprobar Figma disponible
   - Si no activado → mostrar instrucciones de activación

2. **Resolver fichero Figma**:
   - Si `{url}` → extraer file key y node ID de la URL
   - Si `--project` → buscar `FIGMA_DEFAULT_PROJECT` en CLAUDE.md
   - Si `--page` → filtrar por nombre de página

3. **Extraer estructura** usando el conector MCP de Figma:
   - Obtener árbol de nodos (pages → frames → components)
   - Identificar componentes, variantes y auto-layouts
   - Extraer estilos aplicados (colores, fuentes, efectos)

4. **Según --type**:

   **components** →
   ```
   ## Inventario de Componentes — {proyecto}
   | Componente | Variantes | Props | Usado en |
   |---|---|---|---|
   | Button | primary, secondary, ghost | label, icon, disabled | Login, Dashboard |
   | Card | default, compact | title, body, actions | Products, Dashboard |
   ```

   **screens** →
   ```
   ## Pantallas — {proyecto}
   | Pantalla | Componentes | Flujo | Notas |
   |---|---|---|---|
   | Login | Button, Input, Logo | Auth Flow | Responsive |
   | Dashboard | Card, Chart, NavBar | Main Flow | Admin only |
   ```

   **design-tokens** →
   ```
   ## Design Tokens — {proyecto}
   ### Colores
   --primary: #2563EB | --secondary: #64748B | ...
   ### Tipografía
   Heading: Inter 24/32 Bold | Body: Inter 16/24 Regular | ...
   ```

5. Si `--generate-pbis` → proponer PBIs:
   - 1 PBI por pantalla/vista principal
   - Tasks por componente a implementar
   - Incluir link al frame de Figma en la descripción
   - **Confirmar con PM antes de crear** (Regla 7)

6. **Guardar resultado** en `output/reports/YYYYMMDD-figma-{proyecto}.md`

## Integración con otros comandos

- `/diagram-generate` puede usar la estructura de Figma como input
- `/pbi-decompose` puede descomponer los PBIs generados en tasks
- `/spec-generate` puede incluir specs de UI desde Figma
- Soporta `--notify-slack` para publicar resumen

## Restricciones

- **Solo lectura** — no modificar ficheros en Figma
- **NUNCA crear PBIs sin confirmación** del PM (Regla 7)
- Si `--dry-run` → solo mostrar extracción
- No descargar imágenes/assets (solo metadatos y estructura)
- No acceder a proyectos Figma sin URL o config explícita
- Máximo 100 componentes por extracción (paginación si más)
