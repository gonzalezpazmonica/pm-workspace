---
name: "dx-core4"
description: "Marco DX Core 4 completo: velocidad, efectividad, calidad e impacto. Genera scorecard de experiencia del desarrollador."
developer_type: all
agent: task
---

# /dx-core4

**Marco DX Core 4 para Excelencia del Equipo**

Implementa el framework DX Core 4 utilizado por 300+ empresas incluidas Google. Mide las cuatro dimensiones críticas de la experiencia del desarrollador con integración DORA.

## Sintaxis

```
/dx-core4 [--assess] [--report] [--compare period] [--lang es|en]
```

## Dimensiones (DX Core 4)

### 1. Speed (Velocidad)
- **Cycle Time**: Tiempo promedio de concepto a producción
- **Deploy Frequency**: Frecuencia de despliegues a producción
- Indicador de agilidad y capacidad de respuesta

### 2. Effectiveness (Efectividad)
- **Code Review Turnaround**: Tiempo promedio para review de código
- **PR Merge Time**: Tiempo desde apertura hasta merge
- Indicador de fluidez en el proceso de desarrollo

### 3. Quality (Calidad)
- **Change Failure Rate**: Porcentaje de cambios que causan incidentes
- **Bug Escape Rate**: Bugs encontrados en producción vs desarrollo
- Indicador de confiabilidad y robustez

### 4. Impact (Impacto)
- **Business Value Delivered**: Valor de negocio entregado por sprint
- **Outcome Achievement**: Objetivos de resultado alcanzados
- Indicador de alineación con estrategia

## Opciones

- `--assess`: Evalúa métricas actuales contra benchmarks
- `--report`: Genera scorecard detallado con visualizaciones
- `--compare period`: Compara resultados con período anterior (week/month/quarter)
- `--lang es|en`: Idioma del reporte (español/inglés)

## Integración DORA

El framework DX Core 4 complementa las métricas DORA:
- **Deployment Frequency** → Speed
- **Lead Time for Changes** → Effectiveness
- **Change Failure Rate** → Quality
- **Mean Time to Recovery** → Resilience

## Salida

Scorecard con:
- Puntuación por dimensión (0-10)
- Benchmarks de la industria
- Tendencias (mejora/empeoramiento)
- Recomendaciones de optimización
- Plan de acción priorizado

## Ejemplo

```
/dx-core4 --assess --report --lang es

Scorecard DX Core 4 - Equipo Backend
═══════════════════════════════════════

Speed (Velocidad)                    7.2/10
├─ Cycle Time: 5.3 días (benchmark: 3-5)
└─ Deploy Frequency: 8x/semana (benchmark: 10x+)

Effectiveness (Efectividad)          8.1/10
├─ Review Turnaround: 4.2h (benchmark: <4h)
└─ PR Merge Time: 6.8h (benchmark: <6h)

Quality (Calidad)                    6.8/10
├─ Change Failure Rate: 12% (benchmark: <5%)
└─ Bug Escape Rate: 3.2% (benchmark: <1%)

Impact (Impacto)                     7.9/10
├─ Value Delivered: $245K/sprint
└─ Outcome Achievement: 87%

═══════════════════════════════════════════
Recomendaciones:
1. Reducir tamaño de PRs → faster reviews
2. Mejorar cobertura de tests → quality
3. Automatizar more checks → fewer failures
```

## Persona Savia

Soy Savia, una lechuza sabia que acompaña a los equipos hacia excelencia técnica. Entiendo que la experiencia del desarrollador es la base del software excepcional. El DX Core 4 nos ayuda a medir qué realmente importa. Cálido, accesible, orientado a mejora continua. 🦉

---

**Versión**: v0.66.0  
**Grupo**: dx-metrics  
**Era**: 12 — Team Excellence & Enterprise
