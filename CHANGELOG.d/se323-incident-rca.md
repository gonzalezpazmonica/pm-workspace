---
version_bump: minor
section: Added
---

### Added

- SE-323 Incident RCA Agent — investigación autónoma de incidentes con
  evidencia enlazada y masking reversible:
  - `scripts/mask-reversible.py` + `scripts/mask-reversible.sh`: masking
    reversible de identificadores (pods, clusters, account IDs, IPs,
    servicios, imágenes). Sustituye IDs por placeholders únicos
    (`{POD_1}`, `{IP_2}`) y `--restore` recompone el texto original byte a
    byte desde un mapa efímero (N4b, no persistido). Sin IDs → passthrough
    (AC-S1).
  - `scripts/incident-rca.sh`: harness de investigación — dado un alert JSON
    y señales locales (logs, métricas, deploys) correlaciona de forma
    determinista (sin LLM en la primera iteración), razona hipótesis de root
    cause y emite `output/incidents/{incident-id}-rca.json` con
    `root_cause`, `confidence`, `evidence[]` enlazada a su fuente, `timeline`,
    `next_steps` y `red_herrings_dismissed[]`. Sin señales → confidence low,
    evidence vacío, no inventa (AC-S2). Emite telemetría `rca.verdict`
    (schema savia.event/1.0, SE-313).
  - `scripts/rca-eval-runner.sh` + `tests/evals/incident-rca/rca-cases.jsonl`
    (12 casos): suite sintética que puntúa root cause, evidencia y red
    herrings descartadas; gate score >= 80 (AC-S3).
  - `scripts/incident-postmortem.sh`: rellena la plantilla de postmortem de
    `postmortem-policy.md` (Timeline, Diagnosis Journey, Resolution) desde el
    informe RCA, conservando las secciones humanas vacías para revisión
    (AC-S4). Naming `output/postmortems/YYYYMMDD-{incident-id}.md`.
  - Gate G18 en `pr-plan-gates.sh` (report-only, nunca bloquea) que ejecuta
    la suite RCA en cada plan.
  - Job CI `Incident RCA Eval (report-only)` con `continue-on-error: true`;
    emite el score como notice.
  - 15 tests BATS (`tests/test-incident-rca.bats`): AC-S1..S4 + zero-secrets.

### Notes

- La suite sintética usa `rca-cases.jsonl` (no `cases.jsonl`) para no chocar
  con el schema de tribunales de SE-316 eval-lint (formato RCA propio, no
  golden set de tribunal).
- El harness reutiliza las capas de detección deterministas de SE-314
  (sovereignty-classify) en el espíritu, sin duplicar su LLM; el razonamiento
  agéntico tool-calling se conecta vía `--llm` (Ollama local).
- `--postmortem` respeta la política `output/postmortems/` (gitignored, N4b);
  hereda `--out` solo si el usuario lo especifica explícitamente.
