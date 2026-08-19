# SCL-005 — Embeddings híbridos para la divergencia (IMPLEMENTED)

**Status:** PROPOSED → IMPLEMENTED (2026-08-17) · desbloqueada por infra
**Fecha:** 2026-08-17
**Area:** Memoria / Búsqueda híbrida / ADR-003 Fase 4
**Branch:** agent/scl-001-aprendizaje-continuo
**Bloqueo resuelto:** venv `~/.savia/venv` con sentence-transformers 5.7.0 + faiss-cpu 1.14.2 + numpy 2.5.2

---

## Qué es

**Embeddings híbridos** (BM25 + vectorial) para el recall de lecciones de la
cúpula SaviaLearning. El recall BM25 puro (SCL-003) no matchea sinónimos
("token de acceso" → lección sobre PAT). El híbrido añade recuperación semántica
(modelo all-MiniLM-L6-v2, local — ADR-012, cero vendor names).

## Implementación (2026-08-17)

- **Dependencias instaladas**: venv aislado `~/.savia/venv` (no toca el python
  del sistema) con sentence-transformers 5.7.0, faiss-cpu 1.14.2, numpy 2.5.2 y
  Torch 2.8.0 CPU-only. Aprobado por la operadora (~2GB). Modelo
  all-MiniLM-L6-v2 (384-dim, local).
- **`scripts/learning-hybrid.py`**: fusión determinista
  `hybrid = w_lex·lex + w_sem·sem` (default 0.4/0.6). `lex` = overlap léxico
  query↔doc; `sem` = similitud coseno del embedding. Degradación elegante: sin
  venv → solo léxico (equivalente a BM25 puro).
- **`learning-recall.sh --hybrid`**: en modo híbrido, lista las lecciones del
  dir de la cúpula como candidatos (sin depender del índice BM25, que no
  matchea sinónimos) y las re-rankea con `learning-hybrid.py`. Los candidatos
  usan texto completo (no truncado).

## Acceptance criteria

- AC-1. `learning-recall.sh --hybrid` fusiona resultados BM25 + vectorial
  (test).
- AC-2. Recall semántico recupera sinónimos (p. ej. "token de acceso" → lección
  sobre PAT) que BM25 solo no encuentra (test, validado en producción).
- AC-3. Degradación elegante: sin venv/embeddings, cae a léxico puro sin fallar
  (test).
- AC-4. El recall BM25 puro (sin `--hybrid`) sigue funcionando (test).
- AC-5. `--hybrid` registra en el log de utilidad (test).

## Validación en producción (2026-08-17)

Query "necesito el token de acceso para conectarme a Azure" → el recall híbrido
rankeó la lección PAT (`LP-...-ed0f9efb`, score 0.1228) como top; el BM25 puro
no la recuperaba con ese query (sinónimo). La recuperación semántica funciona.

## Referencias

- ADR-003 (Fase 4): embeddings híbridos
- SPEC-018: `memory-vector.py`, `embedding-server.py`
- SCL-003: recall BM25 operativo (base del híbrido)
- Scripts: `scripts/learning-hybrid.py`, `scripts/learning-recall.sh --hybrid`
