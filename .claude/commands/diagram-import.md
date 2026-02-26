---
name: diagram-import
description: >
  Importa un diagrama de arquitectura (Draw.io, Miro o local) y genera
  Features, PBIs y Tasks en Azure DevOps. Valida reglas de negocio antes.
---

# Importar Diagrama → Generar Work Items

**Fuente:** $ARGUMENTS

> Uso: `/diagram:import {source} --project {nombre} [--validate-only] [--dry-run]`

## Parámetros

- `{source}` — URL de Draw.io, URL de Miro, fichero local (.drawio, .xml, .mermaid), o ID de meta.json existente
- `--project {nombre}` — Proyecto destino en Azure DevOps (obligatorio)
- `--validate-only` — Analiza y valida sin crear work items
- `--dry-run` — Muestra la propuesta sin crear nada (comportamiento por defecto)

## Contexto requerido

Leer en este orden (Progressive Disclosure):

1. `CLAUDE.md` (raíz)
2. `projects/{proyecto}/CLAUDE.md` — Stack, arquitectura
3. `projects/{proyecto}/reglas-negocio.md` — **CRÍTICO**: reglas de dominio
4. `projects/{proyecto}/equipo.md` — Para asignación posterior
5. `.claude/rules/diagram-config.md` — Constantes y checklist validación
6. `.claude/rules/pm-config.md` — Credenciales

## Pasos de ejecución

1. **Invocar la skill** completa:
   → `.claude/skills/diagram-import/SKILL.md`

2. **Fase 1 — Obtener diagrama** según tipo de source:
   - URL Draw.io → MCP `draw-io` para leer XML
   - URL Miro → MCP `miro` para leer board
   - Fichero local → leer directamente
   - Parsear → modelo normalizado (entidades + relaciones)

3. **Fase 2 — Validar arquitectura**:
   - Invocar agente `diagram-architect`
   - Si hay problemas ❌ bloqueantes → informar y recomendar corregir

4. **Fase 3 — Validar reglas de negocio** ⚠️ PASO CRÍTICO:
   - Leer `projects/{p}/reglas-negocio.md`
   - Si no existe → solicitar al PM, NO continuar
   - Verificar checklist por entidad (ver skill `diagram-import` → business-rules-validation)
   - Si falta información obligatoria → mostrar informe detallado
   - Ofrecer opciones: completar info, generar parcial, generar draft

5. **Fase 4 — Generar jerarquía** (si reglas OK o PM elige parcial/draft):
   - Features por bounded context / módulo
   - PBIs por funcionalidad / endpoint / user story
   - Tasks por requisito técnico
   - Usar templates de la skill (`diagram-import` → pbi-generation-templates)

6. **Fase 5 — Presentar propuesta** en tabla con SP estimados
   - Preguntar: "¿Creo estos work items en Azure DevOps?"

7. **Fase 6 — Crear en Azure DevOps** (tras confirmación):
   - Features → PBIs → Tasks con links jerárquicos
   - Tags: `diagram-import`, tipo de entidad
   - Link al diagrama source en Description
   - Actualizar metadata local

## Ejemplo

```
/diagram:import https://miro.com/app/board/uXjVN... --project ProyectoAlpha
/diagram:import projects/alpha/diagrams/local/architecture.mermaid --project ProyectoAlpha
/diagram:import --validate-only projects/alpha/diagrams/local/flow.mermaid --project ProyectoAlpha
```

## Restricciones

- ❌ **NUNCA crear PBIs sin validar reglas de negocio primero**
- Siempre modo dry-run por defecto — requiere confirmación explícita para crear
- No sobrescribir work items existentes — detectar duplicados por tag + nombre
- Si `--validate-only` → solo análisis + informe, no ofrece crear
- Máximo 50 PBIs por importación — si hay más, dividir en lotes
