---
id: SPEC-023
title: SPEC-023: Savia LLM Trainer — Context Brain Local
status: APPROVED
approved_at: "2026-04-19"
approved_reason: "Strategic priority — software scaffolding ready, GPU-dependent phases deferred"
priority: P1-Tier1
origin_date: "2026-03-22"
migrated_at: "2026-04-19"
migrated_from: body-prose
related: [SPEC-SE-027, SPEC-080, SE-028, SE-042]
---

# SPEC-023: Savia LLM Trainer — Context Brain Local

> Status: **RESEARCH** · Fecha: 2026-03-22 · Score: 4.90
> Origen: la usuaria — "entrenar LLM especializado para gestión de contexto"
> Impacto: Soberania cognitiva total. Claude para trabajo bruto, LLM local para contexto.

---

## Vision

pm-workspace genera miles de decisiones, patrones y observaciones.
Ese conocimiento hoy vive en JSONL + texto plano. Un LLM pequeno
entrenado con esos datos seria el "cerebro de contexto" de Savia:

- Routing inteligente de comandos sin depender de Claude
- Búsqueda semántica sin sentence-transformers (modelo unificado)
- Perfil de usuario inferido sin cargar fragmentos
- Respuestas rapidas a preguntas de contexto (<100ms local)

Claude sigue haciendo el trabajo pesado (código, specs, análisis).
El LLM local gestiona la capa de contexto y memoria.

---

## Fases

### Fase 1 — Dataset Generation (implementable ahora)

Extraer datos de entrenamiento desde pm-workspace:
- memory-store JSONL → pares pregunta/respuesta
- decisión-log → decisiones con contexto
- agent-notes → patrones de cada agente
- session summaries → contexto de sesiones
- specs → requisitos y arquitectura

Formato: JSONL con `{"instruction": "...", "response": "..."}`
Objetivo: 5K-10K pares de entrenamiento de calidad.

Script: `scripts/generate-training-data.py`
Output: `output/training/savia-context-v1.jsonl`

### Fase 2 — Fine-tune (requiere GPU o cloud temporal)

Modelo base: Mistral 7B o Llama 3.1 8B (ambos open-weight).
Framework: Unsloth (4x mas rapido, 60% menos memoria).
Metodo: QLoRA (4-bit quantized LoRA) — funciona en 16GB VRAM.

Alternativa sin GPU: usar Ollama + `ollama create` con Modelfile
que inyecta system prompt largo con el dataset como contexto.

### Fase 3 — Eval Framework

Benchmark de calidad del modelo:
- Recall en búsqueda de contexto vs grep vs vector
- Accuracy en routing de comandos
- Calidad de perfiles inferidos
- Latencia (objetivo: <100ms en CPU)

Script: `scripts/eval-savia-model.py`

### Fase 4 — Integration

El LLM local se integra como "primer filtro" antes de Claude:
1. Usuario escribe query
2. LLM local intenta resolver (routing, contexto, perfil)
3. Si confianza >80%: respuesta directa
4. Si confianza <80%: escalar a Claude con contexto enriquecido

---

## Principios

- **Zero vendor lock-in** — modelo open-weight, entrenamiento local
- **Texto plano como verdad** — el JSONL sigue siendo la fuente
- **Complementario** — no reemplaza Claude, lo complementa
- **Offline** — funciona sin internet (compatible SPEC-017)
- **Incremental** — cada sesión genera mas datos de entrenamiento

## Requisitos

- Fase 1: Python 3, acceso al workspace (sin GPU)
- Fase 2: GPU 16GB VRAM o cloud temporal (Vast.ai, ~$1/hora)
- Fase 3: Python 3, modelo generado
- Fase 4: Ollama instalado localmente
