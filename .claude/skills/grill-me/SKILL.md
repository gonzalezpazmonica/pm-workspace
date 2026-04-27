---
name: grill-me
description: "Relentless interview that walks every branch of a decision tree to expose blind spots. Use when Mónica says 'grill me', 'interrógame', 'stress-test este plan', 'desafía esta decisión', or invokes /grill-me; aligned with Rule #24 radical-honesty (challenge assumptions, expose blind spots)."
summary: |
  Interrogatorio relentless sobre cada aspecto de un plan o decisión.
  Una pregunta a la vez, recorre cada rama del árbol de decisión.
  Para cada pregunta, da tu recomendación. Si la pregunta tiene
  respuesta en el código, explóralo en lugar de preguntar.
maturity: stable
context: fork
agent: any
---

# Grill me

Pattern adoption from `mattpocock/skills/grill-me` (MIT, 26.4k⭐) — clean-room. SE-081 Slice única.

## Body

> Interroga relentlessly sobre cada aspecto de este plan o decisión hasta que lleguemos a entendimiento compartido. Recorre cada rama del árbol de decisión, resolviendo dependencias entre decisiones una a una. Para cada pregunta, ofrece tu recomendación.
>
> Una pregunta a la vez.
>
> Si una pregunta tiene respuesta directa en el código, repo o memoria del workspace, explóralo en lugar de preguntar.

## Cuándo usar

- Mónica acaba de proponer un plan y quiere stress-testarlo
- Antes de cerrar un spec SDD — última pasada antes de APPROVED
- Cuando una decisión arquitectónica tiene 3+ ramas no-obvias
- Cuando intuitivamente "huele a hueco" — Mónica usa el skill explícitamente para forzar el escrutinio

## Qué hace el agente

1. Lee el plan/decisión en cuestión (la conversación reciente o el doc indicado)
2. Identifica las decisiones implícitas que NO están explicitadas (assumptions, constraints, dependencias)
3. Para CADA una, formula UNA pregunta concreta + ofrece su recomendación con razonamiento
4. Espera respuesta de Mónica antes de la siguiente pregunta — NO hace batch
5. Cuando se topa con una pregunta cuya respuesta está en el código (architecture, callers, tests), explora en lugar de preguntar — preserva el tiempo de Mónica

## Disciplina anti-padding

NO preguntar "¿estás seguro?" ni "¿quieres revisarlo?" — son hedging. Cada pregunta debe revelar una rama no resuelta del decision tree, no buscar confirmación de lo ya decidido.

## Cross-references

- Implementa Rule #24 radical-honesty (challenge assumptions / expose blind spots / show where they play small) en formato interactivo
- Alineado con Genesis B9 GOAL STEWARD (defender el alcance del request) — ver `docs/rules/domain/attention-anchor.md` (SE-080)
- Diferente de `business-analyst` agent: ese descompone PBIs; grill-me interroga al humano

## Atribución

`mattpocock/skills/grill-me/SKILL.md` — MIT — pattern only, prosa propia.
