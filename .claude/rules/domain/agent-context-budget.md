---
name: agent-context-budget
description: Protocolo de budget de tokens para subagentes — control de consumo de contexto
auto_load: false
paths: []
---

# Agent Context Budget Protocol

> 🦉 Cada agente tiene un presupuesto. Gastar solo lo necesario.

---

## Principio

Los subagentes no deben consumir contexto sin límite. Cada agente tiene un budget
de tokens asignado según su complejidad y el tipo de output que genera.

## Campos de frontmatter

```yaml
name: performance-analyst
max_context_tokens: 8000    # Máximo de tokens de input al agente
output_max_tokens: 500      # Máximo de tokens del resumen devuelto
```

## Categorías de budget

| Categoría | max_context_tokens | output_max_tokens | Agentes |
|---|---|---|---|
| **Heavy** | 12000 | 1000 | architect, security-guardian, code-reviewer |
| **Standard** | 8000 | 500 | developers (all languages), business-analyst, tester |
| **Light** | 4000 | 300 | commit-guardian, diagram-architect, performance-analyst |
| **Minimal** | 2000 | 200 | azure-devops-operator, infra-deployer |

## Reglas de invocación

Cuando un comando invoca un subagente:

1. **Seleccionar** solo los ficheros target que el agente necesita
2. **Estimar** tokens de los ficheros seleccionados
3. Si tokens_estimados > max_context_tokens → **resumir** o **fragmentar**
4. El agente devuelve su output dentro de output_max_tokens
5. El output del agente se inserta en el contexto del comando invocador

## Estrategias de reducción

Si el input supera el budget:

1. **Priorizar**: Cargar ficheros por relevancia (más relevante primero)
2. **Truncar**: Para ficheros grandes, cargar solo las secciones relevantes
3. **Resumir**: Pedir al agente que trabaje con un resumen en vez del fichero completo
4. **Fragmentar**: Dividir la tarea en subtareas más pequeñas

## Métricas

El context-tracker puede registrar el consumo real de cada agente:

```bash
bash scripts/context-tracker.sh log "agent:architect" "spec.md,domain-model" "6200"
```

Esto permite a `/context-optimize` detectar agentes que consistentemente exceden su budget.

## Evolución

Los budgets se ajustarán con datos empíricos de `/context-optimize`.
Agentes nuevos deben incluir `max_context_tokens`, `output_max_tokens` y `token_budget` en su frontmatter.

## Metering (SPEC-AGENT-METERING)

Cada agente incluye `token_budget: {max_context + output_max}` en frontmatter.
`agent-trace-log.sh` compara uso real vs budget; excesos en `budget-alerts.jsonl`.
Ver con `/agent-cost`.
