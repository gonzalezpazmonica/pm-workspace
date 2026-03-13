# Autoresearch — Investigación Autónoma con Agentes IA

> Referencia técnica del proyecto [autoresearch](https://github.com/karpathy/autoresearch) de Andrej Karpathy y sus patrones aplicados a pm-workspace.

---

## Qué es Autoresearch

Sistema que permite a agentes IA realizar investigación de ML de forma autónoma. El agente ejecuta ciclos de **modificar → entrenar → evaluar → mantener o descartar** sin intervención humana. Por la mañana, el investigador revisa logs y encuentra un modelo mejorado con historial completo.

## Arquitectura: 3 archivos

| Archivo | Responsabilidad | Editable por agente |
|---------|----------------|---------------------|
| `prepare.py` | Datos, tokenizador, evaluación (FIJO) | ❌ No |
| `train.py` | Modelo GPT-like + optimizador (~630 LOC) | ✅ Sí |
| `program.md` | Instrucciones declarativas para el agente | ❌ Solo lectura |

**Constantes fijas**: MAX_SEQ_LEN=2048, TIME_BUDGET=300s, VOCAB_SIZE=8192.

**Modelo**: RMS Norm, Rotary Embeddings, Flash Attention 3, Value Embeddings con gating, Sliding Window configurable, MLP relu², Soft-capping. Optimizador híbrido MuonAdamW.

## El bucle autónomo

```
LOOP FOREVER:
  1. Proponer modificación experimental a train.py
  2. git commit -m "agent(experiment): descripción"
  3. Ejecutar: uv run train.py
  4. Si val_bpb mejoró → MANTENER (avanzar rama)
  5. Si igual o peor → DESCARTAR (git reset --hard HEAD~1)
  6. Registrar en results.tsv
```

**Protecciones**: timeout 10min, fail-fast si loss>100, OOM→descartar, loop detection (3 repeticiones→cambiar estrategia).

## La métrica: Bits Per Byte (BPB)

`val_bpb = total_nats / (math.log(2) * total_bytes)` — independiente del vocabulario y la tokenización, con significado físico (límite teórico de compresión).

## Gestión de estado via Git

Rama por sesión (`autoresearch/{tag}`), cada experimento = un commit. Mantener = avanzar HEAD, descartar = `git reset --hard HEAD~1`. `results.tsv` registra TODOS los intentos.

```tsv
commit	val_bpb	memory_gb	status	description
a1b2c3d	0.997900	44.0	keep	baseline
b2c3d4e	0.993200	44.2	keep	increase LR to 0.04
c3d4e5f	1.005000	44.0	discard	switch to GeLU activation
```

## Patrones transferibles a pm-workspace

| Patrón Autoresearch | Aplicación pm-workspace | Skill/Regla |
|---------------------|------------------------|-------------|
| Bucle autónomo infinito | Overnight Sprint — tareas en loop nocturno | `overnight-sprint` |
| Modificar → test → keep/discard | Code Improvement Loop — mejora continua con métricas | `code-improvement-loop` |
| `program.md` declarativo | Research Programs para investigación técnica | `tech-research-agent` |
| Time budget fijo (5 min) | Time-boxed agent tasks (15 min default) | `autonomous-safety.md` |
| `results.tsv` tracking | Experiment tracking para modos autónomos | Todos los skills autónomos |
| Git branch per experiment | Ramas `agent/*` aisladas | `autonomous-safety.md` |
| Fail-fast (loss > 100) | Abort tras 3 fallos consecutivos | `autonomous-safety.md` |

### Diferencia clave

En autoresearch el agente hace merge automáticamente. **En pm-workspace, NUNCA se hace merge automático.** El agente crea un PR en Draft asignado a un reviewer humano.

> Regla completa: `@.claude/rules/domain/autonomous-safety.md`

## Casos de uso

Detalle completo: `@docs/autoresearch-cases.md`

1. **Optimización de hiperparámetros overnight** — LR, batch size, warmdown ratio (~96 experimentos/noche)
2. **Exploración arquitectónica** — window patterns, activaciones, depth/width tradeoffs
3. **Ablation studies automáticas** — eliminar componentes uno a uno, medir impacto
4. **Benchmarking reproducible** — runs de 5min exactos, directamente comparables

## Throughput esperado

Autoresearch: ~12 experimentos/hora × 8h = ~100 experimentos/noche.
pm-workspace: ~4 tareas/hora × 8h = ~32 mejoras propuestas como PR Draft.

## Setup

```bash
git clone https://github.com/karpathy/autoresearch.git && cd autoresearch
uv sync && uv run prepare.py && uv run train.py  # verificar baseline
```

Requisitos: GPU NVIDIA (H100), Python 3.10+, `uv`.
