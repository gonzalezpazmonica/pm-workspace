---
id: SPEC-SE-027
title: SPEC-SE-027: SLM Training Pipeline — Soberanía de Modelos
status: APPROVED
approved_at: "2026-04-19"
approved_reason: "Strategic priority — software scaffolding first, GPU execution deferred until hardware available"
priority: P1-Tier1
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-SE-027: SLM Training Pipeline — Soberanía de Modelos

> **Estado**: Draft
> **Prioridad**: Estratégica
> **Dependencias**: SE-005 (Sovereign Deployment), SE-006 (Governance)
> **Era**: 231

---

## Problema

Savia Dual (SE-017) permite fallback a modelos locales (Ollama) cuando
la nube falla o cuando los datos son demasiado sensibles para enviar a
APIs externas. Pero los modelos locales genéricos (gemma4, qwen2.5) no
conocen el dominio del proyecto: terminología, reglas de negocio,
patrones de código, convenciones del equipo.

**Brecha**: datos soberanos + modelo genérico = clasificación mediocre.

## Solución

Pipeline de fine-tuning local que entrena SLMs especializados por
proyecto usando datos N4 que nunca salen de la máquina del usuario.
El modelo resultante se despliega en Ollama y se integra con Savia
Dual como tercera opción de inferencia.

## Arquitectura

```
                    ┌─────────────────────────────┐
                    │  Datos del proyecto (N4)     │
                    │  specs, reglas, transcripts   │
                    └──────────┬──────────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │  1. Preparación de dataset   │
                    │  chunking + ChatML format    │
                    └──────────┬──────────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │  2. Entrenamiento (Unsloth)  │
                    │  QLoRA 4-bit, SFT o DPO      │
                    │  100% local, zero egress     │
                    └──────────┬──────────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │  3. Export GGUF + Modelfile  │
                    │  q4_k_m cuantización         │
                    └──────────┬──────────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │  4. Despliegue Ollama        │
                    │  ollama create savia-{proy}  │
                    └──────────┬──────────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │  5. Integración Savia Dual   │
                    │  Ruta: datos N4 → modelo     │
                    │  local fine-tuned            │
                    └─────────────────────────────┘
```

## Modelos base recomendados

| Hardware | Modelo base | Parámetros | VRAM estimada |
|----------|-------------|------------|---------------|
| 8GB VRAM | SmolLM3 | 3B | ~4GB (4-bit) |
| 12GB VRAM | Qwen2.5 | 7B | ~6GB (4-bit) |
| 16GB VRAM | Gemma4 | 12B | ~10GB (4-bit) |
| 24GB VRAM | Llama-3.2 | 8B | ~6GB + margen |

Selección automática por hardware (reutilizar detección de Savia Dual).

## Stack técnico

| Componente | Herramienta | Licencia |
|------------|-------------|----------|
| Motor de entrenamiento | Unsloth | Apache 2.0 |
| Trainers (SFT, DPO) | TRL (HuggingFace) | Apache 2.0 |
| Adaptadores eficientes | PEFT/LoRA | Apache 2.0 |
| Cuantización | bitsandbytes | MIT |
| Datasets | HuggingFace datasets | Apache 2.0 |
| Export | llama.cpp (GGUF) | MIT |
| Inferencia local | Ollama | MIT |
| Formato de datos | ChatML | Open standard |

Zero dependencias propietarias. Todo Apache 2.0 o MIT.

## Tipos de fine-tuning soportados

### 1. Domain SFT (Supervised Fine-Tuning)

Adaptar el modelo al dominio del proyecto: vocabulario, entidades,
patrones de código, convenciones.

**Fuentes de datos** (N4, nunca salen de la máquina):
- `projects/{p}/reglas-negocio.md` — reglas de dominio
- `projects/{p}/GLOSSARY.md` — terminología
- `projects/{p}/specs/` — especificaciones técnicas
- `projects/{p}/meetings/digests/` — contexto de reuniones
- `projects/{p}/agent-memory/` — patrones aprendidos
- Código fuente del proyecto (si aplica)

**Formato**: instrucción → respuesta (ChatML)

### 2. Preference DPO (Direct Preference Optimization)

Alinear el modelo con las preferencias del equipo: estilo de
comunicación, nivel de detalle, convenciones de naming.

**Fuentes de datos**:
- Correcciones del usuario (feedback memories)
- Code reviews con chosen/rejected
- Clasificaciones de Savia Shield (CONFIDENTIAL vs PUBLIC)

### 3. Task-Specific GRPO

Optimizar para tareas concretas de clasificación:
- Clasificación de datos sensibles (reemplazo/mejora de Savia Shield)
- Triaje de PBIs por prioridad
- Detección de riesgos en reuniones

## Pipeline de preparación de datos

```bash
# Fase 1: Recopilar documentos del proyecto
scripts/slm-data-prep.sh collect --project alpha

# Fase 2: Chunking y formato ChatML
scripts/slm-data-prep.sh format --project alpha --method sft

# Fase 3: Validación y estadísticas
scripts/slm-data-prep.sh validate --project alpha
# Output: N documentos, M chunks, L tokens, distribución

# Fase 4: Split train/eval (90/10)
scripts/slm-data-prep.sh split --project alpha
```

**Filtros de seguridad** (pre-entrenamiento):
- Eliminar PII (nombres, emails, DNIs) via regex + NER local
- Eliminar credenciales y connection strings
- Eliminar datos de otros proyectos (aislamiento N4)
- Log de auditoría: qué datos se incluyeron/excluyeron

