---
name: ai-model-card
description: Genera model card documentando agentes IA, modelos, tareas y decisiones
developer_type: agent-single
agent: business-analyst
context_cost: medium
---

# AI Model Card Generator

## Propósito
Genera tarjetas de modelo que documentan exhaustivamente cada agente IA utilizado en el proyecto, incluyendo su arquitectura, capacidades, limitaciones y puntos de supervisión humana.

## Funcionalidad
El comando ejecuta las siguientes operaciones:

### 1. Inventario de Agentes
- Escanea `.claude/agents/` para obtener lista completa de agentes del proyecto
- Para cada agente extrae:
  - Nombre identificador
  - Modelo utilizado (Opus 4.6, Sonnet, Haiku 4.5)
  - Versión y configuración

### 2. Mapeo de Tareas y Datos
- Documentar todas las tareas que cada agente puede ejecutar
- Definir datos de entrada y salida
- Especificar acceso a sistemas (archivos, APIs, bases de datos)
- Señalar puntos de decisión autónoma vs asistida

### 3. Cumplimiento Legal
- Sigue requisitos de Artículo 11 (Documentación técnica) de EU AI Act
- Garantiza trazabilidad de decisiones del sistema
- Documenta limitaciones conocidas y casos de uso no soportados

### 4. Estructura de Salida
Archivo: `projects/{proyecto}/compliance/model-card-{YYYY-MM-DD}.md`

Secciones generadas:
1. **Overview**: resumen ejecutivo, versión del sistema, fecha
2. **Agent Inventory**: tabla de todos los agentes con modelo y rol
3. **Data Access Mapping**: qué datos accede cada agente
4. **Decision Points**: dónde toma decisiones el agente vs requiere confirmación humana
5. **Human Oversight**: mecanismos de supervisión implementados
6. **Limitations**: restricciones conocidas, edge cases no soportados
7. **Contact Information**: responsable del agente, fecha de última revisión

### 5. Estadísticas de Uso
Si existen trazas de agentes en `/agent-trace`:
- Incluye estadísticas: invocaciones totales, por agente
- Duración promedio de ejecución
- Tasa de éxito/error
- Usuarios que han ejecutado cada agente

## Opciones de Ejecución
```bash
claude ai-model-card [--proyecto {nombre}] [--fecha {YYYY-MM-DD}] [--incluir-trazas]
```

## Notas de Cumplimiento
- Salida obligatoria para auditorías de conformidad
- Debe ser accesible a evaluadores externos y autoridades regulatorias
- Actualización recomendada cuando cambien agentes o modelos
