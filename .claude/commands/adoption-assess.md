---
name: adoption-assess
description: Evaluar madurez de adopción de IA del equipo usando modelo ADKAR
developer_type: all
agent: task
context_cost: medium
---

# /adoption-assess

> 🦉 Diagnosticar dónde está el equipo en su viaje de adopción de Savia.

Basado en el modelo **ADKAR** (Awareness, Desire, Knowledge, Ability, Reinforcement).

---

## Modelo ADKAR (5 Dimensiones)

1. **Awareness** — ¿El equipo sabe que existe Savia y cómo puede ayudar?
2. **Desire** — ¿Quieren usarla? ¿Ven valor en adoptar IA?
3. **Knowledge** — ¿Saben cómo usar los comandos? ¿Conocen las reglas?
4. **Ability** — ¿Pueden usarla en su flujo diario sin fricción?
5. **Reinforcement** — ¿Se refuerza el hábito? ¿Hay celebraciones de éxito?

---

## Flujo

### Paso 1 — Recopilar datos (encuesta rápida)
- Preguntar al PM sobre cada dimensión ADKAR
- ¿Cómo está el equipo ahora? (1-5 escala)
- Ejemplos de fricción o resistencia
- Equipos que adoptan bien vs. equipos rezagados

### Paso 2 — Scoring
- Cada dimensión: 1 (muy bajo) a 5 (excelente)
- Identificar la dimensión más débil (cuello de botella)
- Calcular score ADKAR global (promedio)

### Paso 3 — Análisis
- ¿Cuál es el principal blocante? Ej: falta Knowledge → necesita capacitación
- ¿Hay "early adopters" que pueden mentorar? Reinforce→ estrategia peer-learning
- ¿Qué comando del team usar primero para ganar rápida victoria?

### Paso 4 — Intervenciones personalizadas
Recomendar acciones específicas por dimensión débil:
- **Awareness baja** → `/adoption-plan --awareness` (crear storytelling de casos de uso)
- **Desire baja** → demo personal con ROI: "Esto te ahorra 1h/día"
- **Knowledge baja** → `/adoption-sandbox --learn` (entorno seguro de práctica)
- **Ability baja** → `/adoption-track --friction` (identificar puntos de dolor)
- **Reinforcement baja** → crear rituales: "Cada viernes, un equipo comparte su victoria con Savia"

### Paso 5 — Propuesta de roadmap
- Secuencia de intervenciones en 4-12 semanas
- Hitos: "Semana 2: 50% equipo usa /sprint-status" → "Semana 6: Primer spec con SDD"
- Métrica de éxito por hito

---

## Output

- Matriz ADKAR con scores actuales
- Gráfico de radar con 5 dimensiones
- Top 3 frenos y acciones recomendadas
- Roadmap personalizado de 8-12 semanas
- Guardar en `output/adoption-assess-YYYYMMDD-{proyecto}.md`

---

## Restricciones

- No asumir que el equipo es resistente — escuchar sin juzgar
- Adaptar lenguaje a rol: DevOps ≠ PM ≠ QA
- NUNCA forzar adopción — motivar y facilitar
