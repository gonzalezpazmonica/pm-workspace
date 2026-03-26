# SPEC-019: Memory Contradiction Resolution

> Status: **READY** · Fecha: 2026-03-22
> Origen: Supermemory pattern — automatic contradiction tracking on upsert
> Impacto: Memory accuracy, prevents stale facts persisting

---

## Problema

Cuando memory-store.sh hace upsert por topic_key, reemplaza la entrada
anterior sin traza. Si "auth strategy = JWT" se reemplaza por "auth
strategy = OAuth2", no queda registro de que cambio ni por que.

Supermemory resuelve esto con contradiction resolution automatica.

## Solucion

Al hacer upsert, preservar el contenido anterior en campo `supersedes`:

```json
{
  "topic_key": "decisión/auth-strategy",
  "content": "OAuth2 with PKCE flow",
  "supersedes": "JWT with refresh tokens",
  "rev": 2
}
```

## Implementación

En `cmd_save()` de memory-store.sh, al detectar upsert:

1. Leer contenido anterior (`old_content`)
2. Si contenido difiere: añadir `"supersedes":"old_content"` al JSON
3. Si contenido igual: no añadir supersedes (es un refresh, no un cambio)
4. Truncar supersedes a 200 chars

## Tests

- Upsert con contenido diferente → supersedes contiene valor anterior
- Upsert con contenido igual → sin campo supersedes
- supersedes truncado a 200 chars
- search muestra supersedes si existe

## Métricas

- Entradas con supersedes / total upserts (ratio de cambio real)
