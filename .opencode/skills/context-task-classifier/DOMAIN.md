# Context Task Classifier — Dominio

## Por que existe esta skill

La compresión de contexto genérica (summarization) trata todos los turnos igual, perdiendo señal crítica: una decisión de arquitectura comprimida 40:1 se degrada al mismo ratio que un "gracias". SE-029 (rate-distortion-aware compression) requiere clasificar cada turno en una clase de tarea para aplicar el ratio máximo correcto — decisiones y specs se preservan (ratio bajo), chitchat se colapsa (ratio alto). Esta skill es el clasificador determinístico de entrada del pipeline SE-029, sin dependencia de LLM para el caso común (6 clases con heurísticas regex).

## Cuando usar

Activar cuando:
- Se va a compactar una sesión larga y el compresor necesita saber qué ratio aplicar por turno
- `/context-compress` o `/context-budget` orquestan una pasada de compresión consciente de la tarea
- Se analiza una transcripción para medir distribución de clases (¿cuánto chitchat vs cuánto code?)
- Debugging de distortion: un turno comprimido mal quiere saber a qué clase pertenecía

NO usar cuando:
- No hay presupuesto de contexto comprometido (sesión pequeña < 20% del budget) — la compresión genérica sirve
- El turno es el input activo del modelo (compresión aplica a turns ya archivados, no al input current)
- Se requiere clasificación semántica fina (p.ej. distinguir "decisión de arquitectura" vs "decisión de naming") — el clasificador es de 6 clases, no jerárquico

## Limites

- Determinístico solo — sin LLM fallback en este slice. Caso híbrido (turn contiene código Y decisión) se resuelve por scoring aditivo + tie-breaking que favorece la clase más estricta. En casos muy ambiguos el clasificador puede sobre-preservar (conservador por diseño).
- No entiende contexto cross-turn — clasifica cada turno aislado. Un turno de "ok" después de una decisión no heredará clase `decision`; queda como `chitchat`. Para correlación multi-turn usar session-level analyzer (fuera de scope de este slice).
- Patrones regex específicos a este workspace (SPEC-NNN, SE-NNN, PBI-NNN, etc.). Aplicable a otros repos requeriría ajustar los patrones de la clase `spec`.
- Falsos positivos en `code`: líneas con `function foo` en prosa técnica pueden disparar scoring; el filtro actual exige el keyword al inicio de línea seguido de nombre + `[({:=]` para reducir ruido.
- Clase `chitchat` tiene threshold en 8 palabras — turnos muy cortos pero técnicos ("AC-03 wrong") pueden caer ahí sin patrones, pero el scoring `spec` dispara primero.

## Confidencialidad

El clasificador opera sobre el texto del turno en stdin o fichero. NO persiste datos: ni caché, ni log, ni envío externo. Read-only determinístico. Apto para turnos N2+ (los patrones regex son locales, sin llamadas a red).

Auditable: cada invocación en modo `--json` emite el score por clase, lo que permite verificar POR QUÉ un turno se clasificó de cierta manera — útil para compliance evidence en sesiones de Court.

## Integración con SE-029

Pipeline completo de SE-029 (Slices 1-5):

```
Turn → context-task-classify.sh (este skill, Slice 2)
     → clase + max_ratio + frozen flag
     → compress-skip-frozen.sh hook (Slice 3) — skip si frozen
     → operational-point-selector (Slice 4) — ratio = min(budget, max_ratio_class)
     → context-compress existente — compresión real con el ratio elegido
     → context-distortion-measure.sh (Slice 1) — mide D post
     → re-state anchor (Slice 5) si ratio > 20:1
```

Este skill es el **primer gate**: clasificación determinística de entrada.
El resto del pipeline puede ser más caro (operational-point selector usa
optimización, distortion measure usa LLM-judge) — filtrar bien aquí
reduce la carga del resto.

## Referencias

- `docs/propuestas/SE-029-rate-distortion-context.md` §2 — SE-029-C task classifier spec
- `scripts/context-task-classify.sh` — implementación
- `tests/test-context-task-classify.bats` — 34 tests (auditor score 98)
- `scripts/context-distortion-measure.sh` — SE-029 Slice 1, mide el resultado
