---
version_bump: minor
section: Added
---

### Added

- **SCL-002 — Cúpula SaviaLearning**: cúpula propia en SaviaVaults para las
  lecciones aprendidas del bucle SCL (persistencia real cross-instancia).
  Schema `learning_proposal`, `learning-persist.sh` (nota con entity +
  relations + wikilinks, indexada en el grafo), `learning-proposal.sh
  --persist`, `learning-federate.sh` (--list/--import como INFERRED shadow).
- **SCL-003 — Recall operativo**: `learning-recall.sh` recupera lecciones
  relevantes por contexto (BM25, umbral de score, log de utilidad) y
  `learning-recall-hook.sh` (UserPromptSubmit) las inyecta en el contexto del
  trabajo antes de responder — "NO reintroduzcas el error que documenta".
  Las lecciones dejan de ser un almacén muerto y se usan para evitar errores
  futuros.
