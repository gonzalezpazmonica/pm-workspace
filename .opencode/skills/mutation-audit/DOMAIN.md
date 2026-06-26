# Domain: Mutation Audit

> Test quality measurement via mutation testing. Detects AI-generated zombie tests.
> Spec: SE-035 — `docs/propuestas/SE-035-mutation-testing-skill.md`

## Problema que resuelve

Cobertura alta (líneas ejecutadas por tests) NO implica tests efectivos. Un test puede pasar por un bloque sin asserciones que capturen cambios lógicos — estos tests zombie pasan pero son inútiles ante regresiones reales.

AI-generated tests son especialmente propensos a esto: el modelo genera tests que ejercitan código pero no siempre validan output con precisión.

## Métrica canónica

**Mutation score** = (mutantes matados) / (mutantes totales) × 100

- Mutante = copia del source con un cambio lógico pequeño (ej. `>` → `>=`)
- Matado = al menos un test falla cuando se ejecuta contra el mutante
- Survivor = todos los tests pasan con el mutante → gap en los tests

## Por qué este skill existe (post-SE-061)

Proyección Q3 2026: 500+ tests AI-generated en pm-workspace. Sin mutation audit periódico, 25% probable zombies.

Research 2026-04-18 (javiergomezcorio substack) documenta caso 57% → 74% automatizado — prueba que el gap es cerrable sin intervención humana pesada.

## Integración con el ecosistema

| Consumidor | Cuando invocar | Threshold |
|---|---|---|
| sprint-end retro | semanal sobre módulos tocados en sprint | 70% |
| test-engineer agent | post-creation de batería nueva (≥10 tests) | 80% |
| overnight-sprint | módulos críticos mensual | 80% |
| PR opcional | developer añadiendo tests a hotpath | 70% |

## Tradeoffs

**Pros**:
- Detecta zombies objetivamente
- Mutadores determinísticos (reproducible con seed)
- Operación on-demand (no CI cost per-PR)

**Contras**:
- Coste tiempo: N mutantes × tiempo_test_suite
- Falsos positivos posibles (mutante equivalente que no cambia semántica)
- Limitado a 4 mutadores Slice 1 (arithmetic/comparison/conditional/return-null)

## Roadmap futuro

- Slice 2 (post-adoption): más mutadores (string-swap, loop-bound, exception-swallow)
- Slice 3: integración test-architect para regenerar tests cuando score < threshold
- Slice 4: trending mensual auto-digerido en `output/mutation-trends/`
