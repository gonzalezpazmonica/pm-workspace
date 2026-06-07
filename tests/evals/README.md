# Evaluation Harness — SE-204

> Ref: docs/propuestas/SE-204-eval-harness.md

Directorio raíz de eval cases para agentes críticos de pm-workspace.
Formato: EvalCase = `input.md` (tarea) + `criteria.md` (rúbrica LLM-as-judge).

## Estructura

```
tests/evals/
├── sdd-spec-writer/      # Eval cases para el agente sdd-spec-writer
├── court-orchestrator/   # Eval cases para court-orchestrator
└── business-analyst/     # Eval cases para business-analyst
```

Cada subdirectorio de agente contiene carpetas `eval-NN-<nombre>/` con:
- `input.md` — Descripción realista de la tarea (≥50 palabras)
- `criteria.md` — Rúbrica LLM-as-judge (≥5 criterios, umbral ≥7/10)

## Ejecución

```bash
# Listar todos los eval cases disponibles
bash scripts/run-agent-evals.sh --list

# Dry-run (sin ejecutar agentes)
bash scripts/run-agent-evals.sh --dry-run

# Ejecutar todos los agentes
bash scripts/run-agent-evals.sh

# Ejecutar un agente específico
bash scripts/run-agent-evals.sh --agent sdd-spec-writer
```

## Threshold

Exit 0 si score estructural ≥ 80% de los eval cases son válidos.
Exit 1 si < 80%.

Reporte generado en `output/eval-report-YYYYMMDD.md`.

## Nota sobre Slices

- **Slice 1-2** (esta implementación): estructura + eval cases + runner estructural.
- **Slice 3-4** (futura SE-204): invocación real de agentes LLM + puntuación LLM-as-judge.

El runner actual valida que los ficheros existen y tienen forma correcta
(criteria.md ≥5 criterios, input.md ≥50 palabras). No invoca LLMs todavía.
