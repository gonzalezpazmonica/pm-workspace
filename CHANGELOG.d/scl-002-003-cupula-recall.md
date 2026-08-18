---
version_bump: minor
section: Added
---

### Added

- **SCL-002 — Cúpula de aprendizaje**: cúpula propia en SaviaVaults para las
  lecciones aprendidas del bucle SCL (persistencia real cross-instancia).
  Schema `learning_proposal`, `learning-persist.sh` (nota con entity +
  relations + wikilinks, indexada en el grafo), `learning-proposal.sh
  --persist`, `learning-federate.sh` (--list/--import como INFERRED shadow).
- **SCL-003 — Recall operativo**: `learning-recall.sh` recupera lecciones
  relevantes por contexto (BM25, umbral de score, log de utilidad). El hook de
  prompt solo inyecta principios activos, escritos por una persona y resueltos
  desde `CRITERIO.md`; las propuestas inferidas permanecen en sombra y nunca se
  convierten en instrucciones automáticamente.
- **SCL-008 — Límite de autoridad del aprendizaje**: separa búsqueda y
  autoridad, conserva la medición de propuestas sin elevarlas y aplica el mismo
  filtro en Claude Code y OpenCode. El ranking híbrido puede ordenar candidatos,
  pero no evita la validación humana ni expone snippets de propuestas.
