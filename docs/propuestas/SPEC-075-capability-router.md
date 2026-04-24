---
id: SPEC-075
title: SPEC-075: Capability Router — Selección de Agentes por Descripción
status: PROPOSED
origin_date: "2026-03-25"
migrated_at: "2026-04-19"
migrated_from: body-prose
priority: media
---

# SPEC-075: Capability Router — Selección de Agentes por Descripción

> Status: **DRAFT** · Fecha: 2026-03-25 · Score: 3.50
> Origen: Qwen-Agent pattern "Capability-Based Routing"
> Impacto: Routing más preciso para tareas ambiguas; menos errores de asignación

---

## Problema

El routing actual de agentes usa keywords hardcodeadas en `assignment-matrix.md`.
Cuando la tarea es ambigua ("refactoriza esto"), el sistema no sabe qué
agente usar. Qwen-Agent demuestra que usar el campo `description` del agente
como contexto de matching permite routing semántico más preciso.

## Solución

Nuevo skill `smart-routing` que dado una tarea:
1. Carga los `description` de los agentes candidatos (L0 del catálogo)
2. Usa LLM (haiku) para seleccionar el mejor match semántico
3. Devuelve agente + confianza + justificación

```
Tarea: "Refactoriza el servicio de pagos para reducir duplicación"
  ↓ smart-routing
Candidatos: dotnet-developer, architect, code-reviewer
  ↓ LLM matching contra descriptions
Selección: dotnet-developer (92%) — "refactorización en C#"
           code-reviewer (backup, 75%) — "si hay dudas de calidad"
```

## Implementación

En `.claude/skills/smart-routing/SKILL.md`:

```markdown
Entrada: task_description, candidates[] (agente names)
Proceso:
  1. Leer frontmatter descriptions de candidates
  2. LLM prompt: "Given task: {task}. Which agent best fits? Options:\n{descriptions}"
  3. Parse respuesta: agente + score 0-100
Salida: {primary: agent, confidence: N, backup: agent}
```

Integrar en `assignment-matrix.md` como fallback cuando keyword match < 3.

## Degradación

Sin LLM disponible → usar assignment-matrix actual (keyword matching).
Confianza < 50% → preguntar al usuario antes de proceder.

## Tests

- "Refactoriza X" → dotnet-developer o python-developer según contexto proyecto
- "Revisa la seguridad de JWT" → security-attacker o security-guardian
- Confianza reportada calibrada: score 90% → correcto ≥85% de casos
