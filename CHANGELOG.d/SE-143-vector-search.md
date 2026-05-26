---
version_bump: minor
section: Added
---

### Added

- SE-143: Vector search activado (sentence-transformers + faiss-cpu). Recall@5: Grep=40% → Vector=90% (+50pp)
- memory-store.sh: nuevo subcomando 'doctor' reporta Level 0/1/2, deps y estado del índice
- install.sh: Step 7 instala requirements-memory.txt con fallback graceful
- session-init.sh: auto-rebuild del índice vectorial en background al arranque

