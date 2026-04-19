---
id: SPEC-041
title: SPEC-041: Brain-Inspired Context Reasoning Engine
status: ACCEPTED
origin_date: "2026-03-24"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-041: Brain-Inspired Context Reasoning Engine

> Status: **APPROVED** · Fecha: 2026-03-24 · Score: 5.0
> Origen: la usuaria — "simular el cerebro humano para seleccionar contexto pre-LLM"
> Impacto: El LLM recibe contexto optimo, su output mejora proporcionalmente

---

## Problema

El LLM es tan bueno como el contexto que recibe. Hoy cargamos contexto
por dominio y frescura — pero no razonamos sobre si ese contexto es
UTIL para la tarea concreta, si se CONTRADICE entre si, o si hay algo
CRITICO que debe estar siempre presente.

El cerebro humano tiene mecanismos especificos para esto. Vamos a copiarlos.

## 4 Mecanismos Cerebrales

### 1. Working Memory Gate (Cortex Prefrontal)

El cerebro no carga todo lo relevante en memoria de trabajo — solo lo
que necesita para la tarea actual. Tiene ~7 slots (Miller, 1956).

**Implementacion:** Dado un prompt, clasificar las memorias primed en:
- MUST: sin esto el LLM no puede responder (maximo 3)
- USEFUL: mejora la respuesta pero no es imprescindible (maximo 4)
- NOISE: relevante por keywords pero no para ESTA tarea (excluir)

**Criterio de exclusion (NOISE):** si la memoria no cambiaria la
respuesta del LLM, no la cargues. Ejemplo: "Usamos PostgreSQL" es
irrelevante cuando preguntan sobre sprint velocity.

### 2. Contradiction Detection (Hipocampo)

El hipocampo detecta cuando dos recuerdos se contradicen. Si cargas
"usamos JWT" y "migramos a OAuth2" sin indicar cual es vigente, el
LLM puede generar respuestas inconsistentes.

**Implementacion:** Antes de enviar contexto, buscar pares donde:
- Mismo topic_key con diferentes rev (superseded no filtrado)
- Mismo dominio con afirmaciones opuestas (keyword: "no usar X" + "usar X")
- Conflicto temporal (decision A vigente + decision B vigente sobre mismo tema)

Si se detecta contradiccion: incluir SOLO la mas reciente + nota "[supersedes anterior]".

### 3. Priority Tagging (Amigdala)

La amigdala marca recuerdos con carga emocional alta — peligro, dolor,
urgencia. Estos recuerdos siempre se recuperan primero, sin importar
la frescura.

**Implementacion:** Ciertos tipos de memoria tienen prioridad absoluta:
- `type: bug` con severity critical → siempre presente si dominio coincide
- `type: correction` (feedback del usuario) → siempre presente
- Memorias con `rev >= 3` → decision cambiada muchas veces = importante
- Memorias con keyword "NUNCA" o "SIEMPRE" → reglas inmutables

### 4. Attention Focus (Cortex Parietal)

El cerebro ajusta el "zoom" de atencion segun la tarea. Tarea detallada
= zoom estrecho (pocos items, mucho detalle). Tarea amplia = zoom ancho
(muchos items, poco detalle).

**Implementacion:** Detectar tipo de tarea desde el prompt:
- Pregunta especifica ("como conecto a PostgreSQL") → zoom estrecho: 2-3 memorias con detalle
- Pregunta amplia ("que decidimos este sprint") → zoom ancho: 5-7 memorias con titulo
- Comando de analisis ("/sprint-status") → zoom medio: 4-5 memorias con resumen

## Formula del Context Reasoning Score

```
gate_score = (task_relevance × 0.35) + (contradiction_free × 0.20)
           + (priority_tag × 0.25) + (attention_fit × 0.20)

task_relevance: 1.0 si MUST, 0.5 si USEFUL, 0.0 si NOISE
contradiction_free: 1.0 si no conflicto, 0.3 si conflicto detectado
priority_tag: 1.0 si critico/correccion, 0.5 si rev>=3, 0.3 normal
attention_fit: 1.0 si zoom coincide, 0.5 si no coincide
```

Solo se envia al LLM contexto con gate_score > 0.50.

## Principio inmutable

Todo este razonamiento es pre-LLM, sin llamadas a API, puro aritmetica
sobre ficheros .md y JSONL. Los ficheros siguen siendo la fuente de verdad.
