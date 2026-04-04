# Performance Audit -- Dominio

## Por que existe esta skill

Los problemas de rendimiento se descubren tarde en produccion. El analisis estatico detecta hotspots, anti-patrones async y complejidad excesiva antes de que impacten. Esta skill identifica funciones problematicas sin ejecutar codigo, priorizando hallazgos por severidad e impacto.

## Conceptos de dominio

- **Hotspot**: funcion con score compuesto alto (cyclomatic x0.4 + cognitive x0.3 + length x0.15 + nesting x0.1 + fan-out x0.05).
- **Async Anti-pattern**: bloqueo en contexto asincrono (Task.Result, .Wait(), await en loop, sync-over-async).
- **Complejidad ciclomatica**: caminos independientes por funcion; <=10 OK, 11-20 HIGH, >=21 CRITICAL.
- **Performance Score**: 100 - penalizaciones (CRITICAL -15, HIGH -8, MEDIUM -3, LOW -1); >=80 GOOD.
- **Test-First Optimization**: crear characterization tests ANTES de optimizar para garantizar no-regresion.

## Reglas de negocio que implementa

- performance-patterns.md: umbrales de complejidad, deteccion N+1, blocking async, memory allocation.
- scoring-curves.md: normalizacion piecewise-linear para metricas de rendimiento.
- Hallazgos >=HIGH se registran automaticamente en /debt-track con ID PA-{NNN}.
- Hotspots sin tests elevan severidad +1 nivel automaticamente.

## Relacion con otras skills

- **Upstream**: architecture-intelligence (deteccion de lenguaje y estructura).
- **Downstream**: debt-track (hallazgos como deuda tecnica), code-improvement-loop (fixes autonomos).
- **Paralelo**: language packs (perf-{lang}.md complementa con patrones especificos del lenguaje).

## Decisiones clave

- Analisis estatico sobre benchmarks: no requiere entorno de ejecucion; aplicable a cualquier lenguaje.
- 4 fases ponderadas (complejidad 40%, async 25%, hotspots 20%, coverage 15%): prioriza lo que mas impacta.
- Test-first obligatorio: optimizar sin tests es mas peligroso que no optimizar.
