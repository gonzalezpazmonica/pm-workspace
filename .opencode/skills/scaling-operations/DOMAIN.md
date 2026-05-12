# scaling-operations — Dominio

## Por que existe esta skill

Las organizaciones crecen y lo que funciona con 3 proyectos colapsa con 20. Sin diagnostico explicito del tier de escala, los equipos aplican practicas de startup a organizaciones medianas o viceversa, desperdiciando contexto y capacidad. Esta skill detecta el tier actual, benchmarkea contra targets y genera un plan de optimizacion priorizado por ROI.

## Conceptos de dominio

- **Tier de escala**: clasificacion de la organizacion en Small (1-5 proyectos), Medium (5-20) o Large (20-50) segun metricas concretas
- **Context per-project**: kilobytes de contexto que consume cada proyecto al cargarse, determinante de cuantos proyectos caben en una sesion
- **Async-first transformation**: transicion de comunicacion sincrona a asincrona, critica a partir de Tier 2
- **Knowledge search**: busqueda transversal de conocimiento en decision-logs, ADRs, specs y reglas del workspace

## Reglas de negocio que implementa

- Patrones de escalabilidad (scaling-patterns.md): tiers, recomendaciones y umbrales por aspecto
- Team Topologies (Skelton & Pais): stream-aligned, platform, enabling teams
- Regla de context-health: fragmentacion de contexto obligatoria en Tier 2+
- Regla de parallel-execution: limites de concurrencia de agentes por tier

## Relacion con otras skills

- **Upstream**: `team-coordination` (datos de equipos y dependencias alimentan el analisis de tier)
- **Upstream**: `capacity-planning` (metricas de capacidad son input del benchmark)
- **Downstream**: `context-caching` (recomendaciones de fragmentacion se aplican via caching)
- **Paralelo**: `enterprise-analytics` (metricas a escala enterprise complementan el analisis)

## Decisiones clave

- Tres tiers discretos en vez de escala continua: simplifica la comunicacion y las recomendaciones
- Benchmark contra targets del tier en vez de comparacion con otras organizaciones: cada tier tiene su optimum
- Knowledge search integrado porque a mayor escala, encontrar conocimiento existente es mas valioso que generarlo de nuevo
- Recomendaciones con story points estimados para que el PM pueda priorizarlas en el backlog
