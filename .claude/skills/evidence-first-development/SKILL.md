---
name: evidence-first-development
description: "Desarrollo evidence-first: rodea la implementación con un SPEC aprobado y un gauntlet de restricciones para que el line-by-line review sea opcional. Usar cuando se pide alta garantía (prove it works, no leeré el código), o en dominios de alto riesgo (dinero, auth, pérdida de datos, concurrencia)."
summary: |
  SPEC → RED → GREEN → REFACTOR → GAUNTLET → EVIDENCE. El humano aprueba
  dos artefactos (SPEC antes, EVIDENCE después) y no lee el código línea a
  línea. La confianza pasa de la inspección a las restricciones ejecutables.
  Inspirado en Uncle Bob vía AmazingAng/old-coder (MIT), pattern-only.
maturity: beta
context: fork
context_cost: high
category: "sdd-framework"
tags: ["evidence-first", "gauntlet", "mutation", "coverage", "sdd", "anti-gaming"]
priority: "high"
trigger:
  keywords: [evidence-first, gauntlet, prove it works, no leeré el código, high-assurance, reliable]
---

## Subagent Scope Guard

> Si fuiste invocado como subagente con una tarea concreta, ejecuta solo
> esa tarea y reporta DONE / DONE_WITH_CONCERNS / BLOCKED. NO actives el
> workflow completo de esta skill.

# Skill: Evidence-First Development

El humano NO leerá tu implementación. Su confianza viene de dos artefactos:
**(1)** un SPEC ejecutable que aprueba antes del código, y **(2)** un informe
EVIDENCE que prueba que el código pasó el gauntlet. Invierte el modelo de
revisión: **la confianza pasa de inspección a restricciones**.

Honestidad sobre lo que esto compra: el gauntlet convierte en evidencia
ejecutable las restricciones del SPEC — no puede demostrar que el SPEC
cubre todo lo importante, ni es auto-autenticable (un checker puede ser
unsound y un mapeo puede sobre-afirmar). Por eso el humano aprueba el SPEC
(el artefacto que rompe la correlación todo-autor-mismo-agente), y EVIDENCE
reporta confianza en capas, nunca prueba absoluta.

## Authoritative Paths

> **Lee antes de actuar. NUNCA asumas firmas ni inventes paths.**

| Para | Lee este path |
|---|---|
| Tooling del gauntlet por ecosistema (py/ts/go/rust/java/sql…) | `references/gauntlet.md` |
| Plantilla del informe EVIDENCE | `references/gauntlet.md` (sección "Evidence report template") |
| Checkers caseros fail-closed | `docs/rules/domain/checker-fail-closed.md` |
| Cobertura changed-line | `docs/rules/domain/coverage-scripts.md` |
| Mutation testing | `../mutation-audit/SKILL.md` |
| Aprobación de spec (answer ≠ approval) | `../spec-driven-development/SKILL.md` |

## Cuándo usar

- Alta garantía explícita: "reliable", "prove it works", "no leeré el código"
- Dominios de alto riesgo: dinero, auth, pérdida de datos, concurrencia, API pública
- Cambios donde el line-by-line review no escala (muchos ficheros, output voluminoso)

## Cuándo NO usar

- Cambios triviales (typo, comment, config value) → Tier 1, o tests normales
- Cuando el usuario quiere tests normales sin el bucle completo
- Cuando ya se ejecuta `verification-lattice` con Code Review Court → se solapan

## Decision Checklist

1. ¿El cambio toca dinero/auth/datos/concurrencia/API pública? → Tier 3 (failure model + adversarial pass)
2. ¿Es bug fix o feature pequeña? → Tier 2 (bucle completo, RED reproduce el bug)
3. ¿Es trivial (typo/comment/config)? → Tier 1 (suite + lint, sin tests nuevos)
4. ¿El humano aprobó el SPEC? → si NO: EVIDENCE registra `spec approval: not obtained` y reclama menos confianza

