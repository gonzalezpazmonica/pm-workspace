---
version_bump: minor
section: Added
---

### Added

- SE-410 Savia RAG en SaviaVaults: búsqueda híbrida (BM25 + embeddings locales vía Ollama, RRF) paralela sobre varias cúpulas y consultas, por MCP (`vault_rag`, `vault_rag_status`, `vault_rag_sync`) y CLI (`savia-vaults rag …`). Política dinámica de embeddings (`docs/rules/domain/rag-embedding-policy.md`) y disparador programado `savia-vaults rag sync --all --check`. En savia-docs: recall@10 0,347 → 0,806 y MRR 0,251 → 0,566 frente a `vault_search`.
