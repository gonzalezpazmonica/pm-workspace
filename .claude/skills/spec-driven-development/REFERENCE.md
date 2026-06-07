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
