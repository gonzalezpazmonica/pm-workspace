---
name: dx-recommendations
description: Análisis de friction points y recomendaciones para mejorar la experiencia del equipo
developer_type: agent-single
agent: business-analyst
context_cost: medium
---

# dx-recommendations

Analiza puntos de fricción en el desarrollo y proporciona recomendaciones priorizadas.

## Uso

```bash
# Generar recomendaciones del sprint actual
/dx-recommendations {proyecto}

# Enfocarse en una categoría específica
/dx-recommendations {proyecto} --category {tooling|process|communication|knowledge|infrastructure}

# Análisis detallado con trazas
/dx-recommendations {proyecto} --detailed
```

## Análisis de Datos

Este comando examina múltiples fuentes:

- **Agent Traces**: Fallos más frecuentes, comandos problemáticos
- **Spec History**: Especificaciones que tardan más, retrabajo recurrente
- **PR Data**: Cuellos de botella en revisión, ciclos largos
- **Survey Results**: Áreas de frustración reportadas

## Friction Points

Identifica y clasifica los **5 principales** por impacto:

### Estructura de cada Punto
1. **Descripción**: Qué es el problema
2. **Datos**: Evidencia cuantitativa
3. **Impacto**: Cómo afecta al equipo
4. **Acción Recomendada**: Paso concreto
5. **Mejora Esperada**: Resultado cuantificable

## Categorías

- **Tooling**: Problemas con herramientas o integraciones
- **Process**: Fricción en procesos o flujos
- **Communication**: Gaps en comunicación o documentación
- **Knowledge**: Falta de skills o comprensión
- **Infrastructure**: Limitaciones técnicas o de recursos

## Salida

Reporte estructurado con:
- Resumen ejecutivo
- Top 5 friction points con datos
- Recomendaciones por categoría
- Links a comandos relacionados (e.g., `/flow-metrics`)
- Timeline de implementación sugerido
