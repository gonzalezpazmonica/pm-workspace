# SE-143 — Activar y proteger búsqueda semántica híbrida

**Status:** APPROVED  
**Fecha:** 2026-05-26  
**Área:** Memory System  

---

## Objetivo

La búsqueda semántica híbrida de Savia (SPEC-018, SPEC-035) está completamente
implementada pero corre en Level 0 (grep puro) porque las dependencias Python
no están instaladas. El sistema degrada silenciosamente sin informar al usuario.

Este spec activa, documenta y protege el sistema para que la degradación sea
visible y reparable con un solo comando.

---

## Contexto

Ficheros ya implementados:
- `scripts/memory-vector.py` — embeddings all-MiniLM-L6-v2 + hnswlib/faiss
- `scripts/memory-hybrid.py` — fusión RRF vector + grafo + grep
- `scripts/memory-search.sh` — modo `auto` usa híbrido si deps disponibles
- `scripts/memory-store.sh` — dispatcher, ya tiene `rebuild-index`, `index-status`, `benchmark`

Estado actual confirmado:
```
Level: 0 (grep) — sentence_transformers: NOT INSTALLED, hnswlib: NOT INSTALLED
```

---

## Criterios de Aceptación

### AC-1: requirements-memory.txt
- [x] Existe `scripts/requirements-memory.txt`
- [x] Contiene: `sentence-transformers>=2.7`, `hnswlib>=0.8`, `numpy>=1.26`
- [x] `pip install -r scripts/requirements-memory.txt` instala sin conflicto
  - Nota: `hnswlib` requiere `python3-dev` para compilar; fallback a `faiss-cpu` funciona sin compilación

### AC-2: subcomando `doctor`
- [x] `bash scripts/memory-store.sh doctor` imprime Level actual (0/1/2)
- [x] Imprime estado de cada dep (instalada / faltante)
- [x] Imprime estado del índice (fresh / stale / absent)
- [x] Si Level < 2: imprime `[WARN] Vector search DISABLED — running grep-only`
- [x] Si índice stale: imprime instrucción de rebuild
- [x] Sale con código 0 siempre (solo reporta, nunca instala)

### AC-3: startup hook integrado
- [x] `.opencode/hooks/session-init.sh` lanza `rebuild-index` en background si Level=2 e índice stale
- [x] No bloquea el arranque

### AC-4: sección en docs/memory-system.md
- [x] Existe sección "Activar búsqueda semántica" con levels, instrucción pip y doctor

### AC-5: instalador actualizado
- [x] `install.sh` instala `requirements-memory.txt` en Step 7 con fallback y mensajes claros

---

## Resultados de validación (2026-05-26)

```
doctor output:
  Level: 2 (vector+hybrid)
  sentence_transformers: OK (v5.5.1)
  vector backend (hnswlib/faiss): OK (faiss-cpu 1.14.2)
  index: fresh

benchmark output:
  Recall@5: Grep=40%  Vector=90%  Improvement=+50pp
  PASS: Vector search improved recall by +50 percentage points
```

---

## Plan de Implementación

1. Crear `scripts/requirements-memory.txt`
2. Añadir función `cmd_doctor()` en `memory-store.sh` antes del dispatcher
3. Añadir case `doctor)` en el dispatcher y en el help
4. Identificar hook de startup e integrar llamada (background)
5. Actualizar `docs/memory-system.md`

---

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Hook de startup bloquea arranque | Siempre `&` (background) + `|| true` |
| `doctor` tarda por imports Python | Usar solo `python3 -c "import X"` rápido |
| Conflicto de deps con otras libs | Documentar uso de venv si hay conflicto |

---

## Validación

```bash
# AC-1
pip install -r scripts/requirements-memory.txt

# AC-2
bash scripts/memory-store.sh doctor

# AC-4
grep -q "Activar búsqueda semántica" docs/memory-system.md && echo "OK"
```
