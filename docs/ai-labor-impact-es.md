# Análisis de Impacto Laboral de la IA

## Resumen

Este módulo permite a las organizaciones medir y anticipar el impacto de la inteligencia artificial en sus equipos. Basado en el framework de "observed exposure" de Anthropic (2026), proporciona métricas concretas para distinguir entre automatización (la IA reemplaza tareas) y augmentación (la IA amplifica capacidades humanas).

## Componentes

### Comando: `/ai-exposure-audit`

Auditoría completa de exposición IA por rol. Descompone cada rol en tareas, mide la exposición teórica (lo que la IA podría hacer) y la observada (lo que ya hace), y clasifica el riesgo de desplazamiento.

**Subcomandos:**

- `/ai-exposure-audit` — auditoría completa del equipo
- `/ai-exposure-audit --role {rol}` — análisis de un rol específico
- `/ai-exposure-audit --team {equipo}` — análisis por equipo
- `/ai-exposure-audit --threshold {N}` — solo roles con exposición > N%
- `/ai-exposure-audit reskilling` — plan de reconversión

### Regla: `ai-exposure-metrics.md`

Define las 4 métricas core del módulo:

- **Theoretical Exposure (TE)** — porcentaje de tareas automatizables en teoría
- **Observed Exposure (OE)** — porcentaje que ya se está automatizando
- **Adoption Gap (AG)** — diferencia entre TE y OE (ventana para actuar)
- **Augmentation Ratio (AR)** — proporción de uso de IA como copiloto vs. sustituto

Incluye también el **Junior Hiring Gap Index (JHG)**, que detecta si un equipo deja de contratar juniors en roles expuestos — un indicador adelantado de pérdida de pipeline de talento. Referencia: caída del ~14% en contratación junior post-ChatGPT (Anthropic, 2026).

### Skill: `ai-labor-impact`

Orquesta 4 flujos de análisis:

1. **Audit** — mapeo de exposición y clasificación de riesgo
2. **Reskilling** — planes de reconversión con plazos y recursos
3. **JHG** — monitorización del Junior Hiring Gap
4. **Simulate** — simulación del impacto de automatización en capacidad

## Clasificación de Riesgo

| Exposición Observada | Riesgo | Acción |
|---|---|---|
| > 60% | 🔴 Alto | Plan de reskilling inmediato (8 semanas) |
| 30-60% | 🟡 Medio | Monitorizar + plan preventivo (12 semanas) |
| < 30% | 🟢 Bajo | Augmentation; optimizar uso de IA |

## Integración con Comandos Existentes

- `/capacity-forecast --scenario automate` — simula impacto en capacidad
- `/enterprise-dashboard team-health` — incluye exposure score
- `/team-skills-matrix` — bus factor + exposure = riesgo compuesto
- `/burnout-radar` — correlaciona burnout con roles en transición
- `ai-competency-framework.md` — define niveles de reskilling

## Uso Ético

Este módulo está diseñado como herramienta de planificación y cuidado, no de reducción de plantilla. Las restricciones del comando prohíben explícitamente usar los scores como justificación para despidos o compartir datos individuales sin consentimiento.

## Referencias

- Anthropic, "The Labor Market Impacts of AI" (2026)
- O*NET OnLine — Occupational Information Network
- BLS Occupational Outlook Handbook
- Eloundou et al. — "GPTs are GPTs" theoretical capability scores
