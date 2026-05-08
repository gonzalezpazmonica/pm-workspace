---
name: flow-setup
description: Configurar proyecto en Azure DevOps para Savia Flow (dual-track, campos custom, áreas)
developer_type: pm
agent: azure-devops-operator
context_cost: moderate
allowed_modes: [pm, lead, all]
---

# /flow-setup — Configurar Savia Flow en Azure DevOps

> Configura tablero dual-track, campos custom y area paths para Savia Flow.

## Prerrequisitos
- Proyecto Azure DevOps existente y validado (`/devops-validate`)
- PAT con permisos: Work Items (R/W), Project (R/W), Process (R)
- Cargar: `@savia-flow-practice/SKILL.md`, `@savia-flow-practice/references/azure-devops-config.md`

## Uso
`/flow-setup [--plan|--execute|--validate] [--project {nombre}]`

## Subcomandos
- `--plan` (default): Muestra cambios propuestos sin ejecutar
- `--execute`: Aplica cambios con confirmación paso a paso
- `--validate`: Verifica que la configuración está correcta post-setup

## Flujo --plan
1. Conectar a Azure DevOps (verificar PAT)
2. Leer configuración actual del board (columnas, campos, áreas)
3. Comparar con configuración Savia Flow:
   - Board columns: Exploration (Discovery, Spec-Writing, Spec-Ready) + Production (Ready, Building, Gate-Review, Deployed, Validating)
   - Custom fields: Track (picklist), Outcome ID (string), Cycle Time Start (datetime), Cycle Time End (datetime)
   - Area Paths: {Project}/Exploration, {Project}/Production
4. Generar plan de cambios: qué se crea, qué se modifica, qué ya existe
5. Mostrar plan en formato tabla

## Flujo --execute
1. Mostrar plan (igual que --plan)
2. Pedir confirmación explícita: "¿Aplicar estos cambios?"
3. Para cada cambio:
   - Crear area paths via REST API
   - Crear custom fields via Process API (si proceso es inherited)
   - Configurar board columns via Board API
   - Configurar WIP limits
4. Verificar cada paso, rollback si falla
5. Mostrar resumen final

## Flujo --validate
1. Verificar area paths existen
2. Verificar campos custom existen en User Story y Task
3. Verificar board columns coinciden
4. Verificar WIP limits configurados
5. Report: PASS/WARN/FAIL por check

## Output
Banner: `🔧 Savia Flow Setup — {proyecto}`
Si >30 líneas → guardar en `projects/{proyecto}/.flow/setup-report.md`

## Errores comunes
- Proceso no es inherited → "Necesitas crear un proceso inherited para añadir campos custom"
- Sin permisos Process → "PAT necesita scope Process (Read & Write)"
- Board ya configurado → "Board ya tiene columnas Savia Flow. Usa --validate para verificar"

## UX
- `--plan` es seguro, ejecutar N veces sin efectos
- `--execute` pide confirmación antes de cada grupo de cambios
- Nunca elimina columnas existentes, solo añade las faltantes
