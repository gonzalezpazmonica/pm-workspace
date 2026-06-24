---
status: APPROVED
---

# SPEC-199 — Self-Conditioning Between Tribunal Rounds

> **Priority:** P2 · **Estimate (human):** 4-5d · **Estimate (agent):** 5-7h · **Category:** standard · **Type:** governance-extension

> **Dual estimate**: 4-5 dias humano (extender SPEC-189 embeddings, integrar con SPEC-195 iteracion, tests). 5-7h agente.

## Objective

Cuando un draft entra al Recommendation Tribunal y vuelve a entrar (caso SPEC-195 iterative), la **segunda iteracion no sabe nada de la primera**. El draft regenerado se evalua como si fuera nuevo — los jueces no tienen contexto del por que la version anterior fue WARN.

DiffusionGemma usa `SelfConditioning`: en cada paso de denoising, los embeddings del paso anterior se pasan como senal al transformer. El primer paso recibe ceros (flag `is_zero_sc`). Los siguientes ven la trayectoria. Esto **reduce el coste cuadratico de mantener historia textual completa** a coste lineal en embeddings densos.

Esta spec aplica el patron a tribunales iterativos: en lugar de reinyectar el texto del draft anterior + razones de los jueces (caro en tokens), comprimir esa historia a embeddings y pasarla como contexto vectorial. SPEC-189 ya tiene infra de embeddings por nodo de grafo — extension natural.

Trade-off honesto: **es ingenieria especulativa**. Anthropic API no acepta embeddings como input directo (el modelo generador es texto-in/texto-out). Lo que SI puedo hacer:
1. Calcular embedding del draft anterior + verdict de jueces.
2. Buscar en KG los **K drafts mas similares** que tuvieron iteraciones similares.
3. Inyectar como context: "drafts similares en la historia tuvieron veredicto X, evolucionaron a Y, el patron Z funciono."

Eso NO es self-conditioning literal (el modelo recibe texto, no embeddings). Es **conditioning via similarity search**: el equivalente operacional para LLMs cerrados via API. Mas honesto: lo llamamos "historical-context-conditioning" en lugar de self-conditioning.

## Principles affected

- **#3 Reversible** — Opt-in. Default off durante pilot.
- **#5 Truth as common good** — Llamarlo "self-conditioning" cuando no lo es seria deshonesto. Renombrado.
- **#7 Resource efficiency** — Reduce tokens vs reinyectar texto completo.

## Design

### Overview

```
[Iteracion N+1 del tribunal]
    |
    v
[Calcular embedding(draft_N + verdict_N)]
    |
    v
[KG similarity search: top-K drafts mas similares en history]
    |
    v
[Inyectar al prompt del juez: "drafts similares evolucionaron asi: ..."]
    |
    v
[Juez emite verdict mas calibrado por contexto historico]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/recommendation-tribunal/historical-context.py` | py script | Calcula embedding + busca top-K en KG |
| 2 | KG schema migration | sql | Anade tabla `tribunal_iterations` con (draft_hash, embedding, verdict, evolution) |
| 3 | Modificar SPEC-195 `iterate.sh` | extension | Llama a historical-context.py antes de cada iteracion N+1 |
| 4 | `scripts/embeddings-cache.py` | py script | Cache de embeddings calculados (sentence-transformers local) |
| 5 | Tests pytest `tests/scripts/test_historical_context.py` | tests | Similarity threshold, top-K boundaries |

### Contracts

#### historical-context.py

```bash
python3 scripts/recommendation-tribunal/historical-context.py     --draft "<text>"     --verdict-json <file>     --top-k 3     --similarity-threshold 0.6

# Output JSON:
# {
#   "similar_drafts": [
#     {"hash": "abc...", "similarity": 0.78, "verdict": "WARN->PASS in 2 iter",
#      "summary": "Spec was WARN due to vague AC, became PASS by adding Given/When/Then."}
#   ],
#   "context_text": "Drafts simlares...",
#   "tokens_estimate": 450
# }
```

#### KG schema migration

```sql
CREATE TABLE IF NOT EXISTS tribunal_iterations (
    iteration_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    iteration_n INTEGER NOT NULL,
    draft_hash TEXT NOT NULL,
    draft_text TEXT,
    verdict TEXT,
    score_avg REAL,
    embedding BLOB,
    final_verdict TEXT,
    evolution_summary TEXT,
    ts TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_tribunal_iterations_hash ON tribunal_iterations(draft_hash);
```

Embedding: `BLOB` con sentence-transformers `all-MiniLM-L6-v2` (384 dims, 1.5 KB por draft). Local, sin API externa.

### Configuration

```bash
SAVIA_TRIBUNAL_HIST_CONTEXT=on|off              # default off durante pilot
SAVIA_TRIBUNAL_HIST_TOP_K=3
SAVIA_TRIBUNAL_HIST_SIMILARITY_MIN=0.6
SAVIA_TRIBUNAL_HIST_MAX_TOKENS=500              # cap del contexto inyectado
SAVIA_TRIBUNAL_HIST_DB=~/.savia/tribunal-iterations.db
```

