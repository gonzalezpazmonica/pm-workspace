# SPEC-073: Query Keyword Expansion — Expansión de Consultas antes de Búsqueda

> Status: **DRAFT** · Fecha: 2026-03-25 · Score: 3.90
> Origen: Qwen-Agent pattern "SplitQueryThenGenKeyword"
> Impacto: Recall de memoria mejora ~20-30% en consultas vagas

---

## Problema

El usuario escribe "¿qué pasa con el login?" pero la memoria tiene guardado
"decisión: autenticación JWT". Los tokens no coinciden → no hay resultado.

Qwen-Agent resuelve esto con SplitQueryThenGenKeyword: antes de buscar,
un LLM ligero expande la query en sinónimos y términos técnicos relacionados.

## Solución

Paso pre-búsqueda en el flujo de `/memory-recall` y `memory-agent`:

```
Query original: "qué pasa con el login"
  ↓ LLM (haiku, ~50 tokens)
Keywords expandidos: ["login", "autenticación", "auth", "JWT", "sesión",
                      "credenciales", "token", "OAuth"]
  ↓ Búsqueda en JSONL con OR lógico
Resultados combinados → ranking por frecuencia de hit
```

## Implementación

En `scripts/memory-store.sh`, nueva función `expand_keywords`:

```bash
expand_keywords() {
  local query="$1"
  claude -p "Expand this search query into 5-8 related technical keywords.
  Output only: keyword1, keyword2, ... (comma separated, lowercase)
  Query: $query" --model claude-haiku-4-5-20251001
}
```

Integrar en `memory_recall()` como paso 0 cuando la query tiene < 5 palabras.

## Degradación

Si `claude` no disponible → usar query original sin expansión (comportamiento actual).
Si expansión tarda > 3s → timeout, usar query original.

## Tests

- "login" → expande a ≥5 términos relacionados
- Query larga (>5 palabras) → NO se expande (innecesario)
- Timeout de expansión → fallback graceful a query original
- Recall@3 mejora ≥15% vs baseline en test set de 20 queries
