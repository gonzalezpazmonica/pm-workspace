---
globs: [".claude/hooks/agent-trace-log.sh"]
---

# Patrones de Observabilidad de Agentes — Inspirado en claude-code-templates Analytics

## Propósito
Mejorar el sistema existente de agent-trace mediante patrones observados en el analytics dashboard de claude-code-templates, proporcionando una base para evolucionar hacia observabilidad en tiempo real.

## Sistemas Existentes
- Hook: `agent-trace-log.sh`
- Directorio de trazas: `/agent-trace`
- Comandos: `/agent-cost`, `/agent-efficiency`

Estos componentes permanecen intactos; los nuevos patrones son complementarios.

## Patrones a Adoptar

### 1. Detección de Estado en Tiempo Real
Rastrear estados del agente como en su `StateCalculator`:
- **idle**: Esperando entrada del usuario
- **thinking**: Analizando contexto/planeando
- **tool_use**: Ejecutando bash, búsqueda, lectura de archivos
- **writing**: Generando respuesta/editando código

Registrar transiciones de estado con timestamp para análisis de patrones de ejecución.

### 2. Caché Multi-nivel
Implementar caché según niveles como su arquitectura:
- **session**: Metadatos persistentes de sesión
- **conversation**: Resultados entre mensajes del usuario
- **file**: Respuestas de lectura/análisis de archivos

Reduce llamadas redundantes y mejora latencia.

### 3. Actualizaciones WebSocket en Vivo
Patrón preparatorio para dashboard en tiempo real (como su chat monitor):
- Estructura de eventos listos para consumo de WebSocket
- Estados serializables del agente
- Métricas de rendimiento buffereadas por evento

No requerido hoy, pero arquitectura preparada para `/kpi-dashboard` futuro.

### 4. Monitoreo de Rendimiento del Sistema
Capturar métricas de salud durante ejecución:
- Uso de memoria durante operaciones de agente
- Latencia de herramientas (bash, búsqueda, archivo I/O)
- Tasa de éxito/fracaso de operaciones
- Duración de transiciones de estado

## Enfoque de Implementación
- **No reemplaza**: Los datos de agent-trace existentes permanecen como fuente de verdad
- **Enriquecimiento**: Nuevos patrones aumentan contexto sin modificar formatos actuales
- **Gradual**: Adoptar patrones según infraestructura lo permite
- **Retrocompatible**: Cambios no impactan `/agent-cost` ni `/agent-efficiency`

## Punto de Integración Futuro
Cuando `/kpi-dashboard` evolucione a actualizaciones en tiempo real:
- Usar estructura WebSocket preparada de Patrón 3
- Consumir estados/métricas de Patrones 1 y 4
- Aplicar lógica de caché (Patrón 2) para eficiencia
- Mantener retrocompatibilidad con análisis histórico

## Fuente de Referencia
Arquitectura de dashboard analytics: https://github.com/davila7/claude-code-templates
