# Context-Optimized Development — Dominio

## Por que existe esta skill

Con ~60% de la ventana de contexto consumida por reglas y CLAUDE.md, solo queda ~40%
para trabajo real. Esta skill define patrones para maximizar la calidad del codigo
delegando trabajo pesado a subagentes con contexto fresco de 200K tokens.

## Conceptos de dominio

- **Slice**: unidad minima de implementacion (<=3 ficheros, ~15K tokens de contexto)
- **Context priming**: carga selectiva de solo los ficheros necesarios para un slice especifico
- **Subagent delegation**: enviar tarea a un agente con contexto fresco en vez de gastar el principal
- **State on disk**: persistir progreso en output/dev-sessions/ para sobrevivir a /compact
- **Token budget por fase**: limites calibrados (Prime 15K, Implement 12K, Validate 8Kx2, Review 12K)

## Reglas de negocio que implementa

- Dev Session Protocol (dev-session-protocol.md): las 5 fases de desarrollo con slices
- Context Health (context-health.md): /compact obligatorio entre slices, output-first
- Agent Context Budget (agent-context-budget.md): presupuestos maximos por categoria de agente

## Relacion con otras skills

- **Upstream**: spec-driven-development (genera la spec que se divide en slices)
- **Downstream**: check-coherence command (valida cada slice contra su spec-excerpt)
- **Paralelo**: dag-scheduling (orquesta subagentes en paralelo cuando los slices son independientes)

## Decisiones clave

- Spec completo nunca al subagente: solo el excerpt del slice, para no desperdiciar tokens
- /compact obligatorio entre slices sin excepcion: la degradacion por contexto lleno es silenciosa
- Estimacion de tokens por tipo de fichero (C# 1.4, Python 1.1, YAML 0.8): precision > generalidad
