---
name: wiki-sync
description: >
  Sincronizar documentación entre ficheros locales y Azure DevOps Wiki.
  Bidireccional: local→wiki y wiki→local.
---

# Wiki Sync

**Argumentos:** $ARGUMENTS

> Uso: `/wiki:sync --project {p}` o `/wiki:sync --project {p} --direction {dir}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--direction {push|pull|status}` — Dirección de sync (defecto: status)
- `--path {ruta}` — Sincronizar solo una ruta específica de la wiki
- `--wiki {nombre}` — Nombre de la wiki (defecto: wiki del proyecto)
- `--dry-run` — Solo mostrar cambios, no sincronizar

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `projects/{proyecto}/docs/` — Documentación local del proyecto
3. Azure DevOps Wiki configurada en el proyecto

## Pasos de ejecución

### Modo `status` (por defecto)
1. MCP: `get_wikis` → obtener wiki del proyecto
2. MCP: `get_wiki_page` → listar páginas existentes
3. Comparar con ficheros locales en `projects/{proyecto}/docs/`
4. Mostrar estado de sincronización:

```
## Wiki Sync Status — {proyecto}

| Página | Local | Wiki | Estado |
|---|---|---|---|
| /Architecture/Overview | ✅ | ✅ | 🟢 Sincronizado |
| /API/Endpoints | ✅ | ❌ | 🔵 Solo local |
| /Setup/Installation | ❌ | ✅ | 🟡 Solo wiki |
| /Architecture/Decisions | ✅ | ✅ | 🔴 Conflicto (ambos modificados) |

Sincronizados: 5 | Solo local: 2 | Solo wiki: 1 | Conflictos: 1
```

### Modo `push` (local → wiki)
1. Detectar ficheros locales nuevos o modificados
2. Para cada fichero → MCP: `create_wiki_page` o `update_wiki_page`
3. **Confirmar con PM** antes de cada cambio
4. Reportar resultado

### Modo `pull` (wiki → local)
1. Detectar páginas wiki nuevas o modificadas
2. Para cada página → descargar y guardar en `projects/{proyecto}/docs/`
3. Reportar resultado

## Integración

- `/wiki:publish` → publicar páginas individuales
- `/notion:sync` → patrón similar para Notion
- `/confluence:publish` → patrón similar para Confluence

## Restricciones

- Conflictos requieren resolución manual por el PM
- No soporta sync de imágenes (solo markdown)
- Push requiere confirmación del PM para cada página
