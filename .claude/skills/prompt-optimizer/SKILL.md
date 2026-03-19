---
name: prompt-optimizer
description: >
  Bucle auto-optimizador de prompts para skills y agentes — patron AutoResearch.
  Ejecuta skill con test fixture, puntua output contra checklist, modifica prompt,
  re-ejecuta y compara scores. Guarda cambio si mejora, revierte si empeora.
  Criterio de parada: score >= 8/10 en 3 iteraciones consecutivas.
maturity: beta
category: "quality"
tags: ["optimization", "autoresearch", "prompt-engineering", "self-improvement"]
priority: "high"
disable-model-invocation: false
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Task]
---

# Skill: Prompt Optimizer (patron AutoResearch)

> Inspirado en: AutoResearch Loop (Eric Risco / Karpathy)
> "Si los prompts son codigo, necesitan un compilador que los optimice."

## Cuando usar

- Tras crear un skill o agente nuevo, para afinar su prompt
- Cuando un skill produce outputs inconsistentes o de baja calidad
- Para calibrar agentes de digestion contra documentos reales
- Periodicamente: re-optimizar skills con mas uso

## Que necesita

### 1. Target (skill o agente a optimizar)

```
.claude/skills/{nombre}/SKILL.md    → skill
.claude/agents/{nombre}.md          → agente
```

### 2. Test fixture (input + checklist)

Fichero en `.claude/skills/{nombre}/test-fixtures/` o `.claude/agents/test-fixtures/{nombre}/`:

```yaml
# test-fixture.yaml
name: "fixture-basic"
input: |
  [El input que normalmente le pasarias al skill/agente.
   Para digest agents: ruta a un documento real.
   Para spec-writer: descripcion de una task real.
   Para NL resolver: frase en lenguaje natural.]
checklist:
  - id: CHK-01
    criterion: "Extrae todas las entidades mencionadas"
    weight: 2
  - id: CHK-02
    criterion: "Resuelve ambiguedades con contexto del proyecto"
    weight: 2
  - id: CHK-03
    criterion: "Output dentro de 150 lineas"
    weight: 1
  - id: CHK-04
    criterion: "Formato correcto segun template"
    weight: 1
  - id: CHK-05
    criterion: "No inventa datos no presentes en el input"
    weight: 3
context:
  project: "trazabios"  # opcional: proyecto para cargar contexto
```

Si no existe fixture: el comando lo crea interactivamente.

### 3. Scorer (G-Eval adaptado)

Cada item del checklist se puntua 0-10. Score global = media ponderada por weight.

## Flujo del bucle

```
/skill-optimize {skill|agent} [--fixture {nombre}] [--max-iterations 10]
    |
    v
1. Cargar target (SKILL.md o agent.md)
2. Cargar test fixture (input + checklist)
3. Guardar copia original: {target}.backup
    |
    v
4. LOOP (max N iteraciones):
   |
   a. Ejecutar skill/agente con input del fixture
   b. Puntuar output contra checklist (G-Eval 0-10 por item)
   c. Calcular score global (media ponderada)
   d. Registrar en optimization-log.jsonl
   |
   Si score >= 8.0:
     consecutive_passes += 1
     Si consecutive_passes >= 3 → PARAR (exito)
   Si score < 8.0:
     consecutive_passes = 0
   |
   e. Analizar que items puntuan bajo
   f. Proponer cambio especifico al prompt
   g. Aplicar cambio al target
   h. Re-ejecutar con mismo input
   i. Comparar score nuevo vs anterior:
      - Subio → guardar cambio, siguiente iteracion
      - Bajo → revertir cambio, intentar cambio diferente
   |
   Si max_iterations alcanzado → PARAR (timeout)
```

## Tipos de cambio que puede hacer

Cambios permitidos al prompt del skill/agente:

- Reordenar instrucciones (priorizar lo que falla)
- Añadir ejemplos concretos (few-shot para items bajos)
- Hacer explicitas restricciones implicitas
- Simplificar instrucciones redundantes
- Añadir paso de verificacion para items que fallan

Cambios PROHIBIDOS:

- Cambiar el nombre o description del frontmatter
- Cambiar tools, model o permissionMode
- Eliminar reglas de seguridad o confidencialidad
- Añadir dependencias externas no presentes

## Output

### Fichero optimizado

```
.claude/skills/{nombre}/SKILL.optimized.md     → skill
.claude/agents/{nombre}.optimized.md            → agente
```

El original NO se modifica. El PM decide si adoptar la version optimizada.

### Log de optimizacion

```
output/prompt-optimizer/{nombre}-{timestamp}.jsonl
```

Cada linea:
```json
{
  "iteration": 3,
  "score": 7.8,
  "scores_by_item": {"CHK-01": 9, "CHK-02": 6, "CHK-03": 10},
  "change_applied": "Added explicit example for entity extraction",
  "change_kept": true,
  "timestamp": "2026-03-19T01:30:00Z"
}
```

### Resumen en chat

```
Prompt Optimizer: {nombre}
  Iteraciones: 7
  Score inicial: 5.2/10
  Score final: 8.4/10
  Items mejorados: CHK-02 (3→8), CHK-05 (4→9)
  Cambios aplicados: 4 de 7 intentos
  Output: .claude/skills/{nombre}/SKILL.optimized.md
  Log: output/prompt-optimizer/{nombre}-20260319.jsonl
```

## Restricciones

```
NUNCA → Modificar el fichero original (solo crear .optimized.md)
NUNCA → Eliminar reglas de seguridad del prompt
NUNCA → Cambiar frontmatter (name, tools, model)
NUNCA → Ejecutar mas de 10 iteraciones por defecto
SIEMPRE → Guardar backup antes de empezar
SIEMPRE → Registrar cada iteracion en el log
SIEMPRE → Mostrar progreso al PM entre iteraciones
```