### Abort Conditions

- SPEC tiene placeholders (TODO/TBD) → incompleto, no empezar
- No hay test runner/linter/typechecker y el humano prohíbe añadirlos → capas manuales con confianza reducida
- Cualquier capa del gauntlet falla → bloquear "done", reportar verbatim

## Workflow

```
SPEC → (humano aprueba spec, no código) → RED → GREEN → REFACTOR → GAUNTLET → EVIDENCE
                                          ↑_________________________|
                                              repeat per behavior
```

1. **SPEC**: convierte la petición en criterios de aceptación ejecutables (Gherkin o lista de tests con inputs/outputs concretos, edge cases, invariantes que deben sobrevivir). Incluye el setup plan: herramientas a instalar, uso de git, y **cada dependencia nueva con justificación de una línea**. Escríbelo a fichero con path absoluto y pide aprobación antes de tocar implementación.
2. **RED**: escribe el test de UN behavior, **obsérvalo fallar**. Un test que nunca viste fallar no prueba nada. Si pasa de inmediato, demuéstralo: muta la implementación con un throwaway mutant, mira el test fallar, restaura.
3. **GREEN**: el mínimo código para pasar. Corre la suite completa, no solo el test nuevo.
4. **REFACTOR**: limpia bajo verde. Las assertions están congeladas; editar una assertion no es refactor — es cambio de behavior, vuelve a SPEC.
5. **GAUNTLET**: corre cada capa aplicable (tabla en `references/gauntlet.md`). Nunca saltes una capa en silencio; registra skip con razón. Escala por tier.
6. **EVIDENCE**: informe con números reales de **una sola ejecución fresca final**, reproducible desde el repo solo (entry-point + versiones pineadas + source state).

## Anti-gaming rules (absolutas)

1. Nunca debilitar un test para que pase (no ampliar assertions, no skips, no tolerancias).
2. Nunca editar test e implementación en el mismo paso para llegar a green.
3. Nunca mockear el sistema bajo test — mockea fronteras (red, clock, filesystem), no lógica.
4. Nunca perseguir el número de cobertura — la cobertura detecta código no testeado, no es un target.
5. Nunca reportar una capa que no corriste. "skipped: sin tool, hice mutación manual" preserva confianza; un resultado inventado destruye todo el esquema.
6. Gauntlet fallando bloquea done — reporta el fallo verbatim como outcome.

## Calibración

- **Tier 1 — trivial**: suite + lint. Sin tests nuevos; justifica por qué es intesteable o ya cubierto.
- **Tier 2 — normal**: bucle completo. Bug fixes DEBEN empezar con RED reproduciendo el bug.
- **Tier 3 — high stakes**: failure model primero (lista de modos de daño: race, partial write, hostile input, overflow, rollback fallido…), una capa por modo. Luego bucle completo + property-based + mutación + **adversarial pass** (ataca tu propio código con inputs hostiles antes de declarar done). Modos no cubiertos → known limits en EVIDENCE.

## Outputs esperados

- SPEC aprobado (path absoluto, append-only)
- EVIDENCE report (`references/gauntlet.md` plantilla) con spec→test mapping y números de ejecución fresca
- Entry-point persistido en repo (`tools/gauntlet.sh`) que re-corrre todas las capas

## Memory hooks

- Tras éxito: guardar el patrón de capa del gauntlet que cazó un bug real → `bash scripts/memory-store.sh save --type pattern --title "gauntlet-catch-<lenguaje>" --content "<capa> cazó <bug>" --source skill:evidence-first-development`

## Related

- Skill: `../mutation-audit/SKILL.md`, `../tdd-vertical-slices/SKILL.md`, `../verification-lattice/SKILL.md`, `../spec-driven-development/SKILL.md`
- Rule: `docs/rules/domain/checker-fail-closed.md`, `docs/rules/domain/coverage-scripts.md`
- Ref: AmazingAng/old-coder (MIT) — pattern only, prosa propia
