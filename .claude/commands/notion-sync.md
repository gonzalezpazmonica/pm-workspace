---
name: notion-sync
description: >
  Sincronizar documentación del proyecto con Notion. Import/export de
  specs, decisiones arquitectónicas, onboarding y documentación técnica.
---

# Sync Documentación ↔ Notion

**Argumentos:** $ARGUMENTS

> Uso: `/notion-sync --project {p} --direction {dir}` o `/notion-sync {page} --project {p}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace
- `--direction {to-notion|from-notion|bidirectional}` — Dirección (defecto: to-notion)
- `{page}` — URL o ID de página Notion específica (para import)
- `--type {tipo}` — Tipo de contenido a sincronizar:
  - `specs` → SDD Specs del proyecto
  - `decisions` → Decisiones arquitectónicas (ADRs)
  - `onboarding` → Guía de onboarding del equipo
  - `reglas-negocio` → Reglas de negocio del proyecto
  - `all` → Toda la documentación del proyecto
- `--database {id}` — ID de database Notion (defecto: `NOTION_DEFAULT_DATABASE`)
- `--dry-run` — Solo mostrar cambios propuestos

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Notion habilitado
2. `projects/{proyecto}/CLAUDE.md` — `NOTION_DEFAULT_DATABASE`

## Pasos de ejecución — Export (to-notion)

1. **Verificar conector** — Comprobar Notion disponible
2. **Recopilar documentación** del proyecto:
   - Specs: `projects/{p}/specs/*.md`
   - Decisiones: `projects/{p}/decisions/*.md` o ADRs
   - Onboarding: `projects/{p}/onboarding.md`
   - Reglas negocio: `projects/{p}/reglas-negocio.md`
3. **Convertir markdown → Notion blocks**:
   - Headings → heading blocks
   - Tablas → table blocks
   - Código → code blocks con lenguaje
   - Listas → bulleted/numbered list blocks
4. **Detectar páginas existentes** (buscar por título en database)
5. **Presentar propuesta**:
   ```
   ## Sync → Notion — {proyecto}
   | Acción | Documento | Página Notion |
   |---|---|---|
   | CREATE | specs/auth-oauth.md | (nueva) |
   | UPDATE | reglas-negocio.md | Reglas de Negocio (mod. hace 3d) |
   | SKIP | onboarding.md | Sin cambios |
   ```
6. **Confirmar con PM** → ejecutar sync

## Pasos de ejecución — Import (from-notion)

1. **Verificar conector** y resolver página/database
2. **Leer contenido** de Notion usando el conector MCP
3. **Convertir Notion blocks → markdown**
4. **Guardar** en el directorio del proyecto:
   - Si es spec → `projects/{p}/specs/{título}.md`
   - Si es decisión → `projects/{p}/decisions/{título}.md`
   - Si es genérico → `projects/{p}/docs/{título}.md`
5. **Confirmar con PM** antes de sobrescribir ficheros existentes

## Integración con otros comandos

- `/spec-generate --publish-notion` → publica Spec en Notion tras generarla
- `/team-onboarding --publish-notion` → publica guía en Notion
- `/sprint-retro --publish-notion` → publica retrospectiva en Notion
- `/pbi-prd --publish-notion` → publica PRD en Notion

## Restricciones

- **SIEMPRE confirmar antes de sobrescribir** (import puede pisar ficheros locales)
- No eliminar páginas en Notion — solo crear y actualizar
- No modificar databases (estructura) — solo páginas dentro de ellas
- Si `--dry-run` → solo mostrar propuesta
- Máximo 20 páginas por ejecución
- No sincronizar secrets ni credenciales
