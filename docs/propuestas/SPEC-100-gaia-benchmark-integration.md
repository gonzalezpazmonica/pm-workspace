---
spec_id: SPEC-100
title: GAIA Benchmark Integration — External Quality Validation for Agents
status: PROPOSED
origin: HKUDS/AutoAgent analysis (2026-04-15)
severity: Media
effort: ~5 días (40h)
priority: baja
---

# SPEC-100: GAIA Benchmark Integration

## Problema

pm-workspace tiene 56 agentes especializados pero ninguna métrica externa
valida su calidad. Confiamos en:
- Tests BATS (estructura, no comportamiento)
- /eval-output (LLM-as-judge interno, sesgo de auto-evaluación)
- Feedback humano cualitativo

Cuando un cliente enterprise pregunta "¿qué tan buenos son tus agentes vs
GPT-4 + AutoAgent + CrewAI?", no tenemos respuesta defendible. AutoAgent
publica score GAIA, OpenAI publica MMLU/HumanEval, nosotros nada.

GAIA (General AI Assistant) Benchmark de Meta + HuggingFace evalúa agentes
en tareas multi-step que requieren razonamiento, herramientas web, y
síntesis. Es el estándar emergente para agentes generales.

## Solucion

Suite de evaluación que ejecuta agentes pm-workspace contra GAIA:

```
gaia/
├── runner/
│   ├── run-gaia.sh              # Ejecuta tests GAIA contra agente especificado
│   ├── adapter.py               # Adapta protocolo GAIA → invocación pm-workspace
│   └── scorer.py                # Compara output vs ground truth
├── results/
│   ├── {date}-{agent}-level{1|2|3}.json
│   └── leaderboard.md           # Histórico de scores propios
└── README.md                    # Cómo ejecutar y reproducir
```

Niveles GAIA:
- **Level 1**: tareas simples, 1-2 herramientas
- **Level 2**: razonamiento multi-step
- **Level 3**: tareas complejas, requieren planeo

## Agentes a evaluar (Phase 1)

Priorizamos los 5 con mayor potencial GAIA (generalistas):

| Agente | Por qué | Nivel target |
|--------|---------|--------------|
| `tech-research-agent` | Más cercano a "general AI assistant" | L2-L3 |
| `architect` | Razonamiento técnico complejo | L2 |
| `business-analyst` | Síntesis multi-input | L2 |
| `code-reviewer` | Análisis estructurado | L1-L2 |
| `dev-orchestrator` | Workflow planning | L2-L3 |

Phase 2: agentes especializados (developers por lenguaje, no aplican GAIA directo)

## Comando

```bash
/gaia run --agent tech-research-agent --level 1 --samples 50
/gaia compare --agents architect,business-analyst --level 2
/gaia leaderboard                                    # ver histórico propio
/gaia publish                                        # generar markdown público
```

## Métricas

| Métrica | Definición | Target inicial |
|---------|-----------|---------------|
| Accuracy GAIA L1 | % tareas con respuesta exacta | ≥40% (baseline AutoAgent ~50%) |
| Accuracy GAIA L2 | idem L2 | ≥25% |
| Accuracy GAIA L3 | idem L3 | ≥10% |
| Latencia media | s/tarea | <120s L1, <300s L2 |
| Token cost | $/100 tareas | <$5 L1, <$15 L2 |
| Tool calls | promedio por tarea | informativo |

## Restricciones

- NO ejecutar GAIA contra producción (cuesta dinero, $5-50 por suite completa)
- Sandbox aislado: `nidos` worktree dedicado a benchmarks
- API key Anthropic separada con presupuesto cap (`MAX_BENCHMARK_BUDGET=$50`)
- Resultados se publican mensualmente (no continuos), evitar gaming
- Si score baja >15% entre runs → bloquea release hasta investigar

## Reglas de negocio

- **GAIA-01**: Solo agentes con `permission_level >= L1` son evaluables
- **GAIA-02**: Resultados oficiales requieren ≥3 runs independientes (reduce varianza)
- **GAIA-03**: Comparativas con competidores (AutoAgent, GPT-4) se documentan
  con fecha + versión exactas para reproducibilidad
- **GAIA-04**: Scores nunca se cherry-pickean — si se publica L1, se publica L2 y L3 también
- **GAIA-05**: Si baseline cae bajo target durante 2 sprints consecutivos, escalar a architect

## Acceptance criteria

- [ ] `gaia/runner/run-gaia.sh tech-research-agent --level 1 --samples 10` ejecuta y emite JSON válido
- [ ] Adapter.py traduce input GAIA → prompt pm-workspace y output → respuesta GAIA
- [ ] Scorer.py compara fuzzy (no exact match estricto) con tolerancia configurable
- [ ] Tests BATS validan parsing del formato GAIA y del output
- [ ] Leaderboard.md se actualiza automáticamente tras cada run
- [ ] Documentación: cómo descargar GAIA dataset (HuggingFace), cómo configurar API key, cómo interpretar scores
- [ ] Primer baseline publicado: tech-research-agent L1 con 50 samples

## Out of scope

- Otros benchmarks (HumanEval, MMLU, SWE-bench) — futuras specs
- Optimización de agentes basada en GAIA — separada (esta spec solo MIDE)
- Comparación automática con AutoAgent/GPT-4 (manual primera iteración)
- Web UI para resultados (markdown suficiente)
- Auto-tuning de prompts basado en errores GAIA

## Justificacion

**Defensiva:** clientes enterprise exigen métricas externas. Sin GAIA, perdemos
deals contra competidores que sí publican. AutoAgent (9.1k★) tiene baseline
público; nosotros no.

**Ofensiva:** si nuestros agentes especializados superan a generalistas (AutoAgent,
GPT-4) en su nicho, es argumento de venta poderoso. Especialización vs
generalismo se vuelve **medible**.

**Calidad interna:** detecta regresiones de agentes que tests estructurales no ven
(un agente puede pasar BATS y aun así degradar en razonamiento real).

## Riesgos

| Riesgo | Mitigación |
|--------|-----------|
| Coste API alto ejecutando GAIA frecuente | Budget cap + frecuencia mensual + sample subset |
| Scores bajos públicos dañan reputación | Phase 1 interno, publicar solo cuando target alcanzado |
| GAIA no mide lo que pm-workspace hace bien (PM workflows) | Documentar limitación, complementar con propio benchmark |
| Variance alta entre runs | GAIA-02: 3+ runs, reportar mediana |

## Métricas de éxito

- 50 samples L1 ejecutados sin errores en <30 min
- Baseline establecido para 5 agentes Phase 1
- Documento público de comparativa pm-workspace vs AutoAgent en 6 sprints

## Referencias

- [GAIA Benchmark](https://huggingface.co/datasets/gaia-benchmark/GAIA)
- [Leaderboard](https://gaia-benchmark-leaderboard.hf.space/)
- [Paper Mialon et al. 2023](https://arxiv.org/abs/2311.12983)
- HKUDS/AutoAgent score público
- /eval-output (complementario, no reemplazado)
- /eval-create, /eval-run (framework de evals propio)
