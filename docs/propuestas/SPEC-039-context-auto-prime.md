# SPEC-039: Context Auto-Priming — Memoria que se Carga Sola

> Status: **APPROVED** · Fecha: 2026-03-24 · Score: 4.9
> Origen: Gap analysis — "architecture exists, automation missing"
> Impacto: De "recuerda cargar contexto" a "el contexto ya esta ahi"

---

## Problema

Savia tiene temporal memory, hybrid search, cognitive sectors, domain
routing, importance scoring — pero TODO requiere invocacion manual.
El usuario debe recordar ejecutar /context-load, /memory-recall, etc.
Si no lo hace, Savia opera sin memoria: cada sesion empieza en frio.

**La memoria que hay que pedir no es memoria — es una base de datos.**
La memoria real se activa sola cuando es relevante.

## Principio

**Transparencia total.** El usuario no debe saber que existe un sistema
de memoria. Simplemente, Savia recuerda lo relevante automaticamente.

## Solucion

Script `context-auto-prime.py` que, dado un prompt/query:
1. Clasifica por dominio (SPEC-038)
2. Busca las top-K memorias por importancia x relevancia x frescura
3. Devuelve un bloque de contexto pre-formateado (max N tokens)
4. Este bloque se inyecta ANTES de procesar el prompt

### Formula de scoring

```
prime_score = (domain_match × 0.35) + (keyword_sim × 0.25)
            + (recency × 0.20) + (importance × 0.20)

domain_match: 1.0 si dominio coincide, 0.3 si no
keyword_sim: overlap de keywords query vs entry (jaccard)
recency: 1.0 si <7d, 0.7 si <30d, 0.4 si <90d, 0.1 si >90d
importance: rev_count / max_rev (entries mas revisadas = mas importantes)
```

### Output format

```
[Context primed: 3 memories from domain "security" (142 tokens)]
- SQL parameterized queries mandatory (2026-03-20, rev:2)
- OWASP Top 10 in security pipeline (2026-03-22, rev:1)
- XSS vulnerability in profile page (2026-03-23, rev:1)
```

### Limites

- Max 5 memorias por prime (evitar pollution)
- Max 300 tokens total (preservar espacio para la tarea)
- Si ninguna memoria tiene prime_score > 0.3 → no primar (silencio)
- Nunca primar en respuestas a /compact, /clear, confirmaciones simples

## Integracion

Se integra con SPEC-038 (domain routing) para el filtro de dominio
y con el memory store (JSONL) para el scoring. No requiere LLM.

## Metricas

- **Prime hit rate**: % de veces que el prime incluye info usada en la respuesta
- **Token overhead**: tokens usados por prime vs tokens de la respuesta
- **Silence rate**: % de queries donde no se prima (deberia ser ~40-60%)

## Esfuerzo

Bajo — 1 sprint. El scoring es aritmetica simple sobre campos JSONL.
La integracion es un pre-filtro antes del prompt principal.
