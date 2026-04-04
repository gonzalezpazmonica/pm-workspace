# Coherence Check — Dominio

## Por que existe esta skill

Los outputs de Savia (specs, informes, codigo) pueden desviarse del objetivo declarado
sin que nadie lo detecte. Esta skill verifica que lo producido coincide con lo pedido,
detectando gaps de cobertura, contradicciones internas y proxy optimization.

## Conceptos de dominio

- **Cobertura**: porcentaje de requisitos del objetivo que el output aborda explicitamente
- **Proxy optimization**: cuando el output optimiza una metrica secundaria en vez del objetivo real
- **Contradiccion interna**: dos secciones del mismo output que se contradicen entre si
- **Severidad**: clasificacion del resultado (ok >= 90%, warning 70-89%, critical < 70%)

## Reglas de negocio que implementa

- Verification Before Done (Rule #22): no marcar tarea como completada sin prueba demostrable
- Consensus Protocol (consensus-protocol.md): el coherence-validator es uno de los 4 jueces
- Dev Session Protocol (dev-session-protocol.md): Fase 4 usa coherence check para validar slices

## Relacion con otras skills

- **Upstream**: spec-driven-development (genera specs que luego se verifican), executive-reporting (genera informes)
- **Downstream**: consensus-validation (consume el veredicto de coherencia como input del panel de jueces)
- **Paralelo**: reflection-validation (ambas validan calidad pero desde angulos distintos: coherencia vs metacognicion)

## Decisiones clave

- No bloquea ejecucion por defecto; informa pero no previene (flags --force y --strict disponibles)
- Usa templates diferenciados por tipo (spec, report, code) porque los criterios de coherencia difieren
- Score binario por requisito (cubierto/no cubierto) para simplicidad y reproducibilidad
