---
name: wiki-publish
description: >
  Publicar documentación y páginas en Azure DevOps Wiki.
  Soporta markdown, imágenes y estructura de páginas.
---

# Wiki Publish

**Argumentos:** $ARGUMENTS

> Uso: `/wiki-publish {file} --project {p}` o `/wiki-publish --project {p} --page {path}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `{file}` — Fichero local a publicar (.md)
- `--page {path}` — Ruta de la página en la wiki (ej: `/Architecture/Overview`)
- `--wiki {nombre}` — Nombre de la wiki (defecto: wiki del proyecto)
- `--update` — Actualizar página existente (en lugar de crear nueva)
- `--dry-run` — Solo preview, no publicar

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. Azure DevOps Wiki configurada en el proyecto

## Pasos de ejecución

### 1. Preparar contenido
- Leer fichero local (.md) o generar contenido desde prompt
- Validar markdown: links, imágenes, formato
- Adaptar paths de imágenes si hay (relative → wiki attachments)

### 2. Verificar wiki destino
- MCP: `get_wikis` → listar wikis disponibles del proyecto
- Si no hay wiki → avisar al PM y sugerir crearla
- Verificar si la página ya existe (`get_wiki_page`)

### 3. Publicar

Si página nueva:
- MCP: `create_wiki_page` con path y contenido
- Confirmar ruta y título con el PM antes de crear

Si actualización (`--update`):
- MCP: `update_wiki_page` con nueva versión del contenido
- Mostrar diff si es posible

### 4. Presentar resultado

```
## Wiki Publish — {proyecto}
Página: /Architecture/Overview
Estado: ✅ Publicada
URL: https://dev.azure.com/{org}/{project}/_wiki/wikis/{wiki}/...
Tamaño: 2.4 KB | Líneas: 85
```

## Integración

- `/wiki-sync` → sincronización bidireccional wiki ↔ local
- `/report-executive` → publicar informes en wiki
- `/confluence-publish` → alternativa para equipos con Confluence

## Restricciones

- NUNCA publicar sin confirmación del PM
- No soporta wikis de tipo "Code Wiki" (solo Project Wiki)
- Imágenes deben subirse como attachments separadamente
