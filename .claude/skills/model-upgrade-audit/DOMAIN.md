---
name: model-upgrade-audit-domain
description: Domain knowledge for prompt debt detection and model upgrade analysis
---

# Por que existe esta skill

Cada era de pm-workspace anade capacidades, pero rara vez revisa si workarounds de eras anteriores siguen siendo necesarios con modelos mas recientes. Anthropic reporta ~20% de reduccion en system prompts al eliminar hacks obsoletos. A escala de 400+ comandos, esta deuda de prompt es significativa.

## Conceptos de dominio

- **Prompt debt**: Instrucciones, repeticiones y workarounds que compensaban limitaciones de modelos anteriores
- **Workaround pattern**: Patron detectableque indica compensacion de limitacion del modelo (repeticion enfatica, parsing defensivo, etc.)
- **Token savings**: Reduccion estimada de tokens por sesion al eliminar prompt debt
- **Era snapshot**: Estado completo del workspace antes de aplicar cambios — permite rollback

## Reglas de negocio

- RN-AUDIT-01: NUNCA aplicar cambios sin confirmacion humana (excepto risk:low con evals passing)
- RN-AUDIT-02: Backup completo como snapshot de Era antes de cualquier cambio
- RN-AUDIT-03: Evals con misma temperatura/seed para comparabilidad
- RN-AUDIT-04: El informe se almacena en memoria semantica para tracking longitudinal

## Relacion con otras skills

- **Upstream**: pm-config.md (modelo actual), agents-catalog.md (inventario)
- **Downstream**: agent-efficiency (tracking), context-budget (optimizacion)
- **Paralelo**: feasibility-probe (datos historicos de capacidad del modelo)

## Decisiones clave

- Opus como modelo del auditor (no Sonnet) — necesita capacidad analitica para detectar patrones sutiles
- Solo propone, nunca aplica — la decision final es humana
- Patterns detectados con regex + heuristicas, no con otro LLM — determinista y reproducible
