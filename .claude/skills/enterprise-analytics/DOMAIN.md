# Enterprise Analytics -- Dominio

## Por que existe esta skill

Las organizaciones con multiples proyectos necesitan visibilidad agregada de salud, rendimiento y riesgo. Sin metricas empresariales, las decisiones estrategicas se basan en intuicion. Esta skill centraliza SPACE, portfolio y forecasting en un solo dashboard ejecutivo.

## Conceptos de dominio

- **SPACE Framework**: 5 dimensiones de productividad (Satisfaction, Performance, Activity, Communication, Efficiency) medidas 0-100.
- **Portfolio Health Score**: agregacion ponderada de SPACE, velocity trend y riesgo cross-proyecto en escala 0-100.
- **Risk Matrix**: mapa 2D (probabilidad x impacto) de dependencias criticas entre proyectos.
- **Monte Carlo Forecast**: simulacion de 1000 iteraciones sobre velocity historica para proyectar rangos optimista/probable/pesimista.
- **WIP Ratio**: items en progreso vs finalizados por sprint; umbral sano <= 3 por persona.

## Reglas de negocio que implementa

- Velocity stable +-20% (enterprise-metrics.md: Performance threshold).
- Dependencies cross-proyecto resueltas <48h (enterprise-metrics.md: Communication SLA).
- Burnout risk <30% zona verde, >60% zona roja (enterprise-metrics.md: Satisfaction).
- Forecasts son internos: nunca prometer a clientes sin validacion humana.

## Relacion con otras skills

- **Upstream**: sprint-management (velocity por proyecto), azure-devops-queries (datos WIQL).
- **Downstream**: executive-reporting (consume portfolio scores para informes PPTX/DOCX).
- **Paralelo**: predictive-analytics (comparte formulas Monte Carlo), capacity-planning (WIP y carga).

## Decisiones clave

- SPACE sobre DORA puro: DORA mide delivery; SPACE incluye satisfaccion y colaboracion.
- Forecasting con ultimos 5 sprints: equilibrio entre estabilidad estadistica y adaptabilidad a cambios.
- Output-first: dashboards se guardan en fichero, solo resumen en conversacion.
