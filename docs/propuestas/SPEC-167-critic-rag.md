---
id: SPEC-167
title: Critic with RAG over external memory
status: APPROVED
priority: MEDIUM
estimated_hours: 6
tier: 2
origin: lecun-jepa-h-research-2026
---

# SPEC-167 Critic-RAG

## Problema
Los jueces del tribunal (correctness, security, architecture, cognitive, spec) evaluan cada output sin acceso a la memoria externa de Savia. No saben:

- Si ya hubo PR similar con misma estructura que fue rechazado
- Si una decision arquitectonica contradice una decision previa registrada
- Si un patron de codigo similar fallo en un sprint anterior

LeCun: el critic sin acceso a la memoria asociativa es un evaluador amnesico. Cada juicio es de novo.

## Solucion
Capa RAG ligera entre la memoria auto (`MEMORY.md` + entradas individuales) y cada juez:

- Antes de emitir veredicto, el juez recibe top-K (K=5) entradas relevantes de memoria
- Relevancia v1: BM25 sobre keywords del output a juzgar
- Relevancia v2 (futura): embeddings + reranker

Cambios minimos en cada juez: una seccion `## Memoria relevante` en el contexto del juez, y una linea "memoria_consulted: [ids]" en su veredicto.

## Slices
1. Indice BM25 de memoria auto + script de query (2h)
2. Hook pre-judge que adjunta top-K a contexto del juez (2h)
3. Cambios en jueces para usar memoria + tests (2h)

## AC
- Cada juez recibe top-5 entradas de memoria relevantes
- Latencia BM25 < 200ms para 1000 entradas
- Veredictos referencian memoria por id en >= 30% de casos
- Telemetria `output/critic-rag-queries.jsonl`
- Tests BATS score >= 80

## Riesgos
- Memoria irrelevante distrae al juez → veredicto peor
- Mitigacion: skip si score BM25 < umbral (entrada irrelevante)
- Cap de tokens del juez se excede al sumar memoria
- Mitigacion: memoria truncada a 500 tokens, juez ajusta context_window_target via SPEC-156

## Out of scope
- Embeddings + vector store (v2, infra no disponible)
- Re-entrenamiento de jueces
- RAG sobre codigo fuente del proyecto (deferido)

## Origen
LeCun: critic con acceso a memoria asociativa convierte juicios puntuales en juicios fundamentados en historia. Cierra el loop memory→critic ausente hoy.

## Trabajo relacionado
- Consume entradas escritas por SPEC-164 (memory feedback loop)
- Beneficiario de SPEC-166 (configurator decide que jueces reciben RAG)
