---
name: headroom-analyze
description: Analizar el uso de tokens por bloque de contexto e identificar oportunidades de compresión
arguments: "$ARGUMENTS = nombre del proyecto"
---

# /headroom-analyze

Analiza el presupuesto de contexto actual de un proyecto e identiza oportunidades de compresión.

## Parámetros

- **Obligatorio:** `{proyecto}` — nombre del proyecto a analizar (ej: `sala-reservas`)
- **Opcional:** `--format csv|json|md` — formato de salida (default: `md`)

## Razonamiento

Paso a paso:
1. Cargar structure del proyecto (rules, docs, skills, CLAUDE.md)
2. Estimar tokens por bloque de contexto
3. Detectar patrones repetidos y redundancias
4. Calcular ahorros potenciales por técnica
5. Generar informe ejecutivo con recomendaciones

## Flujo de ejecución

**Banner:**
```
🔬 /headroom-analyze — Análisis de Contexto
```

**Análisis:**
- Bloques detectados y tokens actuales
- Patrones repetidos
- Oportunidades de compresión por técnica
- Ahorros potenciales (%)
- Recomendaciones ordenadas por impacto

**Output:** Fichero guardado en `output/headroom/YYYYMMDD-analyze-{proyecto}.md` + resumen en chat

**Siguiente paso sugerido:** `/headroom-apply {proyecto}`

