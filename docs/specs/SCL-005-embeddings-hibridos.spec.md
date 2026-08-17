# SCL-005 — Embeddings híbridos para la divergencia (BLOQUEADA por infraestructura)

**Status:** PROPOSED — BLOQUEADA (2026-08-17)
**Fecha:** 2026-08-17
**Area:** Memoria / Búsqueda híbrida / ADR-003 Fase 4
**Branch:** agent/scl-001-aprendizaje-continuo
**Bloqueo:** infraestructura — sin sentence_transformers/hnswlib en la máquina

---

## Qué es

SCL-005 iba a añadir **embeddings híbridos** (BM25 + vectorial) para la métrica
de divergencia del bucle (componente de `L`) y para el recall de lecciones. El
recall actual es BM25 puro (texto); el híbrido mejoraría la recuperación
semántica (sinónimos, paráfrasis) en la cúpula SaviaLearning.

## Estado real (verificado 2026-08-17)

- `scripts/embedding-server.py` y `scripts/memory-vector.py` existen (SPEC-018)
  y detectan el nivel de dependencias: `LEVEL=0` (grep only) cuando no hay
  `sentence_transformers`/`hnswlib`.
- **En esta máquina no hay ninguno instalado**: `pip3 list` no muestra
  sentence-transformers, hnswlib, torch ni transformers.
- Instalarlos requiere ~2GB (torch + modelo all-MiniLM-L6-v2) — no se instala
  sin aprobación de la operadora.

## Decisión

**No se implementa un stub ni una versión falsa del recall híbrido.** El bucle
funciona correctamente con BM25 puro (SCL-003, validado en producción con score
111 en el caso PAT). El salto a híbrido es una mejora de recall, no una
necesidad de funcionamiento. Se deja bloqueada hasta que:
1. La operadora apruebe instalar las dependencias (~2GB), o
2. Se use un backend de embeddings remoto (rompería ADR-012 — no recomendado).

## Acceptance criteria (cuando se desbloquee)

- AC-1. `learning-recall.sh --hybrid` fusiona resultados BM25 + vectorial.
- AC-2. Recall semántico recupera sinónimos (p. ej. "clave API" → lección sobre
  PAT) que BM25 solo no encuentra.
- AC-3. `learning-divergence.sh --hybrid` usa similitud coseno para la
  divergencia grafo-modelo.
- AC-4. Degradación elegante: sin embeddings, cae a BM25 puro (nivel actual).

## Referencias

- ADR-003 (Fase 4): embeddings híbridos
- SPEC-018: `memory-vector.py`, `embedding-server.py`
- SCL-003: recall BM25 operativo (la base sobre la que se añadiría el híbrido)
