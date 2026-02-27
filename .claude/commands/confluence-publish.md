---
name: confluence-publish
description: >
  Publicar documentación del proyecto en Confluence. Convierte markdown
  a formato Confluence y crea/actualiza páginas en el espacio del proyecto.
---

# Publicar en Confluence

**Argumentos:** $ARGUMENTS

> Uso: `/confluence-publish {fichero} --project {p}` o `/confluence-publish --project {p} --type {tipo}`

## Parámetros

- `{fichero}` — Ruta al fichero markdown a publicar (relativa al proyecto)
- `--project {nombre}` — Proyecto de PM-Workspace
- `--space {clave}` — Espacio Confluence (defecto: `CONFLUENCE_DEFAULT_SPACE` del proyecto)
- `--parent {título}` — Página padre bajo la que crear la nueva página
- `--type {tipo}` — Tipo de contenido predefinido:
  - `sprint-report` → publica resultado de `/sprint-review`
  - `spec` → publica una SDD Spec
  - `architecture` → publica diagrama de arquitectura
  - `onboarding` → publica guía de onboarding
  - `retro` → publica resultado de `/sprint-retro`
- `--update` — Actualizar página existente en vez de crear nueva

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Atlassian habilitado
2. `projects/{proyecto}/CLAUDE.md` — `CONFLUENCE_DEFAULT_SPACE`, `JIRA_PROJECT`

## Pasos de ejecución

1. **Verificar conector** — Comprobar Atlassian disponible

2. **Resolver contenido**:
   - Si `{fichero}` → leer el markdown del fichero
   - Si `--type` → generar contenido desde el comando correspondiente
   - Si `--type sprint-report` → ejecutar `/sprint-review` y usar su salida

3. **Convertir markdown → Confluence Storage Format**:
   - Tablas markdown → macro `{table}`
   - Código → macro `{code}` con lenguaje
   - Diagramas Mermaid → imagen renderizada o macro compatible
   - Links internos → ajustar a URLs de Confluence
   - Mantener estructura de headings

4. **Resolver destino**:
   - Espacio: `--space` o `CONFLUENCE_DEFAULT_SPACE`
   - Página padre: `--parent` o raíz del espacio
   - Título: derivado del H1 del markdown o nombre del fichero

5. **Verificar si la página ya existe**:
   - Si existe y `--update` → actualizar contenido
   - Si existe y no `--update` → preguntar: ¿actualizar o crear nueva?
   - Si no existe → crear nueva

6. **Confirmar publicación**:
   ```
   📄 Publicar en Confluence:
   Espacio: {space} | Padre: {parent} | Título: {title}
   Contenido: {líneas} líneas, {tablas} tablas, {imágenes} imágenes
   ¿Confirmar? (y/n)
   ```

7. **Publicar** usando el conector MCP de Atlassian
8. **Confirmar**:
   ```
   ✅ Página publicada en Confluence
   URL: https://org.atlassian.net/wiki/spaces/{space}/pages/{id}
   ```

## Integración con otros comandos

- `/sprint-review --publish-confluence` → publica automáticamente
- `/sprint-retro --publish-confluence` → publica retrospectiva
- `/spec-generate --publish-confluence` → publica la Spec en Confluence
- `/report-executive --publish-confluence` → publica informe ejecutivo

## Restricciones

- **SIEMPRE confirmar antes de publicar** (contenido puede ser sensible)
- No publicar secrets, tokens ni datos confidenciales
- No eliminar páginas existentes
- Si el espacio no existe → informar, no crear espacio
- Máximo 1 publicación por ejecución (evitar spam)
- Respetar permisos del espacio Confluence
