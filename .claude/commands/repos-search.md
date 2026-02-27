---
name: repos-search
description: >
  Buscar código en repositorios de Azure DevOps. Soporta filtro
  por repo, tipo de fichero y ruta.
---

# Repos Search

**Argumentos:** $ARGUMENTS

> Uso: `/repos:search --project {p} {query}` o con filtros

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `{query}` — Texto a buscar (obligatorio)
- `--repo {nombre}` — Filtrar por repositorio (opcional)
- `--path {ruta}` — Filtrar por ruta (ej: `src/services/`)
- `--extension {ext}` — Filtrar por extensión (ej: `cs`, `ts`, `py`)
- `--top {n}` — Máximo resultados (defecto: 25)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — `AZURE_REPOS_PROJECT`

## Pasos de ejecución

1. **Construir query** con filtros aplicados
2. **MCP `search_code`** → buscar en repos del proyecto
3. **Agrupar resultados** por repo y fichero
4. **Presentar:**

```
## Búsqueda: "{query}" — {proyecto}

### backend-api (8 resultados)
| Fichero | Línea | Coincidencia |
|---|---|---|
| src/services/AuthService.cs | L45 | `public async Task<Token> RefreshOAuth(...)` |
| src/controllers/AuthController.cs | L23 | `// OAuth refresh endpoint` |

### frontend-app (3 resultados)
| Fichero | Línea | Coincidencia |
|---|---|---|
| src/auth/oauth.ts | L12 | `export const refreshToken = async ()` |

Total: 11 resultados en 2 repositorios
```

## Integración

- `/repos:pr-create` → si buscas código para entender el impacto de un cambio
- `/spec:generate` → buscar implementación existente antes de generar spec

## Restricciones

- Solo lectura
- Máximo 100 resultados por búsqueda
- Requiere Azure DevOps Search habilitado en la organización
- Si Search no está habilitado → informar al PM
