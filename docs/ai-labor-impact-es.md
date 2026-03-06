# Análisis de Impacto Laboral de la IA

## Resumen

pm-workspace incluye un módulo de análisis de impacto laboral que permite a las organizaciones medir y anticipar cómo la inteligencia artificial afecta a sus equipos. Basado en el framework de "observed exposure" de Anthropic (2026), Savia proporciona métricas concretas para distinguir entre automatización (la IA reemplaza tareas) y augmentación (la IA amplifica capacidades humanas), con planes de reskilling integrados.

Compatible con Azure DevOps, Jira y Savia Flow (Git-native).

## Componentes

### Comando: `/ai-exposure-audit`

Auditoría completa de exposición IA por rol. Descompone cada rol en tareas (taxonomía O*NET), mide la exposición teórica (lo que la IA podría hacer) y la observada (lo que ya hace), y clasifica el riesgo de desplazamiento con planes de acción.

**Subcomandos:**

- `/ai-exposure-audit` — auditoría completa del equipo
- `/ai-exposure-audit --role {rol}` — análisis de un rol específico
- `/ai-exposure-audit --team {equipo}` — análisis por equipo
- `/ai-exposure-audit --threshold {N}` — solo roles con exposición > N%
- `/ai-exposure-audit reskilling` — plan de reconversión por rol

Informes generados en `output/analytics/ai-exposure-YYYYMMDD.md`.

### Regla: `ai-exposure-metrics.md`

Define las 4 métricas core y el índice de pipeline de talento:

- **Theoretical Exposure (TE)** — porcentaje de tareas automatizables en teoría
- **Observed Exposure (OE)** — porcentaje que ya se está automatizando
- **Adoption Gap (AG)** — diferencia entre TE y OE (ventana para actuar)
- **Augmentation Ratio (AR)** — proporción de uso de IA como copiloto vs. sustituto

Incluye el **Junior Hiring Gap Index (JHG)**, que detecta si un equipo deja de contratar juniors en roles expuestos — un indicador adelantado de pérdida de pipeline de talento. Referencia: caída del ~14% en contratación junior post-ChatGPT (Anthropic, 2026). El JHG puede alimentarse del directorio de miembros de SaviaHub (`/savia-directory`) para calcular incorporaciones históricas.

### Skill: `ai-labor-impact`

Orquesta 4 flujos de análisis con contexto aislado (subagente):

1. **Audit** — mapeo de exposición y clasificación de riesgo
2. **Reskilling** — planes de reconversión con plazos, recursos y nivel ai-competency-framework
3. **JHG** — monitorización del Junior Hiring Gap con datos de equipo o SaviaHub
4. **Simulate** — simulación del impacto de automatización en capacidad (conecta con `/capacity-forecast`)

## Clasificación de Riesgo

| Exposición Observada | Riesgo | Acción |
|---|---|---|
| > 60% | 🔴 Alto | Plan de reskilling inmediato (8 semanas) |
| 30-60% | 🟡 Medio | Monitorizar + plan preventivo (12 semanas) |
| < 30% | 🟢 Bajo | Augmentation; optimizar uso de IA |

## Integración con pm-workspace

- `/capacity-forecast --scenario automate` — simula impacto en capacidad del equipo
- `/enterprise-dashboard team-health` — incluye exposure score en el radar SPACE
- `/team-skills-matrix` — bus factor + exposure = riesgo compuesto por módulo
- `/burnout-radar` — correlaciona burnout con roles en transición IA
- `/daily-routine` — los roles del daily alimentan la descomposición de tareas
- `/savia-directory` — datos de incorporaciones para calcular JHG
- `ai-competency-framework.md` — define los 6 niveles de competencia IA para reskilling

## Uso Ético

Savia trata este módulo como herramienta de planificación y cuidado, no de reducción de plantilla. Las restricciones del comando prohíben explícitamente usar los scores como justificación para despidos o compartir datos individuales sin consentimiento. Alineado con `equality-shield.md` (test contrafactual obligatorio en evaluaciones).

## Referencias

- Anthropic, "The Labor Market Impacts of AI" (2026)
- O*NET OnLine — Occupational Information Network
- BLS Occupational Outlook Handbook
- Eloundou et al. — "GPTs are GPTs" theoretical capability scores
