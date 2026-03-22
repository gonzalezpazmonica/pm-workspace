# SPEC-020: Memory TTL / Expiration

> Status: **READY** · Fecha: 2026-03-22
> Origen: Supermemory — automatic forgetting for temporal facts
> Impacto: Memory hygiene, prevents noise accumulation

---

## Problema

Todas las memorias persisten indefinidamente. Informacion temporal
("sprint actual es 2026-06", "deploy en staging fallo hoy") se
acumula como ruido permanente.

context-aging.md define umbrales (30/90 dias) pero es manual.

## Solucion

Campo opcional `expires_at` en JSONL. Search lo filtra automaticamente.

```json
{
  "topic_key": "session/2026-03-22",
  "content": "Working on vector memory index",
  "expires_at": "2026-04-22T00:00:00Z"
}
```

## Implementacion

1. `cmd_save --expires DAYS` — calcula fecha de expiracion
2. `cmd_search` filtra entradas expiradas (no las borra, solo las oculta)
3. `cmd_stats` muestra conteo de expiradas vs activas
4. `cmd_prune` elimina fisicamente las expiradas (manual, con confirmacion)

## Defaults por tipo

| Tipo | TTL default | Razon |
|------|------------|-------|
| session-summary | 30 dias | Contexto de sesion caduca rapido |
| bug | sin expiracion | Lecciones permanentes |
| decision | sin expiracion | Decisiones son permanentes |
| pattern | sin expiracion | Patrones se refuerzan |
| discovery | 90 dias | Re-evaluar tras un trimestre |

## Tests

- Save con --expires 30 → campo expires_at correcto
- Search omite entradas expiradas
- Search --include-expired muestra todas
- Stats cuenta activas vs expiradas
