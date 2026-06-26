---
id: se-172-markitdown-digest
date: "2026-06-24"
spec: SE-172
title: markitdown como capa 0 universal de digestión
type: feature
era: 199
---

# SE-172 — markitdown como capa 0 universal de digestión

## Resumen

Implementa markitdown (Microsoft, MIT, v0.1.6) como capa 0 de extracción universal
para todos los digest-agents de pm-workspace. Separa extracción (commodity) de
análisis de dominio (valor), reduciendo duplicación de parsers y ampliando cobertura
de formatos.

## Ficheros creados

- `scripts/digest-extract.sh` — extractor shell que delega en markitdown con
  seguridad AC-07 (umask 077, path-gate WORKSPACE_ROOT, --external flag)
- `scripts/markitdown-digest-wrapper.py` — orquestador Python: acepta --file/--agent,
  devuelve JSON con markdown extraído o fallback_used=true
- `.opencode/agents/archive-digest.md` — agente nuevo para ZIP, EPub, Outlook .msg
- `tests/bats/test-se-172-markitdown.bats` — 32 tests BATS (AC-08 requería ≥20)
- `tests/scripts/test_markitdown_wrapper.py` — 18 tests pytest (AC-08 requería ≥8)
- `CHANGELOG.d/se-172-markitdown-digest.md` — este fichero

## Ficheros modificados

- `.opencode/agents/pdf-digest.md` — Fase 1 Markitdown añadida
- `.opencode/agents/word-digest.md` — Fase 1 Markitdown añadida
- `.opencode/agents/excel-digest.md` — Fase 1 Markitdown añadida
- `.opencode/agents/pptx-digest.md` — Fase 1 Markitdown añadida
- `.opencode/agents/visual-digest.md` — Fase 1 Markitdown añadida
- `.opencode/agents/meeting-digest.md` — Fase 1 Markitdown añadida
- `docs/propuestas/SE-172-markitdown-universal-digest.md` — status IMPLEMENTED

## Acceptance Criteria

| AC | Estado | Notas |
|----|--------|-------|
| AC-01 | ✓ PASS | `digest-extract.sh` produce Markdown + front-matter (mime, hash, timestamp) |
| AC-02 | ✓ PASS | 6 agentes con Fase 1 Markitdown; fallback al parser histórico si falla |
| AC-03 | ✓ PASS | ZIP, EPub, .msg cubiertos en archive-digest (4 formatos con YouTube via URL) |
| AC-04 | N/A | No había scripts `*-digest-*.py` — los agentes son prompts, no Python |
| AC-05 | ✓ PASS | `convert_local()` por defecto en digest-extract.sh y wrapper |
| AC-06 | ✓ PASS | Fallback con WARNING + exit 1 en digest-extract.sh; fallback_used=true en wrapper |
| AC-07 | ✓ PASS | umask 077, path-gate WORKSPACE_ROOT, flag --external requerido para externos |
| AC-08 | ✓ PASS | 32 BATS + 18 pytest = 50 tests (≥20 BATS + ≥8 pytest) |

## Tests

```
BATS: 32/32 passed
pytest: 18/18 passed
```

## Dependencia instalada

```
markitdown==0.1.6  (pip install 'markitdown[pdf,docx,pptx,xlsx]')
```
