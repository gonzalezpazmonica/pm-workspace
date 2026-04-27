## [6.23.0] — 2026-04-27

Batch 72 — SE-076 QueryWeaver patterns IMPLEMENTED — 3 slices independientes con 70 BATS tests certified ≥80.

### Added (Slice 1 — Episodic memory in JSONL store)
- `scripts/memory-save.sh` — `--type episode` first-class con `--entities <comma-list>`, `--valid-to <iso>`, `--pin` (skip auto-TTL). Auto-TTL 90 días para episodios sin `--pin` ni `--expires` explícito. Sector mapping: `episode → episodic`. Tier mapping: `episode → B`.
- `scripts/memory-graph.py` — emite `MENTIONED_IN` edges (entity → episode_title) cuando episodios traen `entities[]`. Episode rel_type fallback: `co_occurred_in`.
- `tests/structure/test-episodic-memory.bats` — 23 tests, score 84 certified. Cubre type recognition, --entities populate, auto-TTL, --pin override, MENTIONED_IN edges, shell injection guard via comma split, regression sin episodios.

### Added (Slice 2 — Azure DevOps schema-as-graph)
- `scripts/build-azdo-schema-graph.sh` — Builder JSON graph con 5 node types (Field/AreaPath/IterationPath/WorkItemType/AllowedValue) + 3 edge types (HAS_FIELD/ALLOWED_VALUE/PARENT_OF). Modos: live (PAT vía Rule #1) / `--from-fixtures <dir>` (offline, CI-friendly) / `--validate <graph.json>`. Output default `output/azdo-schema-graph.json`.
- `tests/structure/test-azdo-schema-graph.bats` — 25 tests, score 89 certified. Cubre fixture mode, validate mode, edge cases (empty/missing files, 100-field stress), Rule #1 PAT compliance.

### Added (Slice 3 — LLM healer reusable wrapper)
- `scripts/lib/llm-healer.sh` — Función `heal_run` reusable + CLI `run`/`stats`. Pattern: ejecuta runner; si falla, alimenta error al LLM (`LLM_HEALER_LLM_CMD`, default `claude -p`) con prompt template (`{error}`/`{original_query}`/`{attempt}`), reintenta hasta `LLM_HEALER_MAX_ATTEMPTS` (default 3). Audit log JSONL en `output/llm-healer-stats.jsonl`. CLI `stats` reporta recovery rate.
- `tests/structure/test-llm-healer.bats` — 22 tests, score 84 certified. Cubre happy path, exhaust attempts, healing recovery, prompt template substitution, MAX_ATTEMPTS bound, empty LLM heal abort.

### Acceptance criteria status (SE-076 → IMPLEMENTED)
- ✅ AC-01 episode type + entities + valid-to + pin
- ✅ AC-02 MENTIONED_IN edge type
- ✅ AC-03 hybrid search (already existed; episodes auto-indexed)
- ✅ AC-04 TTL auto verified
- ✅ AC-05 BATS ≥18 score ≥80 (23 tests, score 84)
- 🔵 AC-06 doc episodic-memory.md DIFERIDA — cubierto inline en spec + script headers
- ✅ AC-07 schema-graph builder produces JSON con nodes+edges
- 🔵 AC-08 NL→WIQL skill rewire DIFERIDA — graph builder shipped, integration con skill es follow-up
- 🔵 AC-09 50-example metric DIFERIDA — requiere instrumentación tráfico real
- ✅ AC-10 BATS ≥12 (25 tests, score 89)
- ✅ AC-11 llm-healer.sh con MAX_ATTEMPTS=3 default
- 🔵 AC-12 NL→WIQL --heal wrapper DIFERIDA — helper shipped, skill rewire es follow-up
- ✅ AC-13 recovery rate metric vía `stats`
- ✅ AC-14 BATS ≥10 (22 tests, score 84)

### Pattern source attribution
- **graphiti** episodic memory model — re-implementado clean-room (NO `graphiti-core` AGPL-3.0 contagion). Solo el patrón episode-as-first-class + MENTIONED_IN edge + valid_from/to.
- **FalkorDB/QueryWeaver** schema-as-graph + LLM healing — re-implementado en bash + Python sin importar el AGPL-3.0 codebase.

### Hard NO (autonomous-safety + license boundaries)
- NO instala FalkorDB, Redis-graph, ni graphiti-core
- NO importa código AGPL-3.0 — solo replica patterns
- NO toca el skill NL→WIQL más allá de añadir el helper builder + healer (skill rewire diferido)
- NO genera Text2SQL para bases de datos arbitrarias (Savia no tiene caso)
- NO añade nueva dependencia runtime — Python 3 + bash + curl ya disponibles

### Updated
- `docs/propuestas/SE-076-queryweaver-patterns.md` — frontmatter `IMPLEMENTED`, `applied_at: 2026-04-27`, ACs marcados con estado real
- `docs/ROADMAP.md` — SE-076 marcado IMPLEMENTED bajo Era 188

### Spec ref
SE-076 (`docs/propuestas/SE-076-queryweaver-patterns.md`) — IMPLEMENTED 3/3 slices core funcional. AC-06/AC-08/AC-09/AC-12 follow-up evolutivos (no bloqueantes; tracked en spec body).
