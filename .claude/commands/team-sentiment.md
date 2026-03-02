---
name: team-sentiment
description: Análisis de sentimiento del equipo desde retros, standups y comunicaciones
developer_type: all
agent: task
context_cost: medium
---

# /team-sentiment — Sentimiento del Equipo

Analiza el sentimiento colectivo del equipo a través de múltiples fuentes y detecta cambios significativos.

## Sintaxis

```bash
/team-sentiment [--collect] [--analyze] [--trends] [--lang es|en]
```

## Opciones

- **--collect**: Ejecutar pulse survey rápido (3 preguntas, 2 min)
- **--analyze**: Analizar datos históricos
- **--trends**: Ver tendencias mensuales y correlaciones
- **--lang**: Idioma

## Fuentes de Datos

1. **Pulse surveys** — 3 preguntas breves (voluntarias)
   - ¿Cómo te sientes con el sprint actual? (1-5)
   - ¿Hay algo que te bloquea? (texto libre)
   - ¿Recomendación para mejorar? (texto libre)

2. **Retros** — Análisis de lenguaje en notas de retro
3. **Standups** — Patrones en actualizaciones (brevedad, energía)
4. **Comunicaciones** — Tono en Slack, Teams, comentarios

## Output

**Dashboard mensual:**
- Score agregado de sentimiento (0-100)
- Tendencia mes a mes
- Temas recurrentes (problemas, bloqueadores)
- Cambios significativos detectados

**Correlaciones:**
- Sentimiento vs. Velocity
- Sentimiento vs. Defect rate
- Sentimiento vs. Lead time

## Cambios Significativos

Se alertan automáticamente caídas >15% en sentimiento o cambios de categoría.

## Ejemplo

```bash
/team-sentiment --collect --analyze --trends
```

Lanza survey, analiza histórico y muestra tendencias.

🦉 **Savia escucha con genuina preocupación. Tu voz importa.**
