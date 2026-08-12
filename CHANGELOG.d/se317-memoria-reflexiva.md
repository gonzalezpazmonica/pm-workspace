---
version_bump: minor
section: Added
---

### Added

- SE-317 Memoria reflexiva — pase de reflexión sobre el knowledge store:
  - `scripts/memory-consolidate.sh scan`: detecta duplicados (score 1.0) y
    near-duplicates (difflib > 0.85) por fingerprint de contenido (AC-S1).
  - `scripts/memory-consolidate.sh link`: propone aristas tipadas
    `derived-from` cuando una nota cita el hash o título de otra (AC-S2.1);
    la arista es una propuesta en JSONL, no se auto-escribe al grafo
    (AC-S2.2).
  - `scripts/memory-consolidate.sh distill`: agrupa notas del mismo episodio
    (topic_key/domain) en un insight con citas; marca las fuentes como
    `absorbed` sin borrarlas (AC-S3).
  - `scripts/memory-consolidate.sh prune --dry-run`: lista candidatos a
    eliminar con razón (absorbida, importancia tier D); nunca borra solo
    (AC-S4.1).
  - Todo candidato se escribe a `output/memory-consolidation/{fecha}-{accion}.jsonl`
    para revisión humana (AC-S4.3). Automatización semanal ya registrada en
    `savia-automations.sh` (`memory-consolidation`, cron `0 2 * * *`).
  - Comando `/memory-consolidate` actualizado con el backend determinista.
  - 10 tests BATS (`tests/test-memory-consolidate.bats`): AC-S1..S4 +
    zero-secrets.

### Notes

- Determinista (stdlib python), sin LLM: fingerprint + difflib + marcado. El
  enlazado y el prune son propuestas para revisión humana; nada se auto-aplica
  salvo `--apply` explícito.
- `link` usa cita de hash/título (heurística conservadora) para evitar falsos
  positivos; el grafo tipado de knowledge-graph no se escribe automáticamente
  (las aristas propuestas se pueden aplicar en revisión).
