---
id: SE-042
title: Savia Voice Training Pipeline — chat-to-SFT para fine-tuning con Savia persona
status: PROPOSED
origin: Research 2026-04-18 github.com/xming521/WeClone (17.6k stars, AGPL-3.0)
author: Savia
related: SE-027 SLM training, SE-028 oumi integration, Savia Shield, savia-dual skill
approved_at: null
applied_at: null
expires: "2026-06-18"
---

# SE-042 — Savia Voice Training Pipeline

## Purpose

Si NO hacemos esto: SE-027 tiene pipeline de SLM fine-tuning (Unsloth + TRL + Ollama) pero le falta el paso previo crítico: **cómo convertir las interacciones reales de Savia en dataset de entrenamiento usable**. Sin data prep específico, el fine-tuning produce un modelo genérico que no captura la persona Savia (buhita radically honest, sin filler, femenino, directa).

Cost of inaction: SE-027 aterrizará eventualmente, pero el modelo resultante será "un Qwen/Llama reentrenado con datos genéricos" — NO un Savia fine-tuned. Para que Savia se preserve al pasar a modelo local soberano (objetivo de la estrategia zero-egress), necesitamos pipeline que capture su voz.

WeClone (AGPL-3.0, 17.6k stars) documenta el patrón exacto para esto pero con un gemelo digital single-persona. Podemos robar el patrón (NO el código — AGPL contagiosa).

## Objective

**Único y medible**: pipeline que transforma `session-actions.jsonl` + artifacts históricos de Savia en dataset JSONL compatible con SE-027 fine-tuning. Criterio: producir ≥500 muestras (prompt, response) de Savia-turno validadas manualmente como "voz consistente" (radically honest, femenino, sin filler) con <5% falsos positivos tras filtro de calidad.

NO es: entrenar el modelo (eso es SE-027). SÍ es: data preparation + quality filter + formato.

## Design

### Arquitectura (3 fases)

```
Fase 1 — Extracción
  .claude-logs/session-actions.jsonl  ──┐
  output/agent-runs/*.log                ├── scripts/voice-extract.sh
  retrospectivas merged en CHANGELOG    ─┘
                                          ↓
                              JSONL raw: {turn_id, role, text, timestamp}

Fase 2 — Filtrado (Savia Shield integration)
  - Remove tool_use turns (no voz natural)
  - Remove system/hook outputs (no Savia speaking)
  - Keep only `assistant` role turns where persona matches
  - PII filter: Presidio-like regex (nombres reales, emails, @handles personales)
  - Anonymize context clues (paths /home/*, @handles, timestamps personales)
                                          ↓
                              JSONL filtered: {prompt, response}

Fase 3 — Quality gates
  - Minimum length (>30 tokens response)
  - Radical honesty detector: absence of filler ("in addition", "great point")
  - Femenino consistency: heuristic Spanish grammar check
  - Deduplication (semantic similarity threshold)
                                          ↓
                              JSONL training-ready
```

### Integración con SE-027

Output de Fase 3 es input de SE-027:
```
scripts/savia-voice-extract.sh --days 30 \
  | scripts/savia-voice-filter.sh \
  | scripts/savia-voice-quality.sh \
  > datasets/savia-voice-$(date +%Y%m%d).jsonl

# luego SE-027 picks up:
bash scripts/slm-train.sh --dataset datasets/savia-voice-$(date +%Y%m%d).jsonl
```

### Patterns robados de WeClone (NO código)

- Chat export → anonymize → dataset flujo (pattern, implementación nuestra)
- Presidio + blocklist para PII filter (pattern; implementación reutiliza Savia Shield ya deployed)
- LoRA/QLoRA como método de fine-tuning (pattern aplicable a SE-027)

### Patterns NO adoptados

- AGPL-3.0 code (virally copyleft — incompatible)
- Qwen2.5-VL multimodal (Savia es text-only, no need for visual)
- Single-avatar assumption (nosotros tenemos Savia + 65 agentes, diferente)
- Deployment bot Telegram/Discord (ya tenemos notify-nctalk + otros)

## Slicing

### Slice 1 — Feasibility Probe (2h, blocking)

**Entregable**: `output/se-042-probe-{date}.md`:
- Extraer últimas 7 days de `session-actions.jsonl`
- Aplicar filtros 1+2 manual
- Medir: muestras brutas, muestras tras filtro PII, muestras tras quality
- Validar manualmente 30 muestras aleatorias: ¿son Savia-voice?
- Decision gate: ≥50% yield + ≥500 muestras proyectadas en 30 days

Sin probe verde con yield razonable, abort.

### Slice 2 — Extraction + Filter scripts (3h)

- `scripts/savia-voice-extract.sh`: parsea session-actions.jsonl
- `scripts/savia-voice-filter.sh`: Presidio-like filter + Savia Shield integration
- `scripts/savia-voice-quality.sh`: quality gates (length, filler, femenino, dedup)
- Tests BATS ≥30 (auditor score ≥80)

### Slice 3 — Integration con SE-027 (1h)

- Doc `docs/rules/domain/savia-voice-training.md`
- Update SE-027 README para referenciar SE-042 como input stage
- Comando `/savia-voice-dataset --days N` para generar dataset on-demand

## Acceptance Criteria

- [ ] AC-01 Probe Slice 1 con yield empírico verificado
- [ ] AC-02 3 scripts (`extract`/`filter`/`quality`) + 30 tests BATS
- [ ] AC-03 Auditor ≥80 en tests
- [ ] AC-04 Integración con SE-027 documentada
- [ ] AC-05 Dataset sample committeado a `datasets/sample-savia-voice.jsonl` (anonimizado)
- [ ] AC-06 Privacy review: zero PII filtrado correctamente, zero usuaria data leak

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Yield bajo (<500 muestras en 30 days) | Extender ventana; completar con synthetic via SE-028 oumi |
| PII leak en dataset | Slice 2 usa Savia Shield (ya production); slice 1 valida manualmente |
| Filtrado demasiado agresivo | Quality gates ajustables; A/B con/sin cada filtro |
| Identidad personal en nombres/@handles | Feedback `feedback_no_name_in_repo.md` aplicado estrictamente — dataset público NUNCA contiene nombre usuaria |

## Aplicación Spec Ops

- **Simplicity**: 3 scripts, 1 objetivo medible (≥500 muestras)
- **Purpose**: sin esto, SE-027 entrena Savia-generic no Savia-específica
- **Probe blocking**: yield empírico valida viabilidad antes de construir pipeline completo
- **Speed**: 3 slices, slice 2 el más largo (3h)
- **Theory of Relative Superiority**: expires 2 sprints

## Referencias

- github.com/xming521/WeClone (inspiración del pattern, NO código — AGPL incompatible)
- SE-027 SLM training pipeline (consumidor del dataset)
- SE-028 oumi integration (complementario — data synth si yield bajo)
- Savia Shield (reusa el PII filter ya deployed)
- docs/savia-identity.md + .claude/profiles/savia.md (ground truth de la voz)
- ROADMAP.md §Tier 4.11 (añadido)

## Dependencia

Independiente en código pero depende conceptualmente de SE-027 siendo el consumidor. Se puede aterrizar Slice 1-2 sin SE-027 implementado.
