---
id: SE-323
title: "SE-323 — Incident RCA Agent: investigación autónoma de incidentes con evidencia enlazada"
status: IMPLEMENTED
priority: alta
timeline:
  - from: "2026-08-12"
    learned: "2026-08-12"
    value: "IMPLEMENTED"
    source: "SE-323 implementado: mask-reversible + incident-rca + eval suite (PR #956)"
---

# SE-323 — Incident RCA Agent: investigación autónoma de incidentes con evidencia enlazada

**Status:** IMPLEMENTED
**Fecha:** 2026-08-09
**Area:** SRE / Incident response / Observability / Postmortem
**Branch sugerida:** `agent/se323-incident-rca`
**Estimacion total:** ~36h (4 slices)
**Inspiracion:** `Tracer-Cloud/opensre` (incident investigation harness, synthetic RCA suites, reversible masking)

---

## Contexto y evidencia (2026-08-09)

OpenSRE (`Tracer-Cloud/opensre`, Apache-2.0, ~10k stars) automatiza la
investigación de incidentes de producción: ante un alert, un agente AI
correlaciona logs/metricas/trazas/deploys, **enmascara identificadores de
forma reversible** antes de llamadas LLM externas, razona en un bucle
tool-calling, y emite un informe RCA con root cause probable y evidencia
enlazada. Tambien incluye **suites sinteticas de RCA** que puntuan la
exactitud del root cause, la evidencia requerida y las **adversarial red
herrings** (señuelos que el agente debe ignorar).

Savia tiene:

- `docs/rules/domain/postmortem-policy.md` (56 lineas): plantilla de 7
  secciones, heuristic extraction, comprehension gap — **documentacion
  post-hoc, manual**.
- `output/postmortems/` (naming `YYYYMMDD-{incident-id}.md`).
- SE-314 (clasificador de soberania, determinista) y SE-313 (telemetria OTel).
- `pentester` (seguridad, no SRE) y `meeting-risk-analyst` (riesgos de
  negocio, no infraestructura).

**El hueco.** Savia documenta incidentes despues de que un humano los
investigue; no tiene el **lado reactivo**: un agente que recoja el contexto
del incidente, correlacione señales y proponga un root cause con evidencia
enlazada. La pieza `masking reversible` ademas es la evolucion natural del
clasificador SE-314 (de BLOCK/WARN a transformacion id↔placeholder con
restauracion en output).

---

## Objetivo

Implementar un agente de investigacion de incidentes (RCA) que, dado un alert
estructurado, correlacione señales disponibles (logs, metricas, despliegues),
enmascare identificadores de forma reversible para cualquier analisis,
produzca un informe RCA con root cause y evidencia enlazada, y rellene la
plantilla de postmortem existente. Incluye una suite sintetica de evaluacion
con red herrings.

---

## Out of scope

- NO conectar a proveedores de observabilidad externos (Datadog, CloudWatch,
  etc.) en la primera iteracion — entrada via fichero JSON de alert y señales.
- NO ejecutar remediacion automatica (solo sugerir pasos).
- NO sustituir la revision humana del postmortem (autonomous-safety).

---

## Diseno

### S1 — Masking reversible de identificadores

`scripts/mask-reversible.sh` (extiende sovereignty-classify):
- detecta IDs (pods, clusters, account IDs, IPs, nombres de servicio) y los
  sustituye por placeholders (`{ID_1}`, `{POD_2}`),
- mantiene el mapa `placeholder ↔ valor original` en memoria/fichero efimero
  (N4b, no persistido),
- `--restore <map>` recompone el output final con los valores reales.
- Reutiliza las capas de deteccion de SE-314 (patrones deterministas).

### S2 — Harness de investigacion RCA

`scripts/incident-rca.sh --alert <file>`:
1. recibe alert JSON (título, severidad, servicio, timestamp),
2. correlaciona señales disponibles en el directorio del incidente
   (logs, metricas, recent deploys) — lectura local, sin LLM primero,
