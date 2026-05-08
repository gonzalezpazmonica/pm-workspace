---
name: prompt-optimizer-domain
description: Contexto de dominio para la skill de optimizacion de prompts
---

# Por que existe esta skill

Los prompts de skills y agentes se escriben una vez y raramente se revisan.
Con el tiempo, la calidad del output se degrada o nunca alcanza su potencial.
Esta skill aplica el patron AutoResearch (Karpathy/Risco): si los prompts son
codigo, necesitan un compilador que los optimice automaticamente.

## Conceptos de dominio

- **Test fixture**: par input + checklist que define que debe producir un skill
- **G-Eval scoring**: puntuacion 0-10 por criterio con pesos configurables
- **Consecutive passes**: 3 iteraciones seguidas con score >= 8.0 = convergencia
- **Cambio atomico**: una sola modificacion al prompt por iteracion
- **Optimized copy**: version mejorada separada del original (.optimized.md)

## Reglas de negocio

- El original NUNCA se sobreescribe — el PM decide adoptar la optimizacion
- Las reglas de seguridad y confidencialidad son inmutables
- El frontmatter (name, tools, model) no se modifica
- Maximo 10 iteraciones por defecto (configurable)

## Relacion con otras skills

- **Upstream**: evaluations-framework (rubrics), eval-criteria (G-Eval)
- **Downstream**: cualquier skill o agente optimizado
- **Paralela**: code-improvement-loop (mismo patron, diferente target)

## Decisiones clave

- Score umbral 8.0 (no 9.5 como el original) porque G-Eval 1-10 es mas estricto
- Consecutive passes = 3 (igual que AutoResearch original)
- Output separado (.optimized.md) en vez de sobreescribir, por seguridad
