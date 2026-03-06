---
name: experiment-log
description: >
  Registra experimentos científicos con hipótesis, métodos y resultados.
  Permite crear, ejecutar, documentar y comparar experimentos con trazabilidad completa.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /experiment-log {proyecto} {subcommand} {args}

## Subcomandos

- `create {titulo}` — Crea plantilla de experimento con ID único (EXP-NNN)
- `run {exp-id} {parametros-json}` — Registra una ejecución con parámetros
- `result {exp-id} {run-id} {resultado-json}` — Añade resultados a una ejecución
- `compare {exp-id-1} {exp-id-2}` — Compara resultados entre experimentos

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/experiments/` si no existe
3. Obtener último número EXP:
   ```bash
   ls projects/$1/experiments/EXP-*.md 2>/dev/null | sort -t'-' -k2 -n | tail -1 | grep -oP 'EXP-\K[0-9]+'
   ```

## Ejecución

1. 🏁 Banner: `══ /experiment-log — {proyecto}/{subcommand} ══`
2. **create**: Crear JSON con: hipótesis, método, variables (independientes, dependientes), control
3. **run**: Registra fecha, usuario, parámetros en array de runs con ID único (RUN-MM-DD-HH)
4. **result**: Buscar run por ID, añadir datos de resultado, calcular estadísticas básicas
5. **compare**: Cargar dos experimentos, generar tabla comparativa con deltas
6. Escribir agent-note: `projects/{proyecto}/agent-notes/experiment-{exp-id}-{accion}.md`
7. ✅ Banner fin con ruta del archivo

## Output

```
projects/{proyecto}/experiments/EXP-{NNN}-{titulo-slug}.md
projects/{proyecto}/experiments/EXP-{NNN}-runs.json
```

## Reglas

- Cada experimento almacena: título, hipótesis, método, variables, runs[]
- Runs son inmutables — nuevos resultados = nuevo run
- Variables deben documentar: nombre, tipo (continuo/discreto), rango/valores
- Compare genera gráficos ASCII con diferencias significativas resaltadas
- Validar que parámetros en run respeten las variables definidas
