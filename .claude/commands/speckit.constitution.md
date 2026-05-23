---
name: /speckit.constitution
description: "Alias spec-kit compatible. Declara los principios inmutables de un proyecto (constitution). Invoca skill savia-identity con args para constituir un proyecto. Compatible con github/spec-kit (>100k stars)."
developer_type: all
agent: task
context_cost: low
---

# /speckit.constitution — Constitución del proyecto

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `savia-identity` + `docs/rules/domain/project-onboarding.md`.

## Qué hace

Declara los principios inmutables del proyecto (tone, technology, governance) que toda futura spec debe respetar. Es el equivalente a la "constitution" de spec-kit.

## Sintaxis

```
/speckit.constitution [descripción inicial de los principios]
```

`$ARGUMENTS` se propaga como brief inicial. Vacío → entrevista interactiva.

## Ejecución

1. Carga skill `savia-identity` para detectar contexto del proyecto activo.
2. Genera o actualiza `projects/{active}/CONSTITUTION.md` con principios inmutables.
3. Refleja la decisión en `docs/rules/domain/` si afecta governance global.

## Equivalencias

Ver tabla canónica en `docs/agent-teams-sdd.md` sección "spec-kit ↔ Savia".
