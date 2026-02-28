---
name: ai-audit-log
description: Log de auditoría IA — quién ejecutó qué agente, sobre qué datos, cuándo
developer_type: agent-single
agent: azure-devops-operator
context_cost: low
---

# AI Audit Log Generator

## Propósito
Genera un registro de auditoría exhaustivo de todas las ejecuciones de agentes IA, incluyendo usuario, contexto de ejecución, datos procesados, acciones tomadas y resultados.

## Funcionalidad

### 1. Lectura de Trazas de Agentes
- Lee archivos de traza desde: `projects/{proyecto}/traces/`
- Extrae: timestamp, agente ejecutado, parámetros, duración
- Enriquece con metadatos del proyecto

### 2. Información de Ejecución
- **Usuario**: quién disparó la ejecución (desde información de sesión)
- **Agente**: nombre e identificador único
- **Acción**: descripción de lo que hizo el agente
- **Alcance de datos**: qué datos fueron accedidos/modificados
- **Resultado**: éxito/error, salida generada
- **Duración**: tiempo de ejecución en segundos

### 3. Entradas del Log
Cada entrada contiene:
```
[YYYY-MM-DD HH:MM:SS] | Usuario: {user} | Agente: {agente} |
Acción: {descripción} | Datos: {alcance} | Resultado: {status} | Duración: {ms}
```

### 4. Filtrado y Consultas
```bash
claude ai-audit-log --proyecto {nombre} \
  [--from {YYYY-MM-DD}] \
  [--to {YYYY-MM-DD}] \
  [--agent {nombre}] \
  [--user {nombre}] \
  [--resultado {success|error}]
```

### 5. Estadísticas Generadas
- Total de invocaciones del proyecto
- Invocaciones por agente (ranking)
- Invocaciones por usuario
- Tasa de éxito/error general y por agente
- Duración promedio de ejecución
- Usuarios más activos
- Agentes más utilizados

### 6. Salida y Formatos

**Archivo principal**: `projects/{proyecto}/compliance/audit-log-{YYYY-MM-DD}.md`

**Formatos disponibles**:
- Markdown (predeterminado, legible)
- CSV (para análisis)
- JSON (para integración)

## Cumplimiento Regulatorio

### Artículo 12 EU AI Act
Sistemas de alto riesgo deben mantener:
- **Registros de entrada y salida**: ¿qué inputs recibió el sistema?
- **Registro de actividades**: ¿qué hizo el sistema?
- **Cambios significativos**: ¿qué versiones se ejecutaron?
- **Acceso y usuario**: ¿quién accedió al sistema?

Este comando documenta todo ello en formato auditable.

### Propósito de Auditoría
- Demostrar conformidad en inspecciones regulatorias
- Investigar incidentes o comportamientos inesperados
- Analizar patrones de uso de IA
- Garantizar trazabilidad de decisiones

## Opciones de Ejecución Completas
```bash
claude ai-audit-log \
  --proyecto {nombre} \
  --from {fecha_inicio} \
  --to {fecha_fin} \
  [--agent {nombre}] \
  [--user {nombre}] \
  [--resultado success|error] \
  [--exportar csv|json] \
  [--incluir-estadisticas] \
  [--detallado]
```

## Notas
- El log es de **solo lectura** (basado en trazas existentes)
- Retención recomendada: mínimo 1 año para sistemas de alto riesgo
- Actualización: continua (cada ejecución de agente se registra)
- Acceso: limitado a personal autorizado de cumplimiento
