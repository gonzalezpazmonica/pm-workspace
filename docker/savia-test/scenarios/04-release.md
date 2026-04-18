# Scenario 04 — Release & Retrospective

Release readiness, deploy, outcome validation, retro.

## Step 1
- **Role**: la usuaria
- **Command**: release-readiness

```prompt
Eres Savia. la usuaria evalúa la release readiness del MVP de SocialApp. Se han completado SPEC-001 (User Registration) y SPEC-002 (User Profile). SPEC-003 (Create Post) está en Gates. Verifica: todos los quality gates pasados, integration tests verdes, performance tests dentro de SLA (<200ms p95), security scan limpio, documentación API generada. Genera checklist release con estado de cada item. Pipeline: DEV→PRE→PRO.
```

## Step 2
- **Role**: Elena
- **Command**: outcome-track

```prompt
Eres Savia. Elena valida el outcome O-001 "User Onboarding" post-deploy en PRE. Ejecuta outcome-track. Métricas a verificar: registro completado <2min (actual: 1m45s ✅), retención D1 simulada >60% (pendiente datos reales), error rate registro <1% (actual: 0.3% ✅), OAuth success rate >95% (actual: 97% ✅). El outcome está parcialmente validado, pendiente métricas de retención en producción real.
```

## Step 3
- **Role**: la usuaria
- **Command**: flow-metrics --trend

```prompt
Eres Savia. la usuaria ejecuta flow-metrics con tendencia de 4 semanas para la retrospectiva mensual de SocialApp. Métricas: Cycle Time medio 6.2 días (target <7 ✅), Lead Time 9.5 días, Throughput 3 specs/mes, CFR 0% (sin fallos en deploy), Spec-to-Built 4.8 días, Handoff Latency media 3h. Compara con targets DORA. Identifica: punto de mejora en handoff latency Isabel→Ana, Ana necesita más autonomía en reviews. Genera reporte tendencia.
```

## Step 4
- **Role**: la usuaria
- **Command**: flow-metrics --context-report

```prompt
Eres Savia. Genera un informe específico de uso de contexto durante toda la ejecución del proyecto SocialApp. Analiza: tokens consumidos por tipo de comando (specs, intake, metrics, gates), comandos con mayor consumo de contexto, momentos donde el contexto se acercó al límite, estrategias de compactación aplicadas, recomendaciones para optimizar el uso de contexto en proyectos similares. Este informe es clave para depurar y mejorar Savia.
```

## Step 5
- **Role**: Equipo
- **Command**: retro-summary

```prompt
Eres Savia. Genera el resumen de retrospectiva del primer ciclo de SocialApp. Qué fue bien: dual-track permitió specs en paralelo al building, SDD redujo ambigüedad, quality gates atraparon 2 issues pre-deploy, métricas DORA dentro de target. Qué mejorar: Ana necesita mentoring para ganar autonomía, handoff latency puede bajar con specs más detalladas, Elena sobrecargada con QA+specs simultáneamente. Acciones: crear checklist de review para Ana, rotar QA con Isabel, añadir template de handoff notes.
```
