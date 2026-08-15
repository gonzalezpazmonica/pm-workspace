# spec-driven-development — Reference

> Satélite de `.claude/skills/spec-driven-development/SKILL.md`. Cargado bajo demanda.
> Contexto: anti-patterns, criterios extendidos de calidad de specs.

## Anti-patterns

**❌ AC sin criterio verificable**: acceptance criterion del tipo "el sistema debe ser rápido" o "debe comportarse correctamente" → imposible automatizar la validación, el developer no sabe cuándo ha terminado.
**✓ Correcto**: AC en formato Given/When/Then con datos concretos y umbral medible (ej: "Given N=1000 items, When se llama al endpoint, Then responde en <200ms").

**❌ Merge sin aprobación humana**: el agente hace merge del PR de la spec o del PR de implementación → viola Rule #8 directamente, bypassa Code Review obligatorio (E1 = siempre humano).
**✓ Correcto**: el agente crea PR en estado Draft y espera aprobación humana explícita antes de cualquier merge.

## Checklist de spec ejecutable

- [ ] Contrato (interface) definido exactamente — sin "TBD"
- [ ] Tipos de entrada/salida definidos (no "any" o "object")
- [ ] Reglas de negocio inequívocas — una interpretación posible
- [ ] Test scenarios cubren casos normales Y edge cases
- [ ] Ficheros a crear/modificar listados con paths exactos
- [ ] Criterios de aceptación verificables (Given/When/Then + datos)
- [ ] Developer type determinado: human | agent-single | agent-team

## Referencias

- `docs/propuestas/SE-210-skill-antipatterns.md` — origen de estos anti-patterns
- `docs/rules/domain/autonomous-safety.md` — Rule #8: NUNCA merge/approve autónomo
**❌ Spec-after**: escribir la spec después de la implementación para documentar lo que se construyó → la spec no guia, solo describe; pierde el valor de contrato ejecutable.
**✓ Correcto**: la spec se escribe y aprueba ANTES de cualquier implementación (Rule #8 SDD obligatorio).

**❌ Waterfall-spec**: especificar cada detalle de implementación antes de cualquier código → la spec se vuelve obsoleta en cuanto empieza la implementación real, generando drift inmediato.
**✓ Correcto**: la spec define el contrato (interface, tipos, AC) no los pasos de implementación. Los detalles emergen durante el desarrollo.

**❌ Orphan-spec**: spec sin Acceptance Criteria verificables → nadie puede determinar cuándo está Done, el developer tipo human o agent no sabe cuándo parar.
**✓ Correcto**: toda spec tiene al menos un AC en formato Given/When/Then con datos concretos y criterio medible.

## Aprobación del Spec (answer ≠ approval)

Regla dura: **una respuesta no es una aprobación**. Si preguntaste al humano una
decisión, te respondió esa pregunta y nada más. Su respuesta es un INPUT al
spec, y lo CAMBIA — así que cualquier aprobación previa era de un documento que
ya no existe. Pregunta y aprobación son dos intercambios, en ese orden: integra
las respuestas, di qué cambió, muestra el spec revisado, pregunta otra vez. Si
no puedes citar las palabras que aprobaron ESTE spec, no tienes aprobación — ni
una respuesta a tu pregunta, ni un "adelante" sobre otro paso, ni el silencio,
ni la petición que inició la tarea son aprobación.

El caso fácil de equivocarse: cuando el humano elige las opciones que
recomendaste, el spec parece sin cambios y el consentimiento parece implícito.
Ninguno de los dos es cierto.

- **Append-only**: el spec es append-only durante la tarea. Si la implementación
  revela que el spec estaba mal, dilo explícitamente y revísalo visiblemente —
  nunca drift silencioso.
- **Path absoluto**: escribe el spec a fichero con path absoluto. Un path
  relativo no es clickeable en terminal, y el humano no puede abrir el artefacto
  que se le pide aprobar.
