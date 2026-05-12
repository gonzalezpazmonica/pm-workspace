---
name: skill-eval
description: >
  Evalúa qué skills son relevantes para el prompt o contexto actual.
  Analiza el prompt del usuario, el proyecto activo, y los skills disponibles
  para recomendar activaciones automáticas.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---

# /skill-eval {subcommand} {args}

Subcommands: analyze, recommend, activate, history, tune

## Prerequisitos

1. Verificar que `.opencode/skills/` existe y contiene skills
2. Si se especifica proyecto, verificar que `projects/{proyecto}/` existe
3. Cargar registro de activaciones: `.opencode/skills/eval-registry.json`

## Ejecución

### /skill-eval analyze {prompt}

1. Banner: `══ /skill-eval analyze ══`
2. Leer todos los SKILL.md en `.opencode/skills/*/SKILL.md`
3. Extraer: name, description, context, agent de cada skill
4. Analizar el prompt contra:
   - Keywords del description de cada skill
   - Contexto del proyecto activo (si existe)
   - Historial de activaciones recientes
5. Calcular score de relevancia (0-100) por skill
6. Mostrar top-5 skills ordenados por score
7. Banner fin

### /skill-eval recommend

1. Banner: `══ /skill-eval recommend ══`
2. Analizar el contexto actual (último comando, proyecto, ficheros abiertos)
3. Sugerir skills que podrían mejorar la tarea actual
4. Formato: tabla con skill, relevancia (%), razón

### /skill-eval activate {skill-name}

1. Registrar activación en eval-registry.json
2. Cargar el SKILL.md correspondiente
3. Confirmar activación

### /skill-eval history

1. Mostrar últimas 20 activaciones con fecha, skill, prompt, resultado

### /skill-eval tune {skill-name} {+|-}

1. Ajustar peso del skill (+1 o -1) basado en feedback del usuario
2. Actualizar eval-registry.json con nuevo peso
3. Confirmar ajuste

## Output

Tabla de skills recomendados con score de relevancia.

## Reglas

- Nunca activar un skill automáticamente sin confirmación del usuario
- Los scores se basan en: match de keywords (40%), contexto de proyecto (30%), historial (30%)
- Si ningún skill supera score 30, informar que no hay recomendaciones
- Respetar el tuning del usuario: skills con feedback negativo bajan prioridad
- Máximo 5 recomendaciones simultáneas
