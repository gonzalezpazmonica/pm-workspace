---
name: flow-board
description: Visualizar tablero dual-track de Savia Flow (exploración + producción)
developer_type: pm
agent: azure-devops-operator
context_cost: moderate
max_context: 4000
allowed_modes: [pm, lead, dev, qa, all]
---

# /flow-board — Visualizar Tablero Dual-Track Savia Flow

> Muestra tablero dividido: Exploración a la izquierda | Producción a la derecha con métricas en tiempo real.

## Uso
`/flow-board [--track {exploration|production}] [--scope {persona}] [--compact]`

## Subcomandos
- `--track exploration|production`: Mostrar solo una pista (default: ambas)
- `--scope {pm|builder|designer}`: Filtrar por rol/persona
- `--compact`: Formato condensado sin detalles de asignee

## Flujo principal
1. Conectar a Azure DevOps y autenticar
2. Ejecutar WIQL queries para cada track:
   - Exploration: Area Path = {Project}/Exploration, estado != Closed
   - Production: Area Path = {Project}/Production, estado != Closed
3. Agrupar por columna (estado del board)
4. Calcular métricas por columna: count, WIP limit, % de uso
5. Renderizar tablero ASCII side-by-side

## Formato tablero
```
EXPLORATION          │  PRODUCTION
────────────────────┼──────────────────
Discovery (3/∞)     │  Ready (2/5)
Spec-Writing (2/5)  │  Building (4/6)
Spec-Ready (1/3)    │  Gate-Review (1/2)
                    │  Deployed (5/∞)
                    │  Validating (1/∞)
```

- Items destacados en 🔴 si WIP violado
- Per-person allocation: [pm: 2 specs | builder: 3 features]
- Últimas transiciones (moved 5 min ago, etc.)

## Exportación
Si >50 líneas → guardar en `projects/{proyecto}/.flow/board-{date}.md`

## Errores comunes
- Sin conexión DevOps → "¿PAT válida en .env?"
- Proyecto sin area paths → "Ejecuta /flow-setup --plan primero"
