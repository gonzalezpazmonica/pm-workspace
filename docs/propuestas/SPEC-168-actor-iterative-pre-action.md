---
id: SPEC-168
title: Actor iterative pre-action (inner loop with world-model)
status: PROPOSED
priority: LOW
estimated_hours: 10
tier: 3
origin: lecun-jepa-h-research-2026
---

# SPEC-168 Actor Iterative Pre-Action

## Problema
El actor de Savia (el agente que produce la accion) emite UN intento y luego pasa al critic (tribunal). Si el critic rechaza, hay rework completo: nueva invocacion, nuevo contexto, nuevos tokens.

LeCun: el actor en H-JEPA itera internamente N veces, usando el world-model como simulador y el critic interno como gradiente, ANTES de comprometer la accion al entorno. Savia hoy no tiene inner loop.

## Solucion
Wrapper sobre agentes heavy-tier que ejecuta inner loop:

```
for i in 1..N:
  proposal_i = actor.propose(context)
  prediction_i = world_model.simulate(proposal_i)   # SPEC-165
  critique_i = internal_critic.score(prediction_i)  # ligero, no tribunal completo
  if critique_i.score >= threshold: break
  context += [proposal_i, critique_i]               # aprende del intento
return proposal_final
```

N max = 3, threshold = 0.85. Internal critic = haiku-tier con prompt focado, NO el tribunal completo.

## Slices
1. Schema de inner-loop wrapper + internal-critic prompt (3h)
2. Integracion con world-model de SPEC-165 (3h)
3. Activacion opt-in via frontmatter `inner_loop: true` en agentes (2h)
4. Tests BATS + telemetria + comparacion calidad vs baseline (2h)

## AC
- Wrapper funciona en >= 3 agentes heavy (architect, sdd-spec-writer, code-reviewer)
- Telemetria `output/actor-inner-loop.jsonl` registra: agent, iterations, final_score, tokens_used
- Calidad output medible (judge scores) >= baseline en muestra de 30 invocaciones
- Tokens totales por invocacion < 2x baseline (techo aceptable)
- Tests BATS score >= 80

## Riesgos
- 2-3x tokens por invocacion sin mejora notable → coste sin retorno
- Mitigacion: A/B test riguroso antes de enable default
- Inner critic mal calibrado → loop infinito o early-stop
- Mitigacion: N max hard + threshold conservador

## Out of scope
- Aplicar a todos los agentes (solo heavy-tier opt-in)
- Inner critic entrenado (v1 prompt-based)
- Optimizacion via reinforcement learning

## Origen
LeCun H-JEPA: el actor sin inner loop es reactivo. El actor con inner loop + world-model + critic interno es deliberativo. Savia hoy es reactivo en este sentido.

## Trabajo relacionado
- **Bloqueado por SPEC-165** (world-model): sin simulator no hay inner loop util
- Sinergico con SPEC-167 (critic-RAG): el internal critic puede consultar memoria
- Habilitable por SPEC-156 (token_budget): el inner loop necesita budget explicito o explota tokens
