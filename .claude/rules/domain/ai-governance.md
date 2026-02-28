---
paths: ["**/compliance/**", "**/model-card*", "**/risk-assessment*", "**/audit-log*"]
---

# Gobernanza de IA — Reglas de Dominio

## § 1 Principios Fundamentales de Gobernanza IA

Todas las operaciones con agentes y sistemas de IA en pm-workspace se rigen por estos principios:

1. **Transparencia**: Los usuarios y evaluadores pueden entender cómo los agentes toman decisiones
2. **Responsabilidad**: Cada agente tiene un propietario/responsable identificable
3. **Supervisión Humana**: Las decisiones críticas requieren validación o confirmación humana
4. **No Discriminación**: Los agentes no pueden discriminar por características protegidas
5. **Seguridad de Datos**: Los datos procesados se protegen según su sensibilidad

## § 2 Requisitos Regulatorios EU AI Act

### Documentación Técnica (Artículo 11)
- [ ] Model card por agente documentando: propósito, modelo, tareas, limitaciones
- [ ] Arquitectura y flujo de datos del sistema
- [ ] Especificación de requisitos y criterios de evaluación
- [ ] Descripción de datos de entrenamiento (si aplica)
- [ ] Mantenimiento: actualización trimestral o ante cambios

### Gestión de Riesgos (Artículo 9)
- [ ] Evaluación inicial de riesgo (risk assessment)
- [ ] Identificación de riesgos razonablemente previsibles
- [ ] Mitigación: medidas técnicas u organizacionales
- [ ] Evaluación continua: revisión semestral mínimo

### Supervisión Humana (Artículo 14)
- [ ] Puntos de revisión explícitos antes de acciones críticas
- [ ] Capacidad humana para comprender y cuestionar decisiones del agente
- [ ] Derecho a intervenir o anular decisiones del agente
- [ ] Registro de supervisión en audit log

### Registro de Actividades (Artículo 12)
- [ ] Trazas de todas las ejecuciones de agentes
- [ ] Información de usuario, timestamp, acción realizada
- [ ] Datos procesados y alcance de acceso
- [ ] Resultados y cambios realizados
- [ ] Retención: mínimo 1 año

## § 3 Aplicación en pm-workspace v0.29.0

### Inventory de Agentes
Todos los agentes definidos en `.claude/agents/` deben:
- Tener model card documentada (comando `ai-model-card`)
- Estar clasificados por nivel de riesgo (comando `ai-risk-assessment`)
- Tener trazas de ejecución registradas (datos para `ai-audit-log`)

### Tipología de Decisiones

**Decisiones Autónomas** (NO PERMITIDAS sin supervisión):
- Eliminar tareas o sprints
- Cambiar asignación de recursos sin revisión
- Modificar estimaciones críticas sin confirmación

**Decisiones Asistidas** (permitidas con confirmación humana):
- Sugerir estimaciones (PM confirma)
- Recomendar asignaciones (PM revisa y aprueba)
- Generar código (desarrollador revisa y merge)
- Priorizar tareas (PM valida antes de aplicar)

**Decisiones Informativas** (sin requerimiento de supervisión):
- Mostrar métricas históricas
- Generar reportes de análisis
- Listar tareas según filtros
- Sugerir mejoras de proceso (informativo)

### Supervisión Humana Obligatoria
Estos puntos de supervisión deben estar documentados:
- [ ] Quién revisa (rol requerido)
- [ ] Qué se revisa (criterios de evaluación)
- [ ] Cómo se documenta (en audit log)
- [ ] Qué sucede si se rechaza (reversión, escalada)

### Trazabilidad de Datos
- Archivos de traza en: `projects/{proyecto}/traces/`
- Formato: timestamp, usuario, agente, acción, datos, resultado
- Accesibilidad: para auditorías internas y regulatorias

### Revisión de Código Obligatoria
Todo código generado por agentes debe:
- Ser revisado por humano antes de merge
- La revisión constituye punto de supervisión humana
- Documentado en audit log (quién aprobó, cuándo)

## § 4 Checklist de Conformidad

### Por Proyecto (Trimestral)
- [ ] Model card actualizada con agentes actuales
- [ ] Risk assessment revisado
- [ ] Cambios de riesgo identificados y mitigados
- [ ] Supervisión humana funcional y documentada

### Por Agente (Anual)
- [ ] Rendimiento y exactitud evaluados
- [ ] Limitaciones conocidas documentadas
- [ ] Criterios de evaluación especificados
- [ ] Responsable identificable asignado

### Auditoría de Registro (Continuo)
- [ ] Audit log accesible y auditable
- [ ] Queries funcionando correctamente
- [ ] Trazas completas y precisas
- [ ] Retención según regulación (≥1 año)

## § 5 Limitaciones y Alcance

### Qué es pm-workspace
- Herramienta de gestión de proyectos asistida por IA
- Agentes hacen recomendaciones, **humanos toman decisiones**
- Bajo riesgo per se (no toma decisiones autónomas críticas)

### Qué NO es
- Sistema autónomo de toma de decisiones
- Reemplazo de supervisión humana
- Herramienta para decisiones sobre empleo, crédito o discriminación

### Evaluación Caso-a-Caso
Los **proyectos gestionados** por pm-workspace pueden ser de alto riesgo:
- Ejemplo: si pm-workspace gestiona proyecto de sistema médico
- Entonces: ese sistema inherita requisitos de alto riesgo
- Solución: documentar cadena de responsabilidad

### No Cubierto por Esta Regla
- Sistemas externos que usan salida de pm-workspace
- Datos de terceros procesados por proyectos
- Políticas de privacidad de datos específicas por sector

## § 6 Responsabilidades

**Project Owner**: Designar responsable de IA del proyecto
**IA Responsible**: Mantener documentación, coordinar evaluaciones
**Developers**: Implementar supervisión humana en código
**Auditor**: Revisar compliance trimestralmente
**Users**: Ejecutar supervisión humana en puntos asignados

## § 7 Revisión y Actualización

Esta regla se revisa:
- **Anualmente**: alineación con legislación
- **Ante cambios regulatorios**: adaptación inmediata
- **Ante nuevos agentes**: integración de requisitos
- **Ante incidentes**: análisis de raíz y correcciones

Última revisión: 2026-02-28 | Próxima: 2027-02-28