## Pipeline de entrenamiento

```bash
# Entrenamiento SFT con detección automática de hardware
scripts/slm-train.sh sft \
  --project alpha \
  --base-model auto \
  --epochs 2 \
  --lora-rank 64

# Entrenamiento DPO sobre modelo ya SFT
scripts/slm-train.sh dpo \
  --project alpha \
  --base-model output/slm/alpha/sft-latest \
  --epochs 1

# Export a GGUF para Ollama
scripts/slm-train.sh export \
  --project alpha \
  --quantization q4_k_m

# Desplegar en Ollama
scripts/slm-train.sh deploy \
  --project alpha
```

## Registro de modelos (Model Registry)

Cada modelo entrenado se registra localmente:

```
~/.savia/slm-registry/
├── alpha/
│   ├── manifest.json          ← versiones, linaje
│   ├── sft-20260412/
│   │   ├── adapter/           ← LoRA weights
│   │   ├── training.log       ← métricas, pérdida
│   │   ├── config.json        ← hiperparámetros
│   │   ├── data-manifest.json ← qué datos se usaron
│   │   └── eval-results.json  ← benchmarks
│   └── dpo-20260413/
│       └── ...
└── beta/
    └── ...
```

**manifest.json**:
```json
{
  "project": "alpha",
  "versions": [
    {
      "id": "sft-20260412",
      "base_model": "unsloth/SmolLM3-3B",
      "method": "sft",
      "lora_rank": 64,
      "training_tokens": 1250000,
      "epochs": 2,
      "final_loss": 0.823,
      "data_sources": 12,
      "data_hash": "sha256:abc123...",
      "created_at": "2026-04-12T20:00:00Z",
      "ollama_name": "savia-alpha:sft-20260412",
      "gguf_quantization": "q4_k_m",
      "status": "deployed"
    }
  ]
}
```

## Integración con Savia Dual

Extensión de `~/.savia/dual/config.json`:

```json
{
  "primary": "anthropic",
  "fallback": "ollama",
  "project_models": {
    "alpha": "savia-alpha:latest",
    "beta": "savia-beta:latest"
  },
  "routing": {
    "n4_data": "project_model",
    "classification": "project_model",
    "general": "primary"
  }
}
```

Cuando el proxy detecta que la petición involucra datos N4 de un
proyecto con modelo fine-tuned, rutea directamente al modelo local
sin pasar por la nube.

## Requisitos de hardware

| Fase | VRAM mínima | RAM mínima | Disco |
|------|-------------|------------|-------|
| Preparación datos | 0 (CPU) | 4GB | 1GB |
| Entrenamiento 3B | 6GB | 12GB | 5GB |
| Entrenamiento 7B | 10GB | 16GB | 10GB |
| Export GGUF | 8GB RAM | 16GB | 5GB |
| Inferencia Ollama | 4GB | 8GB | 3GB |

## Evaluación post-entrenamiento

1. **Pérdida de validación** — debe bajar vs base (overfitting check)
2. **Clasificación Savia Shield** — accuracy en test set N4 vs PUBLIC
3. **Perplexity en dominio** — comparar base vs fine-tuned en docs proyecto
4. **Benchmark genérico** — verificar que capacidades generales no degradan
5. **Test manual** — 10 preguntas de dominio, comparar base vs tuned

## Compliance y governance (integración SE-006)

- Cada entrenamiento genera entrada en el audit trail (SE-006)
- Datos de entrenamiento hasheados para reproducibilidad
- Derecho al olvido: `slm-train.sh forget --project alpha` elimina
  modelo, datos preparados, y registro
- Linaje completo: datos → modelo → decisiones (trazable)

## Comandos

| Comando | Descripción |
|---------|-------------|
| `/slm-status` | Estado de modelos entrenados por proyecto |
| `/slm-train` | Iniciar pipeline de entrenamiento |
| `/slm-eval` | Evaluar modelo contra benchmarks |
| `/slm-deploy` | Desplegar modelo en Ollama |
| `/slm-forget` | Eliminar modelo y datos (RGPD) |

## Fases de implementación

### Fase 1 — Foundation (este slice)
- `scripts/slm-data-prep.sh` — preparación de datasets
- `scripts/slm-train.sh` — wrapper de Unsloth con detección de hardware
- Export GGUF + despliegue Ollama
- 15+ tests BATS

### Fase 2 — Integration
- Routing inteligente en Savia Dual
- Model registry con versionado
- Evaluación automatizada post-entrenamiento

### Fase 3 — Advanced
- DPO con feedback de usuarios
- GRPO para clasificación Savia Shield
- Entrenamiento incremental (continual learning)
- Multi-tenant model isolation

## Prohibido

```
NUNCA → Enviar datos N4 de entrenamiento a APIs externas
NUNCA → Entrenar sin log de auditoría
NUNCA → Desplegar modelo sin evaluación mínima
NUNCA → Mezclar datos de distintos proyectos en un modelo
NUNCA → Eliminar el linaje de un modelo desplegado
```

## Fuentes

- HuggingFace smol-course (Apache 2.0) — metodología SFT/DPO/LoRA
- Unsloth (Apache 2.0) — motor optimizado, kernels Triton/CUDA
- Savia Dual (SE-017) — infraestructura de failover local
- Savia Shield — clasificación de datos N4 existente
