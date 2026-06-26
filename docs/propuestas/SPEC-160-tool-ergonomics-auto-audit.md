---
id: SPEC-160
title: Tool Ergonomics Auto-Audit
status: IMPLEMENTED
priority: MEDIUM
estimated_hours: 5
tier: 2E
origin: anthropic-effective-agents-thesis-2026
---

# SPEC-160 Tool Ergonomics Auto-Audit

## Problema
Tools del workspace (Read, Grep, Task, etc.) no se auditan por ergonomia. Anthropic recomienda revisar trajectories de agentes y refactorizar tools confusas (parametros mal nombrados, outputs ambiguos, error rates altos).

## Solucion
Script mensual que:
1. Analiza output/agent-runs/*.jsonl ultimas 4 semanas
2. Detecta patterns: tools mal usadas, errores repetidos, parametros confusos (typos)
3. Genera informe con top-5 tools a mejorar
4. Propone refactors (no aplica automaticamente)

## Slices
1. Parser de trajectories y deteccion de patterns (2h)
2. Heuristicas de ergonomia (errores, retries, mal uso) (2h)
3. Informe markdown + tests (1h)

## AC
- Detecta tools con error rate > 15%
- Detecta parametros confusos (typos repetidos en el mismo nombre)
- Detecta retries con mismo input (sintoma de UX confusa)
- Limite 3 PRs de mejora por mes (anti-spam)
- Informe en output/tool-ergonomics-{fecha}.md

## Riesgos
PR spam. Mitigacion: limite 3/mes hardcoded + revision humana obligatoria + dry-run mode por default.

## Out of scope
Auto-aplicar refactors. Modificar tools de OpenCode core (solo wrappers/skills propios).
