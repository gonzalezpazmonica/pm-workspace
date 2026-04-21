# Batch 20 — SE-033 Slice 2 topic-cluster skill

**Date:** 2026-04-22
**Branch:** `agent/batch20-se033-bertopic-skill-20260421`
**Version bump:** 5.68.0

## Summary

Cuarto champion Tier 3 (post-SE-061, SE-035, SE-032). Clustering temático cross-project via BERTopic (UMAP+HDBSCAN+c-TF-IDF) con labels auto-generados. Fallback keyword robusto cuando ML stack ausente.

## Added

- `scripts/topic-cluster.py`:
  - Stdin→stdout wrapper para JSON clustering
  - 2 backends con graceful degradation:
    - `bertopic` (via `bertopic` + `sentence-transformers` + `all-MiniLM-L6-v2`)
    - `fallback-keyword` (conteo de palabras + stopwords filtering)
  - Flags: `--min-cluster-size`, `--nr-topics`, `--json`
  - Exit codes: 0 (OK), 1 (parse/insufficient), 2 (usage)
  - Stdout del model loading redirigido a stderr

- `.claude/skills/topic-cluster/SKILL.md` + `DOMAIN.md`:
  - Invocación: `cat retros.json | python3 scripts/topic-cluster.py --min-cluster-size 3`
  - Integración con retro-patterns, backlog-patterns, lesson-extract, incident-correlate
  - Métrica éxito SE-033: >=3 clusters útiles sobre 50+ docs reales
  - Costes documentados (200MB sbert + 800MB RAM con BERTopic)

- `tests/test-topic-cluster.bats` (37 tests certified):
  - Script existence + shebang + executable
  - Input validation (empty, invalid JSON, <3 docs, missing id/text, non-list)
  - Happy path (6 docs clustering, latency field, --json pretty, outliers always)
  - Fallback contract (funciona sin BERTopic, groups by shared keyword)
  - Skill structure (name, references, UMAP/HDBSCAN keywords)
  - Coverage (fallback_keyword_cluster, try_bertopic, ImportError)
  - Edge cases (zero docs, boundary min-cluster=2, empty text, nr-topics null)
  - Isolation

## Changed

- `CLAUDE.md`: skills count 81 → 82

## Compliance

- Rule #8: Slice 2 sobre SE-033 spec PROPOSED. Wrapper + skill + tests
- Validación funcional: fallback-keyword sobre 6 docs (3 sprint + 3 pr-review) produjo 2 clusters correctos
- Zero egress runtime (solo 1 download de sbert si BERTopic activo)

## Roadmap Tier 3 status

1. ✅ SE-061 Scrapling (batches 14-17, 4 slices, 103 tests)
2. ✅ SE-035 Mutation testing Slice 2 (batch 18, 33 tests)
3. ✅ SE-032 Reranker Slice 2 (batch 19, 36 tests)
4. ✅ SE-033 BERTopic Slice 2 (this batch, 37 tests)
5. ⏳ SE-028 Oumi training pipeline
6. ⏳ SE-041 Memvid backup workflow

## Referencias

- Spec: `docs/propuestas/SE-033-topic-cluster-skill.md`
- Probe: `scripts/bertopic-probe.sh` (batch 9)
- Roadmap: `docs/ROADMAP.md` §Era 183 Tier 3 Champions
