# Predictive Analytics -- Dominio

## Por que existe esta skill

Prometer fechas basandose en intuicion genera expectativas irreales. Esta skill usa Monte Carlo simplificado y flow metrics para ofrecer rangos probabilisticos de entrega. No predice el futuro: cuantifica la incertidumbre para que las decisiones sean informadas.

## Conceptos de dominio

- **Monte Carlo simplificado**: 1000 simulaciones aleatorias sobre velocity historica; salida en percentiles P50/P70/P85/P95.
- **Flow Efficiency**: ratio tiempo activo vs tiempo total de un item (Active Time / Total Elapsed); >50% es buena.
- **WIP Aging**: alerta cuando un item lleva >2x el cycle time promedio en el mismo estado.
- **Throughput Trend**: regresion lineal sobre items completados por semana; slope indica mejora, estabilidad o declive.
- **Confidence Intervals**: P50 para equipo interno, P85 para Product Owner, P95 para ejecutivos.

## Reglas de negocio que implementa

- Predicciones son inputs para planificacion, NUNCA compromisos fijos.
- Minimo 4 data points para throughput trend; 6 sprints para deteccion de anomalias.
- WIP Aging rojo >2x cycle_time_avg, ambar >1.5x, verde <=1.5x.
- Factores no-cuantitativos (moral, calidad, acoplamiento) no se miden; combinar con insights cualitativos.

## Relacion con otras skills

- **Upstream**: azure-devops-queries (velocity por sprint via WIQL), sprint-management (datos historicos).
- **Downstream**: sprint-forecast (consume predicciones), capacity-planning (ajusta planes con rangos).
- **Paralelo**: enterprise-analytics (comparte formulas Monte Carlo a nivel portfolio).

## Decisiones clave

- Monte Carlo simplificado sobre modelos complejos: suficiente precision con minima complejidad.
- Percentiles sobre punto unico: comunicar incertidumbre es mas honesto que dar una fecha.
- Flow Efficiency sobre velocity sola: velocity no captura tiempo bloqueado ni en cola.
