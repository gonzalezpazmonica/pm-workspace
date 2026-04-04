# AI Labor Impact — Dominio

## Por que existe esta skill

La adopcion de IA transforma los roles de los equipos tecnicos, pero sin metricas objetivas las decisiones de reskilling son reactivas o basadas en intuicion. Esta skill proporciona un marco cuantitativo para medir la exposicion de cada rol a la automatizacion, detectar gaps en la contratacion junior y planificar la transicion de competencias con plazos concretos.

## Conceptos de dominio

- **Theoretical Exposure (TE)**: porcentaje de tareas de un rol que un LLM podria realizar, ponderado por peso de cada tarea
- **Observed Exposure (OE)**: porcentaje de tareas que ya se estan automatizando en la practica
- **Adoption Gap (AG)**: diferencia TE - OE; un gap alto indica margen para automatizar mas
- **Augmentation Ratio (AR)**: proporcion de tareas donde la IA asiste vs. sustituye; AR menor a 0.4 indica sustitucion dominante
- **Junior Hiring Gap (JHG)**: ratio de contrataciones junior actual vs. ano anterior; menor a 0.60 indica pipeline de talento roto

## Reglas de negocio que implementa

- Clasificacion de riesgo por rol: OE mayor a 60% es rojo (reskilling 8 semanas), 30-60% es amarillo (12 semanas), menor a 30% es verde
- JHG menor a 0.60 genera alerta de pipeline roto sin relevo generacional
- Los scores de exposicion no son evaluaciones de rendimiento individual
- Los planes de reskilling son confidenciales (no compartir sin consentimiento)

## Relacion con otras skills

- **Upstream**: team-onboarding (proporciona equipo.md con roles y seniority), enterprise-analytics (datos de equipo)
- **Downstream**: capacity-planning (impacto de automatizacion en capacidad), sprint-management (ajuste de velocity)
- **Paralelo**: developer-experience (DX Core 4 complementa con metricas de satisfaccion)

## Decisiones clave

- Taxonomia O*NET de 4 categorias de tareas porque es el estandar con mayor cobertura ocupacional
- Metricas separadas teorica vs. observada en vez de un solo score, para capturar el gap de adopcion real
- JHG como metrica independiente porque el impacto en contratacion junior es un indicador adelantado critico
