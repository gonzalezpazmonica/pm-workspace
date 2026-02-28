---
name: ai-risk-assessment
description: Evaluación de riesgo de agentes según categorías EU AI Act
developer_type: agent-single
agent: security-guardian
context_cost: medium
---

# AI Risk Assessment Command

## Propósito
Ejecuta evaluación sistemática de riesgo de cada agente del proyecto según las categorías regulatorias de la Ley de IA de la UE (EU AI Act).

## Marco Regulatorio

### Categorías de Riesgo EU AI Act

**Prohibidas** (Art. 5):
- Manipulación psicológica o explotación
- Sistemas de puntuación social o crediticia
- Identificación biométrica en tiempo real (excepto casos específicos)
- *Esperado en pm-workspace*: NINGUNO

**Alto Riesgo** (Art. 6):
- Componentes de seguridad crítica (control de máquinas, vehículos)
- Decisiones en empleo, educación, acceso a servicios esenciales
- Determinación de solvencia crediticia o antecedentes penales
- *Esperado en pm-workspace*: BAJO (sin decisiones finales)

**Riesgo Limitado** (Art. 52):
- Interacción con humanos (chatbots, asistentes)
- Generación de contenido deepfake
- *Aplica a*: asistentes de PM y generadores de código

**Riesgo Mínimo**:
- Filtros de spam, recomendadores de juegos
- *Aplica a*: análisis de datos históricos, informes

## Evaluación de Agentes pm-workspace

### Metodología
1. **Clasificar cada agente** según su función principal
2. **Identificar datos procesados** y su sensibilidad
3. **Analizar decisiones tomadas**: ¿autónomas o asistidas?
4. **Evaluar contexto de proyecto**: ¿los proyectos gestionados son sensibles?
5. **Asignar nivel de riesgo** y medidas mitigadoras

### Casos de Uso Esperados
- PM assistance (recomendaciones de tareas, estimación)
- Code generation (agentes de desarrollo)
- Data analysis (métricas, reportes)

**Clasificación esperada**: LIMITADO o MÍNIMO

### Flags de Alto Riesgo
El comando levanta bandera si detecta:
- Agentes que toman decisiones de contratación/despido
- Acceso a datos biométricos o personales sensibles
- Sistemas de puntuación de empleados
- Decisiones sobre acceso a crédito o servicios esenciales

## Salida del Comando

Archivo: `projects/{proyecto}/compliance/risk-assessment-{YYYY-MM-DD}.md`

Contenido:
1. **Matriz de Riesgo**: tabla con clasificación de cada agente
2. **Justificación por Agente**: análisis de riesgo individual
3. **Medidas Requeridas**: por nivel de riesgo
4. **Recomendaciones**:
   - Transparencia (información sobre uso de IA)
   - Supervisión humana (puntos de revisión)
   - Documentación técnica (model cards, pruebas)
5. **Estado General**: conformidad/no conformidad

## Opciones de Ejecución
```bash
claude ai-risk-assessment [--proyecto {nombre}] [--detallado] [--exportar-csv]
```

## Cumplimiento
- Requisito de Art. 9 (gestión de riesgos)
- Base para determinar obligaciones regulatorias
- Actualización recomendada semestralmente o ante cambios de agentes
