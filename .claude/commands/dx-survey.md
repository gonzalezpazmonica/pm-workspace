---
name: dx-survey
description: Genera encuesta DX Core 4 adaptada al equipo y procesa respuestas
developer_type: agent-single
agent: business-analyst
context_cost: medium
---

# dx-survey

Genera una encuesta de Experiencia del Desarrollador basada en el framework DX Core 4, complementada con dimensiones SPACE.

## Uso

```bash
# Generar nueva encuesta
/dx-survey {proyecto}

# Procesar resultados de una encuesta completada
/dx-survey {proyecto} --results {fichero_respuestas}
```

## Descripción

Este comando crea una encuesta estructurada en 4 dimensiones clave de DX Core 4:

- **Speed (Velocidad)**: Rapidez de entrega y ciclos de feedback
- **Effectiveness (Efectividad)**: Logro de objetivos y claridad de requerimientos
- **Quality (Calidad)**: Fiabilidad del código y procesos de testing
- **Impact (Impacto)**: Valor de negocio entregado al usuario

Complementa estas dimensiones con el framework SPACE (Satisfaction, Performance, Activity, Communication, Efficiency).

## Salida

**Sin resultados**: Fichero Markdown con formulario en `projects/{proyecto}/dx/survey-{timestamp}.md`

**Con resultados**: Procesa respuestas y genera:
- Resumen estadístico (medias, desviaciones)
- Comparación con survey anterior (si existe)
- Visualización de tendencias
- Áreas de mejora identificadas

## Formato de Encuesta

- **12-15 preguntas Likert** (escala 1-5)
- **3 preguntas abiertas** para contexto cualitativo
- Anonimato garantizado
- Tiempo estimado: 8-12 minutos

## Estructura del Documento

1. Banner de introducción
2. Contexto y propósito
3. Bloques de preguntas por dimensión
4. Instrucciones de respuesta
5. Banner de cierre y contacto
