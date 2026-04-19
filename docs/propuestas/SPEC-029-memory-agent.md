---
id: SPEC-029
title: SPEC-029: Memory Agent — Memoria como Agente Conversacional
status: ACCEPTED
origin_date: "2026-03-25"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-029: Memory Agent — Memoria como Agente Conversacional

> Status: **READY** · Fecha: 2026-03-25 · Score: 4.80
> Origen: Qwen-Agent pattern "Memory as Agent"
> Impacto: Memoria accesible via lenguaje natural, sin comandos exactos

---

## Problema

El sistema de memoria actual (JSONL + scripts) requiere comandos específicos:
`/memory-recall`, `/memory-search`, `scripts/memory-store.sh`. El usuario
(o un agente) debe conocer la sintaxis exacta para acceder a la memoria.

Qwen-Agent demuestra que un agente especializado puede gestionar memoria
de forma conversacional: "¿qué decidimos sobre la autenticación?" → el
agente busca, combina y responde en lenguaje natural.

## Solución

Crear `memory-agent.md` como subagente especializado que:
1. Recibe queries en lenguaje natural
2. Ejecuta búsqueda JSONL con grep/scripts
3. Combina resultados y responde en contexto
4. Puede guardar nuevas memorias sin comandos

## Implementación

Agente en `.claude/agents/memory-agent.md` con herramientas Read, Bash, Glob, Grep.
Modelo haiku para velocidad. Cuatro operaciones:

- `recall`: busca en ~/.savia/memory/*.jsonl por topic/concept
- `save`: escribe nueva entrada via `scripts/memory-store.sh`
- `stats`: cuenta y resume entradas por tipo
- `forget`: marca entrada como obsoleta (no elimina)

## Degradación

Sin memory store → "No tengo memorias guardadas sobre eso."
Store vacío → sugiere `/memory-stats` para verificar.

## Tests

- Query natural devuelve resultado relevante (recall@3 ≥ 1 hit)
- Save via lenguaje natural crea entrada JSONL correcta
- Respuesta en < 5s (modelo haiku)
