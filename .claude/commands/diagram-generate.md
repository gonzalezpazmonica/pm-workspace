---
name: diagram-generate
description: >
  Genera diagrama de arquitectura, flujo o secuencia a partir de la
  infraestructura y código del proyecto. Exporta a Draw.io, Miro o local.
---

# Generar Diagrama de Arquitectura

**Proyecto:** $ARGUMENTS

> Uso: `/diagram-generate {proyecto} [--tool draw.io|miro|local] [--type architecture|flow|sequence]`

## Parámetros

- `{proyecto}` — Nombre del proyecto en `projects/` (obligatorio)
- `--tool {draw.io|miro|local}` — Herramienta destino (default: valor de `DIAGRAM_DEFAULT_TOOL` o `local`)
- `--type {architecture|flow|sequence}` — Tipo de diagrama (default: `architecture`)

## Contexto requerido

Leer en este orden (Progressive Disclosure):

1. `CLAUDE.md` (raíz)
2. `projects/{proyecto}/CLAUDE.md` — Stack, arquitectura, repos
3. `projects/{proyecto}/infrastructure/` — Terraform, Docker, K8s
4. `.claude/rules/diagram-config.md` — Constantes de la feature
5. `.claude/rules/pm-config.md` — Credenciales si tool ≠ local

## Pasos de ejecución

1. **Validar proyecto** — Verificar que `projects/{proyecto}/` existe y tiene `CLAUDE.md`

2. **Invocar la skill** completa:
   → `.claude/skills/diagram-generation/SKILL.md`

3. **Fase 1 — Detectar componentes**:
   - Escanear fuentes del proyecto (IaC, código, docs)
   - Identificar: servicios, DBs, colas, almacenamiento, frontends, externos
   - Extraer relaciones: HTTP, mensajería, acceso a datos, dependencias

4. **Fase 2 — Generar Mermaid**:
   - Usar plantillas de la skill (`diagram-generation` → mermaid-templates)
   - Tipo `architecture` → graph TB con subgraphs por capa
   - Tipo `flow` → flowchart LR con decisiones y caminos
   - Tipo `sequence` → sequenceDiagram con participantes y mensajes

5. **Fase 3 — Exportar** según `--tool`:
   - `local` → Guardar `.mermaid` en `projects/{p}/diagrams/local/`
   - `draw.io` → Convertir a XML, llamar MCP `draw-io`, obtener URL
   - `miro` → Crear shapes/connectors en board, obtener URL

6. **Fase 4 — Guardar metadata** en `projects/{p}/diagrams/{tool}/{tipo}.meta.json`

7. **Presentar resultado**:
   ```
   ✅ Diagrama generado: {tipo} — {proyecto}
   🔗 URL: {link}
   📊 Elementos: {N} servicios, {N} DBs, {N} conexiones
   📁 Local: projects/{p}/diagrams/local/{tipo}.mermaid

   ¿Quieres importar este diagrama para generar Features/PBIs?
   → /diagram-import {url_o_fichero} --project {proyecto}
   ```

## Validaciones previas

- Si `--tool draw.io` → verificar entrada `draw-io` en `mcp.json`
- Si `--tool miro` → verificar token Miro existe (`/diagram-config --tool miro --test`)
- Si proyecto no tiene código ni infraestructura → advertir: "No se detectaron componentes. ¿Quieres crear un diagrama desde cero?"

## Invocar agente (opcional)

Si `--type architecture` y el proyecto tiene >10 componentes:
→ Delegar validación de consistencia al agente `diagram-architect`

## Restricciones

- Crear directorio `diagrams/` si no existe
- No sobrescribir diagramas existentes sin confirmar
- Siempre generar copia local en Mermaid además de la exportación al tool
- No incluir secrets, connection strings ni tokens en el diagrama
