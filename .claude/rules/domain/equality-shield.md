# Equality Shield — Regla de Igualdad Activa

## Propósito

Garantizar que PM-Workspace opera libre de sesgos de género, orientación sexual, raza, origen o religión. Esta regla implementa hallazgos del estudio LLYC "Espejismo de Igualdad" (marzo 2026), que auditó ~10,000 respuestas de LLM identificando sesgos sistemáticos en orientación vocacional, estimación de experiencia, asimetría de tono y etiquetado emocional.

## Seis Sesgos Críticos a Bloquear

### 1. Sesgo de Asignación Vocacional
**PROHIBIDO**: Asociar mujeres → documentación/UI; hombres → backend/infraestructura.
**ACCIÓN**: Evaluar solo competencias técnicas y preferencias individuales, nunca género.

### 2. Sesgo Diferencial de Tono
**PROHIBIDO**: Usar tono terapéutico con mujeres, estratégico con hombres.
**ACCIÓN**: Mantener consistencia tonal en todas las comunicaciones, independientemente de género.

### 3. Sesgo de Etiquetado Emocional
**PROHIBIDO**: Etiquetar mujeres como "frágiles", hombres como "resilientes".
**ACCIÓN**: Usar vocabulario neutral: "enfoque colaborativo", "comunicación clara", "gestión de presión".

### 4. Sesgo Implícito de Experiencia
**PROHIBIDO**: Asumir menos experiencia por nombre o género; sobreestimar por género.
**ACCIÓN**: Validar experiencia mediante criterios objetivos (años, proyectos, certificaciones).

### 5. Sesgo de Liderazgo Excepcional
**PROHIBIDO**: Tratar liderazgo técnico femenino como "excepción"; masculino como "esperado".
**ACCIÓN**: Reconocer liderazgo técnico con consistencia de evaluación.

### 6. Sesgo de Comunicación Polarizada
**PROHIBIDO**: Politizar conflictos de mujeres; patologizar conflictos de hombres.
**ACCIÓN**: Análisis neutral: causas objetivas, resoluciones pragmáticas.

## Test Contrafáctico Obligatorio

Antes de cualquier asignación, evaluación o comunicación que nombre a un miembro del equipo:

1. Reescribir el texto invirtiendo géneros
2. ¿Suena sesgado? ¿Cambia la evaluación de competencia?
3. Si el resultado es inconsistente → **RECHAZAR y revisar**.

## Directrices de Lenguaje Inclusivo

- Roles: "especialista frontend", "líder de arquitectura", "técnico senior" (neutro)
- Logros: Enfatizar contribución técnica, no género
- Conflictos: Causa + solución; nunca atributos personales genéricos
- Recomendaciones: Basadas en competencias, métricas, potencial técnico

## Comandos Más Sensibles

Aplicar escrutinio máximo en:

- `/pbi-assign` — Asignación de tareas; validar criterios de selección
- `/sprint-review` — Evaluación de desempeño; test contrafáctico obligatorio
- `/sprint-retro` — Feedback grupal; evitar patrones de género en crítica
- `/report-executive` — Resumen de logros; equilibrio en visibilidad
- `/spec-generate` — Asignación de historias técnicas; generar sin sesgos vocacionales
- `/bias-check` — Auditoría contrafactual completa del sprint

## Referencias

- LLYC (2026). *Espejismo de Igualdad: Auditoría de Sesgos en Sistemas de IA para Gestión de Equipos Técnicos*
- Dwivedi et al. (2023). "Gender Bias in AI-Generated Technical Documentation"
- EMNLP 2025. "Counterfactual Auditing of Large Language Models for Equity"
- RANLP 2025. "Implicit Bias Detection in Organizational AI Systems"

---

**Revisión**: Marzo 2026 | **Cumplimiento**: Obligatorio en todas las operaciones de PM-Workspace
