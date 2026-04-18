# Scenario 03 — Coordination & Quality Gates

Weekly sync, gates, second intake, bottleneck detection.

## Step 1
- **Role**: la usuaria
- **Command**: flow-metrics

```prompt
Eres Savia. la usuaria revisa las métricas de flujo tras la primera semana de SocialApp. Ejecuta flow-metrics. Métricas esperadas: Cycle Time SPEC-001 en progreso (~5 días building), Throughput 0 (nada deployed aún), WIP 1 spec en producción, Lead Time estimado ~8 días. Métricas IA: spec-to-built time tracking, handoff latency Isabel→Ana para contrato API (~4h). Genera dashboard con estado actual.
```

## Step 2
- **Role**: Elena
- **Command**: quality-gate

```prompt
Eres Savia. Elena ejecuta los quality gates para las tasks completadas de SPEC-001 backend. Gate 1 (Lint): ESLint pass. Gate 2 (Unit Tests): 23/23 pass, coverage 85%. Gate 3 (Integration): registro completo email + OAuth mock pass. Gate 4 (Security): bcrypt rounds=12 ok, JWT expiry 15min ok, no secrets en código. Gate 5 (Human Review): Isabel self-review + la usuaria architecture review pendiente. Reporta estado de cada gate.
```

## Step 3
- **Role**: la usuaria
- **Command**: flow-intake

```prompt
Eres Savia. la usuaria ejecuta segundo intake ahora que Isabel terminó SPEC-001 backend (en Gates). Ejecuta flow-intake. Isabel queda libre (WIP 1/2), puede tomar SPEC-002 backend. Ana sigue con SPEC-001 front (WIP 1/2). Mueve SPEC-002 "User Profile" a Production, asigna back a Isabel. SPEC-003 sigue en Spec-Ready. Actualiza board y WIP.
```

## Step 4
- **Role**: la usuaria
- **Command**: flow-board

```prompt
Eres Savia. la usuaria visualiza el tablero actualizado tras segundo intake. Ejecuta flow-board. Exploration: SPEC-003 en Spec-Ready, outcomes O-003/O-004/O-005 pendientes de spec. Production: SPEC-001 en Gates (back done, front building), SPEC-002 en Building (Isabel back). Detecta si hay bottleneck: Ana tiene SPEC-001 front en building y no puede tomar más. ¿Elena debería escribir más specs o ayudar con QA?
```

## Step 5
- **Role**: la usuaria
- **Command**: flow-protect

```prompt
Eres Savia. la usuaria detecta que Ana lleva 5 días seguidos en SPEC-001 front sin pausas significativas. Ejecuta flow-protect --analyze para evaluar el flow state del equipo. Ana tiene WIP 1/2 pero está en context-switching constante entre 5 sub-tasks. Isabel tiene WIP 2/2 (SPEC-001 gates + SPEC-002 building). Elena tiene 3 specs activas. Analiza meeting density, context switches, WIP overload. Sugiere protecciones: bloquear calendario de Ana martes/jueves para deep work, reducir WIP de Elena a 2 specs.
```

## Step 6
- **Role**: Elena
- **Command**: flow-spec

```prompt
Eres Savia. Elena aprovecha que Ana está ocupada para escribir SPEC-004 "Social Graph - Follow System" del outcome O-003. Ejecuta flow-spec. Outcome: follow/unfollow en <1s, sugerencias relevantes. Functional: POST follow, DELETE unfollow, GET followers, GET following, sugerencias basadas en grafos. Technical: MongoDB social_graph collection, índices compuestos, RabbitMQ event user.followed, servicio recomendación. Dependencies: user service, notification service. DoD: unit tests, load test 1000 follows/min.
```
