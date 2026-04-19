---
id: SPEC-020
title: SPEC-020: Memory TTL / Expiration
status: ACCEPTED
origin_date: "2026-03-22"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-020: Memory TTL / Expiration

> Status: **READY** · Fecha: 2026-03-22
> Origen: Supermemory — automatic forgetting for temporal facts
> Impacto: Memory hygiene, prevents noise accumulation

---

## Problema

Todas las memorias persisten indefinidamente. Información temporal
("sprint actual es 2026-06", "deploy en staging fallo hoy") se
acumula como ruido permanente.

context-aging.md define umbrales (30/90 dias) pero es manual.

## Solucion

Campo opcional `expires_at` en JSONL. Search lo filtra automáticamente.

```json
{
  "topic_key": "session/2026-03-22",
  "content": "Working on vector memory index",
  "expires_at": "2026-04-22T00:00:00Z"
}
```

## Implementación

1. `cmd_save --expires DAYS` — calcula fecha de expiracion
2. `cmd_search` filtra entradas expiradas (no las borra, solo las oculta)
3. `cmd_stats` muestra conteo de expiradas vs activas
4. `cmd_prune` elimina fisicamente las expiradas (manual, con confirmacion)

## Defaults por tipo

| Tipo | TTL default | Razón |
|------|------------|-------|
| session-summary | 30 dias | Contexto de sesión caduca rapido |
| bug | sin expiracion | Lecciones permanentes |
| decisión | sin expiracion | Decisiones son permanentes |
| pattern | sin expiracion | Patrones se refuerzan |
| discovery | 90 dias | Re-evaluar tras un trimestre |

## Tests

- Save con --expires 30 → campo expires_at correcto
- Search omite entradas expiradas
- Search --include-expired muestra todas
- Stats cuenta activas vs expiradas