## Acceptance criteria

1. `historical-context.py --draft "X" --top-k 0` retorna `{similar_drafts: []}`.
2. KG vacio: `--top-k 3` retorna `{similar_drafts: []}` sin error.
3. KG con 1 entrada similar (cosine_sim > 0.6): retorna 1.
4. KG con 5 entradas similares: retorna top-3 ordenadas por similarity desc.
5. Similarity threshold respetado: entradas con sim < 0.6 NO incluidas.
6. Embedding determinista: mismo draft -> mismo embedding (modelo seed).
7. Cache: segunda llamada con mismo draft NO recomputa.
8. Schema migration idempotente: ejecutar 2 veces no rompe.
9. `tokens_estimate` del context <= `SAVIA_TRIBUNAL_HIST_MAX_TOKENS`.
10. Privacy: drafts con etiqueta `confidential=true` NO se persisten en KG.
11. Tests: 8 casos cubriendo formula + boundary + privacy.
12. Latencia: lookup top-K en KG con 1000 entradas <= 200ms.

## Out of scope

- Embeddings via Anthropic/OpenAI API (caro, requiere red). Solo sentence-transformers local.
- Aprendizaje activo (re-entrenar embeddings con feedback). Solo inferencia.
- Cross-session sharing: cada session tiene su propio scope. Compartir entre sessiones requiere consentimiento explicito.

## Dependencies

- Blocked by: SPEC-195 (sin iteracion no hay valor).
- Blocked by infra: sentence-transformers instalado (ya esta en `requirements-vector.txt` opcional via SPEC-018).
- Related: SPEC-189 (greedy budget — comparte infra de embeddings), SE-162 (KG).

## Migration path

| Semana | Cambio |
|---|---|
| 1 | Componentes 1-5. Modo off. |
| 2 | Activar en piloto: 1 spec sintetico que itera. |
| 3 | Telemetria: medir cambio en convergence_rate y quality. |
| 8 | Si convergence_rate +10%, promover a default. Si neutral, mantener off. |

## Reference code

Patron Gemma `_transformer.py`:

```python
sc_signal = self.ffw(self.pre_norm(self_conditioning_signal))
combined = canvas_embeddings + sc_signal
result = self.post_norm(combined)
```

En el primer paso, `sc_signal` es zero (flag `is_zero_sc`). Los siguientes ven la trayectoria.

Adaptado a Savia (no neuronal, via similarity search):

```python
def historical_context(draft: str, top_k: int = 3) -> dict:
    if not previous_iterations_exist():
        return {"similar_drafts": [], "context_text": ""}
    emb = compute_embedding(draft)
    candidates = kg.search_similar(emb, top_k=top_k, threshold=0.6)
    context = build_prompt_context(candidates)
    return {"similar_drafts": candidates, "context_text": context}
```

## Impact statement

Speculativa. **Beneficio probable** si convergence_rate del SPEC-195 mejora con contexto historico. **Beneficio nulo** si los jueces ignoran el contexto inyectado. Decision tras 30d de telemetria.

Coste no trivial: embedding model local (200MB), KG storage incremental (~1.5KB/iteracion), latencia de lookup. Justificable solo si SPEC-195 demuestra valor primero.

Honesto: si SPEC-195 no se promueve a default, SPEC-199 tampoco. Estan acopladas.

Origen: patron `SelfConditioning` en DiffusionGemma `_transformer.py`. Renombrado a "historical-context-conditioning" porque la implementacion no es neuronal (LLM cerrado via API).

## OpenCode Implementation Plan

**Classification**: Tier 2 (depende de SPEC-195).

### Phase 1 — Helpers + cache (semana 1)

1. `scripts/embeddings-cache.py` con sentence-transformers.
2. KG schema migration `kg-schema-migrate-tribunal.py`.
3. Tests pytest del cache + schema.

### Phase 2 — historical-context (semana 2)

4. `scripts/recommendation-tribunal/historical-context.py`.
5. Tests pytest 8+ casos.

### Phase 3 — Integracion SPEC-195 (semana 3)

6. Modificar `iterate.sh` (de SPEC-195) para llamar historical-context.py si activo.
7. Tests bats end-to-end.

### Phase 4 — Pilot + telemetria (semana 4-8)

8. Activar en flujo piloto.
9. Medir delta convergence + delta quality.
10. Promover o desinstalar segun datos.

### Risks

- **sentence-transformers download**: 200MB. Mitigacion: skip si infra no disponible (fail-soft).
- **Embeddings de drafts confidenciales en KG**: privacy. Mitigacion: AC-10, etiqueta confidential=true skipea persistencia.
- **Inyeccion de contexto historico altera el sesgo del juez**: el juez puede acomodarse al patron historico ("siempre fue asi, debe ser asi"). Mitigacion: telemetria mide variabilidad de scores; si baja drasticamente, alerta.
- **SPEC-195 nunca se promueve**: SPEC-199 queda huerfana. Mitigacion: marcar como blocked-by SPEC-195 explicito.
