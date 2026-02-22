# /spec:status

Muestra el estado de todas las Specs del sprint activo: pendientes, en progreso, completadas, bloqueadas.

## Uso
```
/spec:status [--project {nombre}] [--sprint {sprint}] [--filter pending|in-progress|blocked|all]
```

- `--project`: Proyecto AzDO (default: todos los proyectos con specs en el sprint activo)
- `--sprint`: Sprint a consultar (default: sprint activo)
- `--filter`: Filtrar por estado (default: `all`)

## Pasos de Ejecución

### Paso 1 — Localizar ficheros de spec del sprint

```bash
SPRINT="${sprint:-$(date +'%Y-%m')}"
SPECS_DIR="projects"

# Encontrar todas las specs del sprint en todos los proyectos
find $SPECS_DIR -path "*/specs/sprint-${SPRINT}/*.spec.md" 2>/dev/null | sort
```

### Paso 2 — Extraer estado de cada spec

Para cada `.spec.md` encontrado, extraer:
```bash
# Estado actual
grep "^\*\*Estado:\*\*" $SPEC_FILE | awk '{print $NF}'

# Developer type
grep "^\*\*Developer Type:\*\*" $SPEC_FILE | awk '{print $NF}'

# Task ID
grep "^\*\*Task ID:\*\*" $SPEC_FILE | grep -oE 'AB#[0-9]+'

# Estimación
grep "^\*\*Estimación:\*\*" $SPEC_FILE | awk '{print $NF}'

# Asignado a
grep "^\*\*Asignado a:\*\*" $SPEC_FILE | cut -d: -f2 | xargs

# Fecha de último update
grep "^\*\*Último update:\*\*" $SPEC_FILE | cut -d: -f2- | xargs
```

### Paso 3 — Mostrar el dashboard

```
📊 SPEC STATUS — Sprint {sprint}
   Generado: {timestamp}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔵 PROYECTO: {proyecto-alpha}   ({N} specs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────┬──────────────────────────────────┬─────────┬──────────────┬───────┬─────────────────────┐
│ Task     │ Spec                             │ Estado  │ Dev Type     │ Horas │ Asignado a          │
├──────────┼──────────────────────────────────┼─────────┼──────────────┼───────┼─────────────────────┤
│ AB#1234  │ B3-create-patient-handler        │ ✅ Done │ agent:single │  4h   │ claude-agent        │
│ AB#1235  │ D1-unit-tests-patient            │ ✅ Done │ agent:single │  3h   │ claude-agent        │
│ AB#1236  │ B3-update-patient-command        │ 🔄 WIP  │ agent:single │  4h   │ claude-agent        │
│ AB#1237  │ C1-patient-repository            │ ⏳ Pend │ human        │  5h   │ María García        │
│ AB#1238  │ E1-code-review                   │ ⏳ Pend │ human        │  2h   │ Carlos Ruiz         │
│ AB#1239  │ B3-create-appointment            │ 🚫 Bloq │ agent:single │  4h   │ -                   │
└──────────┴──────────────────────────────────┴─────────┴──────────────┴───────┴─────────────────────┘

Leyenda: ✅ Completado | 🔄 En Progreso | ⏳ Pendiente | 🚫 Bloqueado

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔵 PROYECTO: {proyecto-beta}   ({N} specs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{tabla similar}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 RESUMEN GLOBAL — Sprint {sprint}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total specs:       {N}
  ✅ Completadas:    {N} ({%})
  🔄 En Progreso:    {N} ({%})
  ⏳ Pendientes:     {N} ({%})
  🚫 Bloqueadas:     {N} ({%})

  Por developer type:
    👤 Human:          {N} specs ({Xh})
    🤖 Agent:Single:   {N} specs ({Xh})
    🤖🤖 Agent:Team:   {N} specs ({Xh})

  Horas ahorradas con agentes (estimado):
    {N} specs de agente × promedio {X}h = {total}h 🟢

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  BLOQUEADOS — Requieren atención
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  AB#1239 — {título}
  Blocker: {descripción del blocker desde la sección 8 de la Spec}
  Necesita: {PM | Tech Lead | humano}
  Fichero: projects/{proyecto}/specs/{sprint}/AB1239-....spec.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Comandos disponibles:
  /spec:implement {spec_file}   — Iniciar implementación de una spec pendiente
  /spec:review {spec_file}      — Revisar una spec antes de implementar
  /agent:run {spec_file}        — Lanzar agente directamente
```

### Formato simplificado (si --filter)

Con `--filter blocked`:
```
🚫 SPECS BLOQUEADAS — Sprint {sprint}

  AB#1239 — {título}
  Blocker: {descripción}
  Fichero: {path}
```

Con `--filter pending`:
```
⏳ SPECS PENDIENTES — Sprint {sprint}

  AB#1237 — {título} (human / María García / 5h)
  AB#1238 — {título} (human / Carlos Ruiz / 2h)
  AB#... — {título} (agent:single / claude-agent / Xh)

  Para lanzar todos los agentes pendientes:
  /agent:run --all-pending --project {proyecto}
```
