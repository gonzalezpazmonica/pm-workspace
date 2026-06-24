---
status: IMPLEMENTED
implemented_at: "2026-06-24"
resource: https://github.com/CarlosVallejoRuiz/slurp
timeline:
  - from: "2026-06-24"
    learned: "2026-06-24"
    value: "IMPLEMENTED"
    source: "session:2026-06-24"
---
# SPEC-189 — Greedy Context Budget Selection

> **Priority:** P1 · **Estimate (human):** 3d · **Estimate (agent):** 3h · **Category:** standard · **Type:** infrastructure

> **Dual estimate**: 3 días humano end-to-end (algoritmo + tres adaptadores + tests + integración con `agent-code-map` + docs). 3 horas wall-clock con pipeline agente. Formula `agent_hours ≈ human_days` aplica al ser standard. Detalles en `@docs/rules/domain/dual-estimation.md`.

## Objective

Cuando un agente Savia carga un grafo de contexto (`.acm`, knowledge-graph SQLite, JSONL, INDEX.acm) entero, consume 20-100K tokens de los que <10% son relevantes para la tarea actual. Esta spec añade `scripts/context-greedy-budget.py` — un selector que dado (grafo, query, budget) devuelve el subgrafo más relevante que cabe en el presupuesto. **Inspiración**: patrón scoring + greedy budget + neighbor decay observado en [CarlosVallejoRuiz/slurp](https://github.com/CarlosVallejoRuiz/slurp). **No adopción**: re-implementación stdlib-only sin deps externas y con adaptadores propios para los formatos de Savia. Cero vendor lock-in.

Trade-off honesto: el algoritmo greedy es myopic (no resuelve knapsack óptimo). Para los tamaños de grafo de Savia (<5K nodos/proyecto) la diferencia con óptimo es <5%. Si en el futuro hay grafos de 10K+ nodos, se itera a knapsack relajado o ILP.

## Principles affected

- **#1 Data sovereignty** — El selector opera sobre datos locales (`.acm`, KG SQLite). Cero llamada externa.
- **#2 Vendor independence** — stdlib pura. `tiktoken` opcional con fallback heurístico (1 token ≈ 4 chars). Cero dep en `slurp`, `numpy`, `sklearn`, `networkx`, `tiktoken` obligatorio.
- **#3 Reversible** — Es un script puro: `rm scripts/context-greedy-budget.{py,sh}` y revertir hooks lo elimina sin daño.
- **#5 Humans decide** — Devuelve subgrafo + razonamiento (`--explain`). El agente o el humano deciden qué hacer con él.

## Design

### Overview

Pipeline lineal con adaptadores intercambiables:

```
[input source] → adapter → graph(nodes, edges, attrs)
                                    ↓
                                  scorer ← query
                                    ↓ scores: {id: float}
                                  budget(greedy + neighbor-decay)
                                    ↓ subgraph
                                  formatter(markdown|json|jsonl)
                                    ↓
                                  stdout
```

El núcleo `core` es agnóstico al formato. Los adaptadores son funciones puras `path → graph_dict`.

### Components

| Name | Kind | Purpose |
|------|------|---------|
| `scripts/context-greedy-budget.py` | python script | Núcleo: scorer + greedy budget + 3 adaptadores |
| `scripts/context-greedy-budget.sh` | bash wrapper | UX consistente con resto de scripts Savia |
| `tests/python/test_context_greedy_budget.py` | pytest | Unit tests del algoritmo (15+ tests) |
| `tests/bats/test-context-greedy-budget.bats` | bats | Smoke tests CLI + adaptadores |

### Contracts

#### CLI

```bash
context-greedy-budget.sh <input> <query> [--budget N] [--format FMT] [--input-format FMT] [--min-score X] [--neighbor-decay D] [--explain]
```

Argumentos:

| Flag | Default | Descripción |
|---|---|---|
| `<input>` | — | Path a fichero o DB. Auto-detect por extensión: `.acm` → adapter ACM, `.db` → adapter KG-SQLite, `.jsonl`/`.json` → adapter JSONL-graph. |
| `<query>` | — | String libre. Tokenizado interno splitea camelCase y snake_case. |
| `--budget` | `4000` | Token budget para el subgrafo seleccionado. |
| `--format` | `markdown` | `markdown` \| `json` \| `jsonl` (1 línea por nodo). |
| `--input-format` | auto | Override del adaptador (`acm`, `kg-sqlite`, `jsonl-graph`). |
| `--min-score` | `0.15` | Pre-filtro: nodos con score < min se descartan antes del greedy. |
| `--neighbor-decay` | `0.7` | Factor multiplicativo aplicado a vecinos del nodo seleccionado. |
| `--explain` | off | Imprime tabla `id | score_final | structural | semantic` post-output. |
| `--token-counter` | `heuristic` | `heuristic` (4 chars/token) o `tiktoken` (si lib disponible). |

Salida: stdout con markdown/json/jsonl. Exit code 0 si OK, 2 si grafo vacío, 3 si input no válido.

#### Algoritmo de scoring

```
score(node, query) = α · structural(node) + β · semantic(node, query) + boost(node)

donde:
  structural(node)     = pagerank_normalizado(node)  ∈ [0,1]
  semantic(node, query) = tfidf_cosine(node.text, query)  ∈ [0,1]
  boost(node)          = +0.3 si node.kind == 'code' else 0  (clamp a 1.0)
  α = 0.4, β = 0.6
```

PageRank power-iteration sin numpy (ver §Reference code). TF-IDF con IDF smoothed `log((N+1)/(df+1)) + 1` y cosine similarity, restringido a tokens de la query. Tokenizer: split camelCase, snake_case, kebab-case, espacios; lowercase.

#### Algoritmo de selección (greedy + neighbor decay)

```
1. candidates = {n: score(n, q)} filter score >= min_score
2. effective = copy(candidates)
3. processed = ∅
4. selected = []
5. tokens_used = 0
6. while processed != candidates:
     best = argmax(effective[n] for n in candidates - processed)
     processed.add(best)
     cost = token_count(serialize(best))
     if cost <= budget - tokens_used:
       selected.append(best)
       tokens_used += cost
       boosted = effective[best] * neighbor_decay
       for nbr in neighbors(best) ∩ (candidates - processed):
         effective[nbr] = max(effective[nbr], boosted)
     if tokens_used >= budget: break
7. return induced_subgraph(selected), stats
```

Garantías:
- Determinismo: con la misma input, query y semilla aleatoria devuelve el mismo subgrafo. (Sin aleatoriedad real; ties por id alfabético.)
- `tokens_used <= budget` siempre.
- `coverage_pct = nodes_selected / nodes_total * 100` reportado en stats.

#### Adaptadores (entrada → grafo canónico)

Forma canónica:

```python
{
    "nodes": {
        "<id>": {
            "label": str,
            "text": str,           # texto para semantic scoring
            "kind": str,           # 'code' | 'doc' | 'entity' | ...
            "neighbors": [<id>, ...],
            "extra": dict          # campos opcionales (file_path, line, ...)
        },
        ...
    }
}
```

Adaptadores:

| Adapter | Input | Mapping |
|---|---|---|
| `acm` | `.acm` markdown | Cada heading `## NombreEntidad` o `### NombreClase` → nodo. text = línea heading + descripción. neighbors = referencias `@include foo.acm` o `→ Bar` en el cuerpo. |
| `kg-sqlite` | `~/.savia/knowledge-graph.db` | `SELECT id, name, type, description FROM entities`; neighbors via `relations`. |
| `jsonl-graph` | `.jsonl` o `.json` | Compatible con formato graphify-like: `{"nodes": [...], "edges": [...]}`. |

### Configuration

Cero configuración global obligatoria. Opt-in.

Variable de entorno opcional:

```bash
CGB_DEFAULT_BUDGET=4000           # defecto si no se pasa --budget
CGB_TOKEN_COUNTER=heuristic       # 'heuristic' | 'tiktoken'
```

No se añade entrada en `.claude/settings.json` ni hooks. Es un script standalone.

## Acceptance criteria

1. **Algoritmo determinista**: ejecutar el mismo (input, query, budget) dos veces produce output byte-idéntico. Verificado por `tests/python/test_context_greedy_budget.py::test_deterministic`.
2. **Budget respetado**: para todo (input, query, budget) válido, `tokens_used <= budget`. Verificado por `test_budget_never_exceeded` con 50 inputs aleatorios de fixtures.
3. **PageRank sin numpy**: `python3 -c "import numpy; numpy.x"` falla pero `bash scripts/context-greedy-budget.sh fixture.jsonl 'q'` funciona. Verificado por `test-no-numpy.bats`.
4. **Adaptador ACM**: dado `tests/fixtures/sample.acm` con 10 entidades y query `"entity"`, devuelve subset con score>0 ordenado descendente. Verificado por `test_acm_adapter`.
5. **Adaptador KG-SQLite**: dado `tests/fixtures/kg-sample.db` con 20 entidades, devuelve subgrafo conectado por `relations`. Verificado por `test_kg_sqlite_adapter`.
6. **Adaptador JSONL**: dado fixture compatible graphify, devuelve subgrafo. Verificado por `test_jsonl_adapter`.
7. **Neighbor decay**: si seleccionas nodo `A` con score 0.9 y `decay=0.7`, vecino `B` con score original 0.3 termina con effective_score=0.63 (max de 0.3 y 0.9·0.7). Verificado por `test_neighbor_decay_boost`.
8. **Min-score filter**: con `--min-score 0.5`, ningún nodo seleccionado tiene score original < 0.5. Verificado por `test_min_score_filter`.
9. **Tokenizer camelCase/snake_case**: `_tokenize("calcularPlayerStats")` devuelve `["calcular", "player", "stats", "calcularplayerstats"]`. Verificado por `test_tokenize_camel_snake`.
10. **Code boost clamped**: nodo con `kind='code'` y score base 0.85 termina en 1.0 (no 1.15). Verificado por `test_code_boost_clamp`.
11. **Empty graph**: input vacío → exit code 2 con mensaje claro a stderr. Verificado por bats.
12. **Format outputs**: `--format json` produce JSON parseable; `--format jsonl` produce N líneas válidas; `--format markdown` contiene `## Selected Nodes`. Verificado por bats con `jq` y `grep`.
13. **--explain table**: imprime tabla con columnas `id | score | structural | semantic | tokens`. Verificado por bats con `grep -E`.
14. **Cobertura tests >=80%**: `pytest --cov=context_greedy_budget` reporta >=80%. Verificado por CI step.
15. **Smoke real**: ejecutar contra `projects/savia-mobile-android/.agent-maps/INDEX.acm` con query `"chat"` y budget `1000` retorna subset y completa en <2s. Verificado por bats.
16. **Sin lock-in**: `grep -rE "import (slurp|networkx|numpy|sklearn|tiktoken)" scripts/context-greedy-budget.py` devuelve solo `import tiktoken` dentro de un `try/except` (opt-in). Verificado por bats.

## Out of scope

- Visualización HTML interactiva del subgrafo (slurp `--viz`). No la necesitamos hoy.
- Servidor MCP que exponga `context_query` como tool. Si se necesita, se hace en spec aparte usando este como dependencia.
- Embeddings reales (OpenAI / Anthropic backends). TF-IDF basta para grafos <5K nodos. Si insuficiente, se añade en spec aparte.
- Diff entre versiones de grafo (slurp `diff`). No es problema actual.
- Auditoría de queries en JSONL append-only. Si se necesita, lo añade `agent-code-map` como skill consumidor, no este script.
- Code injection (extraer cuerpos de funciones). Otra spec si se decide.
- Integración automática con `agent-code-map`. Esta spec entrega el script; la integración la hace una spec posterior cuando midamos beneficio en proyectos reales.

## Dependencies

- Blocked by: ninguno.
- Blocks: posible "SPEC-XXX agent-code-map budget-aware loading" (futura, no bloqueante).
- Related: SE-162 (knowledge-graph) — adaptador KG-SQLite consume su DB.

## Migration path

No hay migración. Es script nuevo, opt-in. Para retirar: `rm scripts/context-greedy-budget.{py,sh} tests/python/test_context_greedy_budget.py tests/bats/test-context-greedy-budget.bats`.

## Reference code

PageRank power-iteration sin numpy (canónico, reusable):

```python
def pagerank(nodes, edges_out, alpha=0.85, max_iter=100, tol=1e-6):
    N = len(nodes)
    if N == 0: return {}
    rank = {n: 1.0/N for n in nodes}
    out_w = {n: max(1, len(edges_out.get(n, []))) for n in nodes}
    dangling = [n for n in nodes if not edges_out.get(n)]
    edges_in = {n: [] for n in nodes}
    for u, outs in edges_out.items():
        for v in outs:
            edges_in.setdefault(v, []).append(u)
    for _ in range(max_iter):
        prev = dict(rank)
        dsum = alpha * sum(prev[n] for n in dangling) / N
        for n in nodes:
            inc = sum(prev[u] / out_w[u] for u in edges_in.get(n, []))
            rank[n] = alpha * inc + dsum + (1.0 - alpha) / N
        if sum(abs(rank[n] - prev[n]) for n in nodes) < N * tol:
            break
    return rank
```

TF-IDF cosine restringido a tokens de query (canónico):

```python
def tfidf_scores(docs, query):
    import math
    from collections import Counter
    q_tokens = tokenize(query)
    if not q_tokens or not docs: return {nid: 0.0 for nid in docs}
    N = len(docs)
    idf = {}
    for term in set(q_tokens):
        df = sum(1 for tok in docs.values() if term in set(tok))
        idf[term] = math.log((N + 1) / (df + 1)) + 1
    q_tf = Counter(q_tokens)
    q_vec = {t: (c/len(q_tokens))*idf[t] for t, c in q_tf.items()}
    q_norm = math.sqrt(sum(v*v for v in q_vec.values()))
    scores = {}
    for nid, tokens in docs.items():
        if not tokens: scores[nid] = 0.0; continue
        d_tf = Counter(tokens)
        d_vec = {t: (d_tf[t]/len(tokens))*idf[t] for t in idf if d_tf[t] > 0}
        d_norm = math.sqrt(sum(v*v for v in d_vec.values()))
        scores[nid] = (sum(q_vec[t]*d_vec[t] for t in d_vec) / (q_norm*d_norm)) if d_norm else 0.0
    return scores
```

## Impact statement

Reduce 50-90% de tokens cargados cuando un agente consulta un grafo de contexto bajo presupuesto, manteniendo precision >= 70% sobre nodos top-relevantes. Habilita que `agent-code-map` y `knowledge-graph` se usen en proyectos grandes sin saturar contexto. Pone en Savia el patrón de scoring + greedy budget + neighbor decay como infraestructura reusable, sin atarse al ecosistema de slurp.

## OpenCode Implementation Plan

> Required post-2026-04-26 (per `docs/rules/domain/spec-opencode-implementation-plan.md`).

**Classification**: Tier 1 — script standalone, sin frontend específico, sin dependencia de agentes Claude Code.

### Phase 1 — Core algorithm (pytest TDD)

1. Crear `scripts/context-greedy-budget.py` con:
   - Funciones puras: `tokenize`, `pagerank`, `tfidf_scores`, `compute_scores`, `select_subgraph`.
   - Token counter con fallback (heuristic 4-chars-per-token + opt-in tiktoken).
   - `from __future__ import annotations`, type hints, docstrings completos.
2. Tests unitarios `tests/python/test_context_greedy_budget.py`:
   - `test_tokenize_camel_snake`, `test_pagerank_converges`, `test_tfidf_basic`.
   - `test_score_combines_alpha_beta`, `test_code_boost_clamp`.
   - `test_select_respects_budget`, `test_neighbor_decay_boost`, `test_min_score_filter`.
   - `test_deterministic` (run 2x, byte-equal output).
3. Pasar `pytest tests/python/test_context_greedy_budget.py -v` con 15+ tests verdes.

### Phase 2 — Adaptadores

4. Implementar `adapter_acm(path) -> graph_dict` parseando markdown headings.
5. Implementar `adapter_kg_sqlite(path) -> graph_dict` con `sqlite3` stdlib.
6. Implementar `adapter_jsonl_graph(path) -> graph_dict` para formato graphify-compatible.
7. Tests con fixtures en `tests/fixtures/`:
   - `sample.acm` (manual, 10 entidades).
   - `kg-sample.db` (generado por test setUp).
   - `sample-graph.jsonl` (manual, 8 nodos).

### Phase 3 — CLI + wrapper bash

8. Argparse en `context-greedy-budget.py`: `<input>`, `<query>`, `--budget`, `--format`, `--input-format`, `--min-score`, `--neighbor-decay`, `--explain`, `--token-counter`.
9. Auto-detect adaptador por extensión del input.
10. Wrapper `scripts/context-greedy-budget.sh` con `set -uo pipefail` y forward de argumentos.
11. Smoke test BATS `tests/bats/test-context-greedy-budget.bats` con fixtures + grafo real `INDEX.acm`.

### Phase 4 — Documentación

12. Actualizar `docs/agents-skills-pages/scripts.md` (si existe) con entrada del script.
13. Añadir entrada en `docs/critical-facts.md` lazy reference si procede (decisión: probablemente NO, es script de uso ocasional, no L1).
14. README breve en cabecera del script (docstring del módulo).

### Phase 5 — Validación end-to-end

15. Ejecutar contra 3 grafos reales:
    - `projects/savia-mobile-android/.agent-maps/INDEX.acm`.
    - `~/.savia/knowledge-graph.db` (si existe).
    - JSONL sintético generado por test.
16. Confirmar: tiempo <2s, output bien formado, savings >=50% vs full graph para query no-trivial.
17. Commit con mensaje `feat(context): SPEC-189 greedy context budget selection`.

### Acceptance criteria checklist (mapping)

| AC | Phase | Verifier |
|---|---|---|
| 1, 2, 7, 8, 9, 10 | 1 | pytest |
| 4, 5, 6 | 2 | pytest |
| 11, 12, 13 | 3 | bats |
| 3, 16 | 1+3 | bats `test-no-numpy` y `grep` |
| 14 | 1 | pytest --cov |
| 15 | 5 | bats smoke real |

### Risks

- **Ridge en adaptador ACM**: parsing markdown ad-hoc puede fallar con `.acm` no estándar. Mitigación: regex defensiva + fallback a "todo el archivo es un nodo" si no detecta headings.
- **PageRank en grafos sparse**: si edges < nodes, PageRank tiende a uniforme. Esperado y aceptable: la componente structural pesa solo 0.4.
- **Performance en grafos >10K nodos**: PageRank O(N·iters·E). Para 10K nodos, ~5s. Aceptable hoy. Si crece, optimizar con sparse matrix opcional vía numpy bajo `try/except`.
