---
id: SPEC-162
title: Self-Evolving Tools (research)
status: APPROVED
priority: LOW
estimated_hours: 12
tier: 3F
origin: anthropic-effective-agents-thesis-2026
---

# SPEC-162 Self-Evolving Tools (research)

## Problema
Tools del workspace son estaticas. Anthropic insinua tools que evolucionan: el agente analiza sus propias trajectories y propone mejoras a las tools que usa. Riesgo alto, recompensa alta, viabilidad incierta.

## Solucion (research, no implementacion productiva)
Investigar viabilidad de:
1. Agente que analiza sus propias trajectories de las ultimas N semanas
2. Propone modificaciones a tools (params, naming, output format)
3. Genera PR con cambio + tests + justificacion basada en datos
4. SIEMPRE L4 + revision humana obligatoria (autonomous-safety)

## Slices
1. Research: state of the art en self-improving agents (4h)
   - Voyager, ReAct, Reflexion, Self-Discover papers
   - Anthropic constitutional AI references
2. Prototipo time-boxed: agente que propone mejora a 1 tool concreta (6h)
   - Target: 1 skill propia del workspace
   - PR draft generado, NO mergeado
3. Informe viabilidad + recomendacion go/no-go (2h)

## AC
- Informe research con 5+ referencias academicas/industriales
- Prototipo funcional (1 propuesta concreta) o justificacion de descarte
- Decision documentada en propuesta o tarea backlog
- Si go: propuesta de SPEC productiva con scope reducido

## Riesgos
- Cambios destructivos a tools criticas. Mitigacion: L4 + human review + rollback automatico si tests fallan
- Loop infinito de mejora. Mitigacion: cap de 1 propuesta por tool por mes
- Sesgo del agente hacia complejidad. Mitigacion: heuristica que penaliza aumentar lineas de codigo

## Out of scope
- Implementacion productiva (esto es research)
- Self-modifying agents (cambios a si mismo)
- Tools que modifican otros agentes
- Bypass de L4 / autonomous-safety
