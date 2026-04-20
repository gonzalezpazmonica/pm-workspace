---
id: SPEC-SE-030
title: SPEC-SE-030: Skill Self-Improvement Pipeline
status: PROPOSED
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-SE-030: Skill Self-Improvement Pipeline

> **Estado**: Draft
> **Prioridad**: P2 (Productividad)
> **Dependencias**: skill-lifecycle.md (existente), instincts-protocol.md
> **Era**: 231
> **Inspiración**: Hermes Agent auto-skill creation

---

## Problema

pm-workspace tiene 85+ skills pero el ciclo de mejora es manual:
alguien detecta un patrón, propone un skill, lo revisa, lo adopta.
No hay mecanismo para que el workspace aprenda automáticamente de
tareas repetidas y proponga skills nuevos o mejore los existentes.

Hermes Agent crea skills automáticamente cuando detecta tareas
complejas que podrían reutilizarse. pm-workspace debería hacer lo
mismo, respetando la supervisión humana (Rule #5: el humano decide).

## Solución

Pipeline de 3 fases: detección de patrones → propuesta de skill →
refinamiento iterativo. Todo como propuesta pendiente de aprobación
humana, nunca automático.

## Algoritmo de detección

### Trigger: secuencia de acciones repetida

```
Si en las últimas 20 sesiones:
  - La misma secuencia de 3+ comandos aparece 3+ veces
  - Con el mismo tipo de input/output
  - En contextos similares (mismo proyecto, mismo rol)
→ Proponer skill que encapsula la secuencia
```

### Fuentes de datos

1. `data/skill-invocations.jsonl` — invocaciones de skills existentes
2. `data/confidence-log.jsonl` — resoluciones NL exitosas
3. Agent trace logs — secuencias de herramientas usadas
4. Session summaries — patrones de trabajo detectados

## Fases

### Fase 1 — Detección (`scripts/skill-detect.sh`)

Analiza logs de invocaciones y detecta:
- Secuencias repetidas de comandos
- Patrones de resolución NL que se repiten
- Flujos de trabajo que siempre siguen el mismo orden
- Skills existentes que siempre se usan juntos

Output: `output/skill-proposals/YYYYMMDD-proposals.json`

### Fase 2 — Propuesta (`scripts/skill-propose.sh`)

Genera scaffold de skill basado en patrón detectado:
- SKILL.md con frontmatter, descripción, flujo
- DOMAIN.md (Clara Philosophy)
- Test skeleton
- Confianza inicial: 50%

El PM revisa y aprueba/rechaza. Si aprueba → maturity: experimental.

### Fase 3 — Refinamiento iterativo

Skills en maturity `experimental` o `beta` se refinan:
- Tras cada uso: registrar resultado (éxito/fallo)
- Si 3+ fallos consecutivos: sugerir modificación
- Si 10+ usos exitosos: promover a `beta`
- Si rating > 70% tras 50 usos: promover a `stable`
- Refinamiento: sugerir cambios al SKILL.md basados en patrones
  de uso que difieren del flujo original

## Integración con instincts-protocol.md

Los patrones detectados que son demasiado pequeños para un skill
se registran como instintos (confianza, decay, categorías).
Los instintos que alcanzan confianza > 80% son candidatos a skill.

## Implementación

### Script: `scripts/skill-detect.sh`

```
Subcomandos:
  scan     — Analizar logs y detectar patrones
  propose  — Generar propuesta de skill
  refine   — Sugerir mejoras a skill existente
  status   — Mostrar propuestas pendientes
```

### Almacenamiento

```
output/skill-proposals/          ← propuestas generadas
data/skill-invocations.jsonl     ← tracking de uso (existente)
data/skill-refinements.jsonl     ← historial de refinamientos
```

## Tests BATS (mínimo 8)

1. Script existe y es ejecutable
2. Scan sin datos no crashea
3. Scan con datos sintéticos detecta patrón repetido
4. Propose genera scaffold válido con SKILL.md + DOMAIN.md
5. Propose respeta límite de 150 líneas
6. Status sin propuestas muestra mensaje limpio
7. Refine sugiere cambio basado en uso real
8. Propuesta incluye confianza inicial de 50%

## Prohibido

```
NUNCA → Crear skill sin propuesta visible al PM
NUNCA → Promover skill sin datos de uso reales
NUNCA → Modificar skill existente sin aprobación
NUNCA → Usar datos de un proyecto para proponer skills genéricos
```
