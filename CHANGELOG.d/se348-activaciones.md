---
version_bump: minor
section: Changed
---

### Changed (SE-348 — activaciones aprobadas, salvo hardware)

- **Vector recall ACTIVADO**: servidor de embeddings 7331 up (all-MiniLM-L6-v2)
  + búsqueda vectorial híbrida con scores (antes grep-only).
- **Shield NER ACTIVADO**: spaCy + Presidio + `es_core_news_md` en el venv;
  el launcher prefiere el venv (`daemon_python()`); `ner: true`; el gate detecta
  EMAIL/PERSON. Clasificador qwen2.5:7b diferido (hardware).
- **SE-346 Slice 2**: `savia_model_by_uncertainty()` en `savia-env.sh`
  (recomendación de modelo por incertidumbre, advisory, fail-open sin sklearn).
- **Hook FxC**: `fronesis-gate-reminder.sh` (warn-only, async) registrado en
  PostToolUse pr-create/merge — recuerda consultar precedentes (SE-344).
- Sandbox: **BLOQUEADO** (requiere sudo para bwrap) · Modelo ≥8B: **DIFERIDO**
  (limitación de hardware, operadora).
- Spec SE-348 → APPROVED→PARCIALMENTE IMPLEMENTADO.
