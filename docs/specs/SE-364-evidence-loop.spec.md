# SE-364 — Bucle de evidencia: historial de decisiones como corpus de evals internos

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Evals / Mejora continua
**Fuente de inspiración:** Anthropic AI-Native SDLC Playbook (capturar cambios aceptados/rechazados/intervenidos como conjunto de evaluación interno)
**Criterio humano aplicable:** CRIT-001 (evals locales, sin datos a cloud)

---

## Objetivo

Capturar el historial real de decisiones de Savia — cambios **aceptados,
rechazados y con intervención humana** — y convertirlo en un **corpus de evals
interno** que se use para refinar agentes. Cada vez que un humano corrige o
rechaza una salida, ese caso entra al conjunto de evaluación como caso
discriminante: si el agente vuelve a producir lo mismo tras un cambio de prompt,
el eval falla.

## Contexto

El playbook propone el bucle de evidencia: los cambios aceptados/rechazados con
intervención humana forman el conjunto de evaluación propio. Verificado en Savia:
`evals-runner.sh`, `evals-paired-delta.py` y `eval-improvement-suggest.sh`
existen y cubren evals sobre config de agentes (SPEC-151). **Lo que falta**: el
mecanismo que **captura la intervención humana** (rechazo/corrección) como caso
de eval — el corpus de evals no se alimenta automáticamente del historial de
decisiones. `focal-decisions-log.sh` registra decisiones del director pero no
se enruta a evals.

**Rechazo explícito (CRIT-001):** el corpus de evals es local y los casos son
salidas del propio workspace (sin datos N3+). No se envía a ningún proveedor.

## Diseño

### 1. Captura de intervenciones `scripts/evidence-capture.sh`

- Lee `focal-decisions.jsonl` + `data/audit/actions.jsonl` (SE-355) +
  `data/decision-traces/` (SPEC-188)
- Detecta casos con `outcome: failure` o intervención humana (rechazo, corrección)
- Escribe `data/evidence-corpus/*.json` (caso: input, output_rejected, human_correction)

### 2. Corpus `data/evidence-corpus/`

Formato por caso:
```json
{
  "id": "ev-001",
  "source": "focal-decisions|audit|decision-trace",
  "input": "...",
  "output_rejected": "...",
  "human_correction": "...",
  "ts": "...",
  "status": "open|closed"
}
```

### 3. Generador de evals `scripts/evidence-to-evals.py`

- Convierte casos cerrados del corpus a formato eval del runner existente
  (SPEC-151 / evals-paired-delta)
- Cada caso es un discriminante: tras cambio de prompt/skill, si el output
  repite `output_rejected`, el eval falla

### 4. Integración

- `evals-runner.sh` acepta `--corpus data/evidence-corpus`
- Informe mensual: casos capturados, tasa de intervención, evals que el agente
  vuelve a fallar (señal de prompt debt)

## Criterios de aceptación

- **AC-0** Captura casos con outcome failure/intervención (test con fixture de ledger)
- **AC-1** Corpus genera evals compatibles con el runner existente (test)
- **AC-2** Eval discriminante: output_rejected vuelto a producir → fail (test)
- **AC-3** Informe mensual con tasa de intervención
- **AC-4** Solo fuentes locales; ningún caso N3+ (filtro por nivel)
- **AC-5** Sin regresión: evals SPEC-151 existentes intactos

## OpenCode Implementation Plan

### Bindings touched
- `scripts/evidence-capture.sh` (nuevo), `scripts/evidence-to-evals.py` (nuevo)
- `data/evidence-corpus/` (nuevo, versionado o gitignored según nivel)
- `evals-runner.sh` (flag --corpus), `eval-improvement-suggest.sh` (consume corpus)

### Verification protocol
```bash
bats tests/bats/test-evidence-loop.bats
bash scripts/evidence-capture.sh --from audit --days 30
python3 scripts/evidence-to-evals.py --corpus data/evidence-corpus --output output/evals
```

### Portability classification
- Bash + python3 stdlib; local; portable

## Validación (ejecutada en esta sesión)

- `evidence-capture.py`: captura failure/deny desde audit → corpus JSON; filtro N3/N3b/N4b; genera evals discriminantes compatibles con SPEC-151; 5 pytest + 4 bats verdes
- `evidence-capture.sh`: wrapper (captura / --to-evals)

## Referencias
- Anthropic: claude.com/blog/the-ai-native-sdlc-playbook (bucle de evidencia)
- Savia: SPEC-151 (evals paired-delta), focal-decisions-log (SE-230), SE-355, CRIT-001
