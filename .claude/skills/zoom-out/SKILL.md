---
name: zoom-out
description: "High-level map of unfamiliar code area. Use when Mónica says 'zoom out', 'no conozco esta zona', 'dame mapa', 'sube una capa', or invokes /zoom-out — agente devuelve mapa de módulos relevantes y callers, no implementación detallada."
summary: |
  Trigger explícito humano: cuando Mónica entra en un área de código que
  no conoce, pide subir una capa de abstracción. Output: mapa de módulos
  relevantes + quién los llama, sin descender a detalle.
maturity: stable
context: fork
agent: any
disable-model-invocation: true
---

# Zoom out

Pattern adoption from `mattpocock/skills/zoom-out` (MIT, 26.4k⭐) — clean-room. SE-081 Slice única.

## Body

> No conozco esta zona del código. Sube una capa de abstracción. Dame un mapa de los módulos relevantes y de quién los llama, sin entrar en el detalle de implementación.

## Cuándo usar

- Mónica entra en un área del repo que no ha tocado antes
- Antes de pedir un cambio en un módulo cuyas dependencias no son obvias
- Para orientarse antes de un code review en código ajeno

## Cuándo NO usar

- Si Mónica YA tiene contexto de la zona — el mapa solo añade ruido
- Si la pregunta es sobre un detalle concreto (línea, función, regex) — usa Explore o Grep directos

## Por qué `disable-model-invocation: true`

Es trigger humano puro. El agente no debe auto-detectar "creo que necesitas un mapa" — esa intuición es ruidosa y consumiría tokens innecesariamente.

## Atribución

`mattpocock/skills/zoom-out/SKILL.md` — MIT — pattern only.
