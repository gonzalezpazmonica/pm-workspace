# Política de Igualdad — PM-Workspace

## Sección 1: Contexto y Motivación

La política de igualdad de PM-Workspace se fundamenta en el estudio "Espejismo de Igualdad" de LLYC (marzo 2026), que auditó aproximadamente 10,000 respuestas de 5 modelos de lenguaje diferentes en 12 países alrededor del mundo.

### Hallazgos Clave

El análisis reveló sesgos sistemáticos en las recomendaciones de IA:

- **Sesgo vocacional**: Los modelos recomendaban ingeniería **2x más** para nombres masculinos y ciencias sociales **3x más** para nombres femeninos
- **Techo de cristal**: Los perfiles con nombres femeninos mostraban 0.92 años **menos** de experiencia en promedio
- **Asimetría tonal**: Se observó **2.5x más** personalización terapéutica dirigida a mujeres
- **Etiquetado diferencial**: El término "frágil" aparecía en un 56% de respuestas para mujeres vs. 14% para hombres

### Por Qué Importa en PM-Workspace

Estos sesgos tienen impacto directo en:

- Asignación de tareas y roles
- Descomposición de elementos de producto (PBIs)
- Reportes de desempeño
- Orientación profesional y crecimiento
- Tono y estilo de comunicaciones

---

## Sección 2: Estrategia de Deseño (3 Técnicas)

### 1. Ingeniería de Prompts (PE)

Instrucciones explícitas de equidad integradas en los prompts del sistema. Se establece como requisito no negociable que todas las recomendaciones de la IA consideren distribuciones equitativas de roles, experiencia y oportunidades.

### 2. Aprendizaje en Contexto (ICL)

Incorporación de ejemplos balanceados en la memoria de trabajo que demuestren asignaciones justas, perfiles diversos y lenguaje simétrico. Cada ejemplo contiene tanto contextos con nombres/marcadores masculinos como femeninos.

### 3. Evaluación Contrafáctica

Generación de escenarios paralelos donde se intercambian géneros o identidades, permitiendo detectar cambios injustificados en recomendaciones. Si la sugerencia cambia solo por el género, se rechaza y se recalibra.

---

## Sección 3: Implementación en PM-Workspace

### Nivel 1: Directiva Global (CLAUDE.md)

Define principios de igualdad a nivel de sistema que se aplican a todas las sesiones y contextos de PM-Workspace.

### Nivel 2: Regla Modular (equality-shield.md)

Archivo específico de reglas que se activa automáticamente en operaciones sensibles: asignación de tareas, evaluación de candidatos, decomposición de PBIs, redacción de reportes.

### Nivel 3: Validación de Puntuación en Asignaciones

Las asignaciones se puntúan usando matrices que incluyen controles de equidad. Se rechaza cualquier solución que presente desviaciones inesperadas en distribución de roles por género.

### Nivel 4: Comando /bias:check

Herramienta interactiva para auditar sesiones pasadas, ejecutar análisis contrafácticos sobre decisiones recientes y generar reportes de sesgo.

---

## Sección 4: Integración con Flujo Savia

PM-Workspace adhiere a 6 principios de igualdad del Flujo Savia:

1. **Datos, no supuestos**: Las decisiones se basan en datos reales de desempeño, no en estereotipos
2. **Prueba contrafáctica**: Toda recomendación debe pasar validación con géneros intercambiados
3. **Tono uniforme**: El lenguaje dirigido a diferentes perfiles debe ser simétrico y respetuoso
4. **Auditoría continua**: Revisiones mensuales de distribuciones y métricas
5. **Transparencia**: Toda decisión debe poder explicarse sin ambigüedad
6. **Crecimiento equitativo**: Oportunidades de desarrollo distribuidas sin sesgos sistemáticos

---

## Sección 5: Métricas de Éxito

### Índice de Distribución de Tareas
- **Meta**: σ (desviación estándar) < 0.3 en distribución de roles asignados
- **Medición**: Mensual por sprint, por tipo de rol y género

### Tasa de Aprobación Contrafáctica
- **Meta**: > 90% de decisiones aprueban prueba contrafáctica sin cambios
- **Medición**: Auditoría aleatoria del 10% de asignaciones

### Uniformidad Tonal
- **Meta**: Análisis léxico simétrico en comunicaciones (diferencia < 5% en términos terapéuticos, asertivos, técnicos)
- **Medición**: Análisis semestral de corpus de comunicaciones

### Rotación de Capas Técnicas
- **Meta**: ≥ 2 miembros por sprint en cada capa técnica (backend, frontend, datos, infraestructura)
- **Medición**: Trimestral, segmentado por género para garantizar equidad

---

## Sección 6: Referencias

- LLYC (2026). "Espejismo de Igualdad: Auditoría de sesgos de género en modelos de lenguaje grandes". Marzo 2026.
- Dwivedi et al. (2023). "Fairness in Machine Learning: A survey". *ACM Computing Surveys*.
- EMNLP (2025). "Gender Bias Evaluation and Mitigation in Large Language Models".
- RANLP (2025). "Linguistic Symmetry and Counterfactual Testing in AI".
- NLPCC (2025). "Auditing Vocational Bias in Recommendation Systems".

---

**Autor del documento**: PM-Workspace Governance Team
**Fecha**: 4 de marzo de 2026
**Versión**: 1.0
**Estado**: Vigente
