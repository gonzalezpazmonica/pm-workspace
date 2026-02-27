---
name: backlog-capture
description: >
  Crear PBIs desde input desestructurado: emails, notas de reunión,
  tickets de soporte, conversaciones de Slack.
---

# Backlog Capture

**Argumentos:** $ARGUMENTS

> Uso: `/backlog-capture --project {p} --source {tipo}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--source {tipo}` — Origen: `text`, `email`, `slack`, `file`, `support`
- `--input {contenido}` — Texto directo o ruta a fichero
- `--channel {canal}` — Canal de Slack (con `--source slack`)
- `--since {fecha}` — Desde cuándo buscar (formato YYYY-MM-DD)
- `--dry-run` — Solo mostrar PBIs propuestos, no crear en Azure DevOps
- `--priority {auto|must|should|could}` — Priorización (auto = inferida)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `.claude/skills/azure-devops-queries/SKILL.md` — Para crear work items
3. `.claude/skills/pbi-decomposition/SKILL.md` — Formato PBI estándar

## Pasos de ejecución

### 1. Obtener input
- **text**: el PM pega texto directamente en el prompt
- **file**: leer fichero indicado (`.md`, `.txt`, `.eml`, `.csv`)
- **slack**: usar `/slack-search` con filtros de canal y fecha
- **email**: leer fichero `.eml` o texto pegado del email
- **support**: leer CSV/JSON de tickets de soporte

### 2. Analizar y extraer
Usar agente `business-analyst` para:
1. Identificar necesidades/problemas/solicitudes en el texto
2. Eliminar duplicados con backlog existente (WIQL query)
3. Clasificar cada item: Feature, Bug, Improvement, Spike
4. Extraer: título, descripción, criterios de aceptación (si infiere)
5. Asignar prioridad (si `--priority auto`, inferir del contexto)

### 3. Formatear como PBIs

Para cada item detectado:
```
### PBI candidato #{n}
Tipo: User Story | Bug | Spike
Título: {título inferido}
Descripción: Como {persona}, quiero {acción}, para {beneficio}
Criterios de aceptación:
- [ ] {criterio 1}
- [ ] {criterio 2}
Prioridad: {Must|Should|Could}
Fuente: {email de X / Slack #canal / reunión de Y}
Duplicado de: — (o #ID si existe similar)
```

### 4. Presentar resumen

```
## Backlog Capture — {proyecto}
Fuente: {tipo} | Items analizados: {n} | PBIs propuestos: {m}

| # | Tipo | Título | Prioridad | Duplicado |
|---|---|---|---|---|
| 1 | Story | Login con SSO | Must | — |
| 2 | Bug | Error 500 en /api/users | Must | ~#1234 |
| 3 | Improvement | Mejorar UX de búsqueda | Should | — |

Descartados: 2 (duplicados exactos de #1230, #1245)
```

### 5. Crear en Azure DevOps
- Si `--dry-run` → solo mostrar, no crear
- Si no → **confirmar con PM** antes de crear cada PBI
- Crear work items con link a fuente original si posible
- Asignar al backlog del proyecto, sin sprint (para refinement)

## Integración

- `/pbi-decompose` → descomponer los PBIs creados en tasks
- `/sprint-plan` → incluir PBIs capturados en planning
- `/slack-search` → fuente de input para captura desde Slack
- `/project-audit` → puede generar input para backlog-capture

## Restricciones

- NUNCA crear PBIs sin confirmación del PM (regla 7)
- Duplicados detectados se marcan, no se eliminan del backlog
- Priorización automática es sugerencia, PM decide final
- Textos muy ambiguos → crear como Spike para refinement
