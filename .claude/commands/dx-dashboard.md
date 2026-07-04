---
name: dx-dashboard
description: Dashboard DX con métricas automatizables de feedback loops, cognitive load y satisfacción
developer_type: agent-single
agent: azure-devops-operator
context_cost: medium
tier: extended
---

# dx-dashboard

Genera un dashboard de métricas DX con indicadores automatizados y datos de encuestas.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Reporting** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar output según `preferences.language`, `preferences.detail_level`, `preferences.report_format` y `tone.formality`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso

```bash
# Dashboard del sprint actual
/dx-dashboard {proyecto}

# Dashboard de un rango de fechas
/dx-dashboard {proyecto} --from YYYY-MM-DD --to YYYY-MM-DD

# Incluir comparativa con sprint anterior
/dx-dashboard {proyecto} --compare
```

## 3. Métricas Automatizadas

No requieren encuesta. Se extraen de datos del workspace:

### Feedback Loops
- **PR Cycle Time**: Tiempo promedio desde creación hasta merge (Azure DevOps)
- **Spec Cycle Time**: Tiempo desde spec-generate hasta spec-verify completion
- **Build Feedback Duration**: Duración del pipeline CI/CD
- **Error Detection Latency**: Tiempo de detección de fallos en producción

### Cognitive Load Proxy
- Archivos promedio por especificación
- Dependencias por tarea
- Complejidad promedio de specs
- Context switches paralelos por desarrollador

### Tool Satisfaction Proxy
- Tasa de éxito de comandos (agent-trace)
- Hit rate en caché de revisión
- Reducción de tiempo con automatización

## Métricas Basadas en Encuesta

Si existen resultados de `/dx-survey`:

- Puntuación de satisfacción general
- Rating de complejidad percibida
- Áreas con mayor fricción

## Indicadores RAG

Cada métrica incluye indicador de estado:
- 🟢 Verde: Dentro de target
- 🟡 Amarillo: Requiere atención
- 🔴 Rojo: Crítico, requiere acción

## Formato de Salida

Dashboard estructurado con:
- Resumen ejecutivo
- Métricas clave con tendencias
- Comparativa vs sprint anterior
- Gráficos de evolución temporal
