# Oportunidades de AI Augmentation por sector

> 🦉 Soy Savia. Este análisis identifica los sectores donde la IA tiene mayor capacidad teórica pero menor adopción real — y cómo pm-workspace puede ayudar a cerrar esa brecha.

---

## El concepto: AI Augmented Donut

El modelo "AI Augmented Donut" (Anthropic, analizado por Miguel Luengo-Oroz) compara dos dimensiones para cada ocupación: la exposición teórica a la IA (cuánto de ese trabajo podría hacer una IA) y la adopción observada (cuánto se usa realmente). La brecha entre ambas es la oportunidad de augmentation.

Los sectores con mayor brecha son los que más se beneficiarían de herramientas de IA bien diseñadas — pero donde menos se están usando hoy.

---

## Sectores con mayor oportunidad

| Sector | Capacidad teórica | Adopción real | Brecha | pm-workspace hoy |
|---|---|---|---|---|
| Healthcare (profesionales) | Alta | Baja | Grande | guide-healthcare.md |
| Educación y biblioteca | Alta | Baja | Grande | guide-education.md |
| Servicios sociales | Alta | Muy baja | Muy grande | No existe |
| Ventas | Alta | Baja | Grande | No existe |
| Legal | Alta | Media-baja | Grande | guide-legal-firm.md |
| Artes y medios | Alta | Baja | Grande | No existe |
| Business y finanzas | Alta | Media | Media | Parcial (enterprise) |

---

## Cómo pm-workspace ya los cubre

**Healthcare** — La guía `guide-healthcare.md` adapta pm-workspace para organizaciones sanitarias: protocolos de mejora continua, compliance HIPAA, gestión de turnos y seguimiento de indicadores clínicos. Los comandos de sprint y reporting se aplican a ciclos de mejora PDCA.

**Educación** — La guía `guide-education.md` y Savia School cubren gestión de proyectos educativos, evaluación de competencias, portfolios de estudiantes y cumplimiento RGPD para menores. Los timesheets trackean dedicación docente.

**Legal** — La guía `guide-legal-firm.md` adapta el workspace a bufetes: gestión de casos como PBIs, plazos legales como sprints, facturación por horas integrada con cost-management, y compliance sectorial.

---

## Gaps identificados

### Servicios sociales (brecha muy grande)

**Oportunidad:** Gestión de casos sociales, coordinación multi-agencia, seguimiento de beneficiarios, reporting de impacto para financiadores.

**Workflows de pm-workspace aplicables:** Sprint management para ciclos de intervención, capacity planning para distribución de caseload, time tracking para justificación de subvenciones, executive reporting para memorias de actividad.

**Extensión necesaria:** Entidades de dominio (beneficiario, caso, intervención), estados personalizados (valoración → plan → seguimiento → cierre), métricas de impacto social.

### Ventas (brecha grande)

**Oportunidad:** Gestión de pipeline comercial, forecasting de ventas, coordinación de campañas, reporting de performance.

**Workflows aplicables:** Backlog management para el pipeline (leads como PBIs), sprint para ciclos de campaña, velocity para conversion rate, stakeholder reports para dirección comercial.

**Extensión necesaria:** Entidades de dominio (lead, oportunidad, cuenta), funnel stages, métricas comerciales (CAC, LTV, churn).

### Artes y medios (brecha grande)

**Oportunidad:** Gestión de producción creativa, coordinación de equipos multidisciplinares, tracking de entregas y revisiones, presupuestos de producción.

**Workflows aplicables:** Sprint para ciclos de producción, spec-driven para briefs creativos, code review adaptado a revisión de contenidos, time tracking para presupuestos de producción.

**Extensión necesaria:** Entidades de dominio (pieza, campaña, brief), estados de revisión (draft → review → aprobación → publicación), métricas de producción.

---

## Relación con `/ai-exposure-audit`

El comando `/ai-exposure-audit` ya calcula la exposición de cada rol a la IA usando datos O*NET. Se podría extender para mostrar no solo la exposición sino la brecha de augmentation: cuánto podría beneficiarse ese rol de herramientas como pm-workspace, comparando capacidad teórica vs adopción real.

Esto convertiría el audit de un análisis de riesgo ("¿me va a reemplazar la IA?") en un análisis de oportunidad ("¿dónde puedo multiplicar mi impacto con IA?").

---

## Próximos pasos

1. Crear `guide-social-services.md` con el vertical de servicios sociales
2. Crear `guide-sales.md` con el vertical de ventas
3. Crear `guide-arts-media.md` con el vertical de artes y medios
4. Extender `/ai-exposure-audit` con la dimensión de brecha de augmentation

> Fuente: Análisis basado en el modelo "AI Augmented Donut" de Anthropic, revisado por Miguel Luengo-Oroz (2025).
