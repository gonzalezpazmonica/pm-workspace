---
id: SE-082
title: SE-082 — Architectural vocabulary discipline (Module/Interface/Seam/Adapter/Depth/Locality)
status: APPROVED
origin: mattpocock/skills/improve-codebase-architecture/LANGUAGE.md (MIT) — análisis 2026-04-27
author: Savia
priority: alta
effort: M 4h
related: SE-080 (attention-anchor), architect agent, architecture-judge agent
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-082 — Architectural vocabulary discipline

## Why

`architect` agent (1100+ LOC) y `architecture-judge` agent emiten suggestions con vocabulario inconsistente: "componente", "service", "API", "boundary", "boundary context" se mezclan según el caller. Resultado: dos sesiones de revisión arquitectónica producen lenguaje distinto para el mismo concepto, fricción para Mónica y deriva en specs.

Pocock define 6 términos canónicos en `improve-codebase-architecture/LANGUAGE.md` (MIT) con disciplina deliberada: **Module / Interface / Seam / Adapter / Depth / Locality**. Cada término viene con un `_Avoid_:` explícito (rejection set) que previene drift. Es exactamente el patrón **Genesis B8 ATTENTION ANCHOR** ya nombrado en SE-080.

Coste de no adoptar: el vocabulario actual rota cada review, los outputs no son comparables entre batches, y la integración con specs (que sí usan vocabulario propio) genera fricción. Coste de adoptar: una doc de ~120 LOC + cross-references desde 2 agentes y attention-anchor.md.

## Scope (Slice único, M 4h)

### 1. Doc canónico `docs/rules/domain/architectural-vocabulary.md` (~150 LOC)

Extiende `attention-anchor.md` (SE-080). Define los 6 términos con la misma estructura que Pocock LANGUAGE.md:

- **Module** — anything con interface + implementation. _Avoid_: unit, component, service.
- **Interface** — todo lo que un caller necesita saber: tipos, invariantes, error modes, ordering, config. _Avoid_: API, signature.
- **Implementation** — el código dentro. Distinto de Adapter.
- **Seam** (Michael Feathers) — donde vive la interface; sitio donde el comportamiento puede alterarse sin editar in-place. _Avoid_: boundary (overload con DDD bounded context).
- **Adapter** — cosa concreta que satisface una interface en un seam.
- **Depth** — leverage at the interface. _Deep_ = mucho comportamiento detrás de una interface pequeña.
- **Locality** — lo que el maintainer gana de Depth: el cambio se concentra en un sitio.

Más principios ratchet:

- **Deletion test**: ¿desaparece la complejidad si borro el módulo? Si reaparece en N callers, el módulo se ganaba el sueldo.
- **Interface = test surface**: si quieres testear "más adentro", el módulo está mal cortado.
- **One adapter = hypothetical seam. Two adapters = real seam.**

Atribución MIT a Pocock LANGUAGE.md en header. Re-implementación clean-room — no copiar texto literal.

### 2. Cross-references (3 sitios)

- `docs/rules/domain/attention-anchor.md` → "Vocabulario arquitectónico canónico: ver `architectural-vocabulary.md`"
- `.claude/agents/architect.md` → "Usa vocabulario `docs/rules/domain/architectural-vocabulary.md` (Module/Interface/Seam/Adapter/Depth/Locality). NO uses 'component/service/API/boundary' en outputs."
- `.claude/agents/architecture-judge.md` → mismo añadido.

### 3. Auditor estático

`scripts/architectural-vocabulary-audit.sh` — escanea outputs recientes de `architect` / `architecture-judge` (en `output/agent-runs/architect-*` si existe, else `output/architect-*.md`) y reporta usos prohibidos ("boundary", "component", "service", "API"). Output: lista de archivos + línea + término violador. Exit 0 siempre (warning-only en este Slice — gate enforced en SE-084 audit).

### 4. Tests BATS estáticos

- Doc canónico tiene los 6 términos definidos
- Doc canónico cita Pocock MIT
- Cross-references existen en los 3 sitios

## Acceptance criteria

- [ ] AC-01 `docs/rules/domain/architectural-vocabulary.md` existe, ≤200 LOC, define los 6 términos con _Avoid_ por cada uno
- [ ] AC-02 Atribución MIT a `mattpocock/skills/improve-codebase-architecture/LANGUAGE.md` en header
- [ ] AC-03 Cross-reference añadida en `attention-anchor.md`
- [ ] AC-04 `architect` agent referencia el doc canónico (1 línea en system prompt)
- [ ] AC-05 `architecture-judge` agent referencia el doc canónico
- [ ] AC-06 `scripts/architectural-vocabulary-audit.sh` ejecutable, output warning-only
- [ ] AC-07 Tests BATS ≥10 estáticos
- [ ] AC-08 CHANGELOG fragment

## No hace

- NO porta el resto de `improve-codebase-architecture` (DEEPENING.md, INTERFACE-DESIGN.md) — fuera de scope (ver SE-087)
- NO bloquea outputs con vocabulario antiguo (warning-only) — gate enforced viene en SE-084
- NO renombra archivos existentes — sólo añade vocabulario
- NO reescribe specs antiguas — vocabulario aplica a outputs nuevos

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Vocabulario "Seam" choca con DDD "bounded context" | Media | Bajo | Doc explica explícitamente la distinción + _Avoid_ list |
| Adopción inconsistente entre agentes | Alta | Medio | Auditor (Slice 4) detecta drift; SE-084 gate enforced |
| Pocock cambia LANGUAGE.md upstream | Baja | Bajo | Doc cita commit hash de Pocock |

## Dependencias

- ✅ SE-080 attention-anchor.md IMPLEMENTED (batch 69)
- ✅ `architect` y `architecture-judge` agents existen
- Sin bloqueantes. Independiente de SE-081 / SE-083 / SE-084.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Doc canónico | `docs/rules/domain/architectural-vocabulary.md` | mismo path (lazy-load) |
| Agent updates | `.claude/agents/{architect,architecture-judge}.md` | regen via SE-078 AGENTS.md |
| Auditor | `scripts/architectural-vocabulary-audit.sh` | bash puro, idéntico |

### Verification protocol

- [ ] Smoke: cargar doc desde sesión OpenCode v1.14
- [ ] Auditor ejecuta sin Claude Code
- [ ] AGENTS.md regen incluye los agents actualizados

### Portability classification

- [x] **PURE_BASH + DOCS**: bash + markdown puro, cross-frontend trivial.

## Referencias

- `mattpocock/skills/improve-codebase-architecture/LANGUAGE.md` — vocabulario fuente
- `docs/rules/domain/attention-anchor.md` (SE-080) — pattern alignment B8
- John Ousterhout "A Philosophy of Software Design" — Deep modules concept (rejected ratio definition; Pocock + Savia usan depth-as-leverage)
- Michael Feathers "Working Effectively with Legacy Code" — Seam original