3. el agente razona en bucle tool-calling (hipotesis → evidencia),
4. emite `output/incidents/{incident-id}-rca.json` con:
   `root_cause`, `confidence`, `evidence[]` (cada una enlazada a su fuente),
   `timeline`, `next_steps`, `red_herrings_dismissed[]`.
- Coste por sesion y telemetria SE-313: evento `rca.verdict`.

### S3 — Synthetic RCA suite

`tests/evals/incident-rca/cases.jsonl` con >=10 casos:
- cada caso: señales reales + un root cause real + **2-3 red herrings**,
- runner `scripts/rca-eval-runner.sh` puntua: exactitud del root cause,
  evidencia citada, red herrings ignoradas (no citadas como causa),
- gate: score >= 80 (compatible con SE-316 eval-lint).

### S4 — Integracion con postmortem

- `incident-rca.sh --postmortem` rellena la plantilla de
  `postmortem-policy.md` (Timeline, Diagnosis Journey, Resolution) desde el
  informe RCA,
- el humano revisa y completa Heuristic Extraction + Comprehension Gap
  (sigue siendo obligatorio por policy),
- el reporte se guarda en `output/postmortems/YYYYMMDD-{incident-id}.md`.

---

## Criterios de aceptacion

### AC-S1: Masking reversible

- [ ] AC-S1.1: texto con pod+cluster+IP → placeholders unicos y `--restore`
  devuelve el texto original byte a byte.
- [ ] AC-S1.2: el mapa no se persiste tras el proceso (fichero efimero N4b).
- [ ] AC-S1.3: sin identificadores → passthrough sin cambios, exit 0.

### AC-S2: Harness RCA

- [ ] AC-S2.1: alert de fixture produce informe RCA con root_cause, evidence
  (>=2, enlazadas a fuente) y confidence.
- [ ] AC-S2.2: `rca.verdict` aparece en `output/telemetry-events.jsonl`.
- [ ] AC-S2.3: sin señales disponibles → informe con `confidence: low` y
  `evidence: []`, no inventa.

### AC-S3: Suite sintetica

- [ ] AC-S3.1: `tests/evals/incident-rca/cases.jsonl` con >=10 casos.
- [ ] AC-S3.2: runner puntua las 3 dimensiones y reporta por caso.
- [ ] AC-S3.3: un caso con red herring citada como causa baja el score
  (el runner lo detecta).

### AC-S4: Postmortem

- [ ] AC-S4.1: `--postmortem` genera el fichero en `output/postmortems/` con
  las 3 secciones rellenadas desde el RCA.
- [ ] AC-S4.2: el postmortem conserva las secciones humanas vacias (Heuristic
  Extraction, Comprehension Gap) para revision.

---

## Ref

- `Tracer-Cloud/opensre` → README (investigation flow, reversible masking,
  synthetic RCA), `tests/synthetic/`, `tests/e2e/`
- `docs/rules/domain/postmortem-policy.md`, `docs/propuestas/SE-314-sovereignty-classifier-redesign.md`
- `docs/rules/domain/autonomous-safety.md`

## Implementación (2026-08-11)

- S1: `scripts/mask-reversible.py` + `scripts/mask-reversible.sh` — masking
  reversible de IDs con placeholders únicos y `--restore` byte a byte.
- S2: `scripts/incident-rca.sh` — harness determinista (sin LLM en primera
  iteración) con telemetría `rca.verdict`.
- S3: `tests/evals/incident-rca/rca-cases.jsonl` (12 casos) +
  `scripts/rca-eval-runner.sh` (gate >= 80).
- S4: `scripts/incident-postmortem.sh` — rellena Timeline / Diagnosis Journey
  / Resolution de la plantilla de postmortem.
- G18 en `pr-plan-gates.sh` + job CI `Incident RCA Eval (report-only)`.
- 15 tests BATS (`tests/test-incident-rca.bats`).
