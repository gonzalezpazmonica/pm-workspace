---
id: SE-081
title: SE-081 — Pocock skills quick-wins (caveman + zoom-out + grill-me)
status: APPROVED
origin: mattpocock/skills review (MIT, 26.4k stars) — análisis 2026-04-27
author: Savia
priority: alta
effort: S 2h
related: SE-080 (vocabulary), Rule #24 radical-honesty
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-081 — Pocock skills quick-wins

## Why

Tres skills de mattpocock/skills (MIT) cubren huecos reales en pm-workspace que no requieren código nuevo, sólo SKILL.md cortos:

- **caveman** (49 LOC en su repo): modo de respuesta ultra-comprimido (-75 % tokens). Útil cuando Mónica está en sesión de móvil o Voicebox y la verbosidad es coste real. NO existe equivalente en pm-workspace.
- **zoom-out** (7 LOC): trigger trivial "dame mapa de módulos relacionados — voy a ciegas en este área". Hoy lo hace `architect` agent pero con 1100+ LOC de prompt; un skill ligero baja la fricción.
- **grill-me** (10 LOC): interrogatorio relentless sobre cada rama del decision tree de un plan. Alinea con Rule #24 Radical Honesty ("challenge assumptions, expose blind spots") pero hoy es cultura, no skill invocable.

Coste de no adoptar: tres patrones útiles quedan sólo en cabeza de Mónica, no enforced. Coste de adoptar: ~70 LOC de markdown (zero código), atribución MIT en headers.

## Scope (Slice único, S 2h)

### 1. `.claude/skills/caveman/SKILL.md` (clean-room, ~50 LOC)

- Trigger: usuaria dice "caveman", "modo cavernícola", "menos tokens", "/caveman"
- Persistencia: ACTIVE EVERY RESPONSE una vez activado, hasta "stop caveman" o "modo normal"
- Reglas de compresión: drop articles, filler, pleasantries, hedging; abreviaturas comunes (DB/auth/config/req/res); arrows para causality (X → Y); fragmentos OK
- Auto-clarity exception: para warnings de seguridad, confirmación de operaciones irreversibles, multi-step sequences donde fragment order arriesga misread → cavemen pausa, frase completa, retoma
- Source-of-truth original: mattpocock/skills/caveman (MIT) — pattern only, sin copiar texto

### 2. `.claude/skills/zoom-out/SKILL.md` (clean-room, ~10 LOC)

- Trigger: "zoom out", "no conozco esta zona", "dame mapa", "/zoom-out"
- Body: "No conozco esta zona del código. Sube una capa de abstracción. Dame un mapa de los módulos relevantes y de quién los llama, sin entrar en detalle de implementación."
- `disable-model-invocation: true` — sólo invocable explícitamente (es trigger humano, no auto-detect)

### 3. `.claude/skills/grill-me/SKILL.md` (clean-room, ~15 LOC)

- Trigger: "grill me", "interrógame", "stress-test este plan", "/grill-me"
- Body: "Interroga relentlessly sobre cada aspecto del plan hasta llegar a entendimiento compartido. Recorre cada rama del árbol de decisión, resolviendo dependencias entre decisiones una a una. Para cada pregunta, da tu recomendación. Una pregunta a la vez. Si la pregunta tiene respuesta en el código, explóralo en lugar de preguntar."
- Cross-reference: `docs/rules/domain/radical-honesty.md` (Rule #24 — challenge assumptions)

### 4. README + CHANGELOG entries

- Línea en `.claude/skills/README.md` (si existe) o nada
- CHANGELOG fragment con atribución MIT a mattpocock/skills

## Acceptance criteria

- [ ] AC-01 `.claude/skills/caveman/SKILL.md` ≤80 LOC con frontmatter `name`, `description` que incluya "Use when ..."
- [ ] AC-02 `.claude/skills/zoom-out/SKILL.md` ≤30 LOC
- [ ] AC-03 `.claude/skills/grill-me/SKILL.md` ≤30 LOC, cita `radical-honesty.md`
- [ ] AC-04 Headers de los 3 skills citan `mattpocock/skills` (MIT) en attribution line
- [ ] AC-05 Ningún skill copia texto literal de Pocock (clean-room — verificable por diff manual)
- [ ] AC-06 Tests BATS estáticos: los 3 SKILL.md existen, tienen frontmatter válido, ≤ líneas máximas, attribution presente
- [ ] AC-07 CHANGELOG fragment

## No hace

- NO adopta `npx skills add` distribution mechanism — incompatible con autonomous-safety (instalaría sin revisar)
- NO adopta el resto del catálogo Pocock — skills separadas por spec individual (SE-082..SE-087)
- NO crea hooks ni tooling — es markdown puro
- NO modifica skills existentes — sólo añade tres nuevos

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Caveman drift en operaciones críticas | Baja | Medio | Auto-clarity exception explícita en SKILL.md (security warnings, irreversible ops) |
| zoom-out solapa con architect | Baja | Bajo | architect es agente (heavyweight); zoom-out es skill (1 turn) — uso distinto |
| grill-me se invoca cuando no toca | Baja | Bajo | Trigger explícito sólo (no auto) |

## Dependencias

- ✅ Rule #24 estable (radical-honesty.md)
- ✅ `.claude/skills/` directory existe (86 skills hoy)
- Sin bloqueantes externos. Independiente de SE-082..SE-087.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| 3 SKILL.md | `.claude/skills/{caveman,zoom-out,grill-me}/SKILL.md` | autoload vía AGENTS.md regen (SE-078 hook) |

### Verification protocol

- [ ] AGENTS.md regenerado tras añadir los 3 skills (drift check pasa)
- [ ] Test BATS estático verifica los 3 SKILL.md existen con frontmatter

### Portability classification

- [x] **PURE_DOCS**: zero código, pura adopción markdown. Cross-frontend trivial (AGENTS.md ya cubre OpenCode).

## Referencias

- `https://github.com/mattpocock/skills` — repo origen (MIT, 26.4k stars, push 2026-04)
- `mattpocock/skills/caveman/SKILL.md`, `zoom-out/SKILL.md`, `grill-me/SKILL.md` — patterns
- `docs/rules/domain/radical-honesty.md` — Rule #24 alignment para grill-me
