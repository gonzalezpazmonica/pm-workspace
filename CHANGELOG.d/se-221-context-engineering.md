---
version_bump: minor
section: Performance
---

### Performance

- se-221: Context Origin Tagging — PostToolUse hook prefija outputs de Read >200 lineas con bloque YAML `---origin` (path, tier N1-N5, hash, tokens). Trazabilidad cuando un fichero se mueve.
- se-221: Drop-After-Use — Hook PostToolUse para Read/WebFetch/Bash decide KEEP/STUB/DROP segun tier y next-task. Stub reemplaza outputs irrelevantes por `<stub origin="..." abstract="..."/>`. Ataque directo al context bloat.
- se-221: Override `KEEP-CONTEXT` — usuario puede forzar KEEP en el siguiente turno cuando necesita re-leer un stub.
- se-221: Capability Metadata `audience:` — frontmatter opcional en docs/skills (default implicito `all-agents`). Subagentes filtrados por audience-graph: deny by default sobre fragmentos audience-restringido.
- se-221: Audience-Cross Graph — `scripts/context-audience-graph.py` produce TSV de pares con >=2 agentes compartidos en audience. Evidencia de conexiones cross-concept entre fragmentos no obviamente relacionados.
- se-221: Knowledge Graph integracion — `scripts/knowledge-graph.py import-audience` ingiere el TSV como relacion tipada `(path_A) -[shared_audience]-> (path_B)` con `count` y agentes en `source`.
- se-221: Metrics CLI — `scripts/context-drop-metrics.sh` reporta `total_tokens_saved`, `n_stubs`, `n_keeps`, `pct_saved` desde `output/context-drop-audit.jsonl`.
- se-221: Capability Metadata extractor — `scripts/context-capability-metadata.py --file <path>` produce JSON `{origin, tier, audience, size_tokens, hash, last_loaded, cross_concept_refs}`. cross_concept_refs extrae SPEC-N, SE-N, Rule #N del contenido. Audience fallback `all` si sin frontmatter.
- se-221: Tests — `tests/scripts/test_se221_context_patterns.py` (29 pytest) + `tests/bats/test-se-221-patterns.bats` (17 bats). 46 tests en verde.
