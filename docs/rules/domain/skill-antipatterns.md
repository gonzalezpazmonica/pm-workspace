---
context_tier: L3
token_budget: 1200
usage: reference-only
---

# Skill Anti-patterns — Canonical Reference

Documento canonico de anti-patrones de las skills criticas de pm-workspace.
Generado en SE-210. Referencia cruzada con cada SKILL.md.

---

## tdd-vertical-slices

Skill: `.opencode/skills/tdd-vertical-slices/SKILL.md`

| Anti-pattern | Consecuencia | Correcto |
|---|---|---|
| **Horizontal slicing** | Tests acoplados a implementacion, fallos en cascada al refactorizar | Un test a la vez: RED -> GREEN -> siguiente test |
| **Slice demasiado grueso** | RED/GREEN imposible de aislar, refactor bloqueado | Cada slice verifica exactamente un comportamiento observable |
| **Over-mocking** | Tests pasan siempre sin ejecutar codigo real, bugs de integracion ocultos | Mockear solo dependencias externas (red, I/O, tiempo) |
| **Test-after** | Tests documentan implementacion existente, cero valor de diseno | RED antes de cualquier implementacion |

---

## grill-me

Skill: `.opencode/skills/grill-me/SKILL.md`

| Anti-pattern | Consecuencia | Correcto |
|---|---|---|
| **Critica generica** | Ruido sin senal, equipo ignora el output | Cada hallazgo nombra artefacto concreto, condicion de fallo y consecuencia |
| **Activar en codigo no propuesto** | Scope creep, review infinita | Aplicar solo al diff o artefacto que se esta mergeando |
| **Praise-sandwich** | Mensaje critico diluido, autor recuerda elogios y minimiza problemas | Critica directa sin wrapper (Radical Honesty Rule #24) |
| **Rubber-stamp** | Bugs criticos llegan a produccion con sello de aprobado | Si no hay tiempo para revision real: BLOCKED, nunca LGTM vacio |

---

## savia-memory

Skill: `.opencode/skills/savia-memory/SKILL.md`

| Anti-pattern | Consecuencia | Correcto |
|---|---|---|
| **Guardar sin tipo** | Memoria no recuperable por topic, busquedas devuelven ruido | Tipo semantico correcto: decision, discovery, bug, pattern |
| **Guardar sin source** | Trazabilidad rota, entries huerfanas sin origen verificable | Siempre incluir --source con el skill, comando o sesion origen |
| **Bulk-dump** | Memoria saturada con ruido, entradas valiosas enterradas | Guardar solo datos con valor de recuperacion real |
| **No-recall** | Memoria crece pero no se usa, agente repite errores | Recall al inicio de sesion relevante antes de proponer soluciones |
| **Stale-reads** | Decisiones basadas en contexto obsoleto | Verificar frescura de entradas >30 dias antes de actuar |

---

## spec-driven-development

Skill: `.opencode/skills/spec-driven-development/SKILL.md`
Anti-patterns en satelite: `.opencode/skills/spec-driven-development/REFERENCE.md`

| Anti-pattern | Consecuencia | Correcto |
|---|---|---|
| **AC sin criterio verificable** | Imposible automatizar validacion, developer no sabe cuando ha terminado | AC en formato Given/When/Then con datos concretos y umbral medible |
| **Merge sin aprobacion humana** | Viola Rule #8, bypassa Code Review obligatorio (E1 siempre humano) | PR en estado Draft, esperar aprobacion humana explicita |
| **Spec-after** | La spec no guia, solo describe; pierde valor de contrato ejecutable | Spec aprobada ANTES de cualquier implementacion (Rule #8) |
| **Waterfall-spec** | Spec obsoleta en cuanto empieza implementacion real, drift inmediato | Especificar contrato (interface, tipos, AC), no pasos de implementacion |
| **Orphan-spec** | Nadie puede determinar cuando esta Done | Toda spec tiene al menos un AC Given/When/Then con criterio medible |

---

## Patron comun entre todos los anti-patrones

Todos los anti-patrones comparten una raiz: **atajar el proceso para ahorrar tiempo a corto plazo**.

- Horizontal slicing: "escribo todos los tests de golpe para ir mas rapido"
- Rubber-stamp: "no tengo tiempo para revisar bien"
- Bulk-dump: "guardo todo ahora y ya filtro luego"
- Spec-after: "ya escribire la spec cuando tenga el codigo"

El coste real es invariablemente mayor: bugs de integracion, reviews ignoradas,
memoria inutilizable, y deuda tecnica de documentacion.

---

Referencias:
- `docs/propuestas/SE-210-skill-antipatterns.md` — spec origen
- `docs/rules/domain/radical-honesty.md` — Rule #24 (aplica a grill-me)
- `docs/rules/domain/autonomous-safety.md` — Rule #8 (aplica a spec-driven-development)
