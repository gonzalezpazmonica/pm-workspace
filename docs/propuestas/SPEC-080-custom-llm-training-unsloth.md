---
id: SPEC-080
title: SPEC-080 — Entrenamiento de LLMs Especializados con Unsloth
status: APPROVED
approved_at: "2026-04-19"
approved_reason: "Strategic priority SLM pipeline — Unsloth toolchain scaffolding ready"
priority: P1-Tier1
migrated_at: "2026-04-19"
migrated_from: body-prose
related: [SPEC-SE-027, SPEC-023, SE-028, SE-042]
---

# SPEC-080 — Entrenamiento de LLMs Especializados con Unsloth

> **Estado**: Investigación
> **Fecha**: 2026-04-07
> **Tipo**: Investigación + Infraestructura
> **Prioridad**: Alta — habilita agentes especializados con modelos propios
> **Origen**: la usuaria — "cómo entrenar nuestros propios LLM para agentes específicos"

---

## 1. Problema

pm-workspace depende al 100% de modelos cloud (Claude Opus/Sonnet/Haiku).
Esto implica:
- Coste por token en cada invocación de agente
- Latencia de red en cada operación
- Dependencia total de Anthropic (Principio #2: independencia del proveedor)
- Sin capacidad de especializar modelos para tareas repetitivas del workspace
- Datos de proyecto viajan a la nube (aunque clasificados por Savia Shield)

## 2. Solución propuesta: Unsloth

[Unsloth](https://github.com/unslothai/unsloth) (Apache 2.0 core) permite
fine-tuning de LLMs localmente con 70% menos VRAM y 2x más rápido.

### Por qué Unsloth

| Dimensión | Valor |
|-----------|-------|
| Velocidad | 2x más rápido que HuggingFace vanilla |
| VRAM | 70% menos (QLoRA) — viable en hardware de consumo |
| Modelos | 500+ modelos soportados (Qwen, Llama, Gemma, Mistral, Phi) |
| Export | GGUF (Ollama), SafeTensors, vLLM — compatible con nuestro stack |
| RL | GRPO con 80% menos VRAM — para entrenar con feedback |
| Licencia | Apache 2.0 (core) — compatible con pm-workspace |
| Local | Todo en local — cero datos a la nube |

### Hardware disponible (verificado 2026-04-07)

| Recurso | Valor | Implicación |
|---------|-------|-------------|
| GPU | Intel UHD (integrada) | NO apta para fine-tune |
| RAM | 16GB | Suficiente para inference |
| Ollama | qwen2.5:3b, qwen2.5:7b, gemma4:e2b, gemma4:e4b | Inference OK |
| Disco | 316GB libres | Suficiente para modelos |
| NVIDIA | No disponible | Fine-tune requiere Colab/Cloud |

### Estrategia: Train in Cloud, Run Local

Fine-tune en **Google Colab** (T4 gratis, 16GB VRAM) → exportar GGUF →
descargar → `ollama create` → inference local. Lo mejor de ambos mundos:
entrenamiento gratis en GPU cloud, ejecución privada sin coste.

## 3. Agentes candidatos a modelo propio

### Tier 1 — Alto volumen, tarea repetitiva (mejor ROI)

| Agente | Modelo actual | Tarea | Modelo candidato |
|--------|--------------|-------|-----------------|
| `commit-guardian` | Sonnet | 10 checks pre-commit | Qwen 3B fine-tuned |
| `tech-writer` | Haiku | README, CHANGELOG | Qwen 3B fine-tuned |
| `azure-devops-operator` | Haiku | Queries WIQL | Qwen 3B fine-tuned |

**Por qué**: Se invocan frecuentemente, hacen tareas formulaicas,
toleran modelos pequeños si están bien entrenados.

### Tier 2 — Conocimiento especializado (mayor diferenciación)

| Agente | Modelo actual | Tarea | Modelo candidato |
|--------|--------------|-------|-----------------|
| `legal-compliance` | Opus | Auditoría legal española | Qwen 7B + legalize-es |
| `security-attacker` | Sonnet | Detección OWASP | Qwen 7B + vuln datasets |
| `code-reviewer` | Opus | Code review multi-lang | Qwen 7B + review corpus |

**Por qué**: Se benefician enormemente de dominio especializado.
El legal-compliance con un modelo entrenado en legislación española
sería más preciso que Opus genérico para esa tarea.

### Tier 3 — Fuera de alcance (requiere razonamiento profundo)

| Agente | Por qué NO entrenar |
|--------|---------------------|
| `architect` | Requiere razonamiento arquitectónico novel |
| `business-analyst` | Requiere comprensión de contexto empresarial amplio |
| `reflection-validator` | Requiere meta-cognición profunda |

## 4. Arquitectura de entrenamiento

```
Datos de entrenamiento
  ├── Agent traces (output/agent-traces/) → pares input/output reales
  ├── Code reviews aprobados → pares código/review
  ├── legalize-es corpus → legislación para legal-compliance
  └── OWASP datasets → vulnerabilidades para security

Unsloth (local)
  ├── Base model: Qwen 2.5 (3B o 7B según agente)
  ├── Método: QLoRA (eficiente en VRAM)
  ├── Formato: Alpaca/ShareGPT (instruction tuning)
  └── Export: GGUF → Ollama

Ollama (local)
  ├── Modelo fine-tuned cargado como modelo custom
  ├── API compatible con el stack actual
  └── Savia invoca vía scripts existentes
```

### Pipeline de datos

```
1. RECOPILAR — agent traces + outputs aprobados
2. FILTRAR — solo ejecuciones exitosas (quality gate)
3. FORMATEAR — convertir a formato Alpaca/ShareGPT
4. ENTRENAR — Unsloth QLoRA (local)
5. EVALUAR — benchmark contra modelo base
6. EXPORTAR — GGUF → Ollama
7. COMPARAR — A/B test: modelo custom vs cloud
8. DEPLOY — si mejora: usar modelo custom como default
```

## 5. Formato de datos de entrenamiento

### Instruction Tuning (Alpaca format)

```json
{
  "instruction": "Review this C# code for security vulnerabilities",
  "input": "public string GetUser(string id) {\n  var query = $\"SELECT * FROM users WHERE id = {id}\";\n  return db.Execute(query);\n}",
  "output": "REJECT — SQL Injection (CWE-89). The query interpolates user input directly. Fix: use parameterized query `db.Execute(\"SELECT * FROM users WHERE id = @id\", new { id })`."
}
```

### Conversation format (ShareGPT)

```json
{
  "conversations": [
    {"from": "system", "value": "You are a legal compliance auditor for Spanish legislation."},
    {"from": "human", "value": "Check if this privacy policy complies with LOPDGDD Article 13"},
    {"from": "gpt", "value": "The policy is missing: identity of the data controller..."}
  ]
}
```

## 6. Métricas de evaluación

| Métrica | Objetivo | Cómo medir |
|---------|----------|-----------|
| Accuracy | >=90% del modelo cloud | Comparar outputs en 100 casos de test |
| Latencia | <2s por invocación | Benchmark local |
| VRAM | <8GB durante inference | nvidia-smi |
| Coste | $0 por invocación | vs coste cloud actual |
| Calidad | Sin degradación perceptible | Human eval (la usuaria) |

## 7. Fases de implementación

### Fase 1 — Investigación (esta spec)
- Verificar hardware disponible
- Instalar Unsloth
- Fine-tune un modelo toy (Qwen 3B en datos de commit-guardian)
- Evaluar calidad vs Haiku/Sonnet

### Fase 2 — Primer agente real
- Recopilar datos de entrenamiento del agente elegido
- Fine-tune con QLoRA
- A/B test contra modelo cloud
- Si mejora: deploy en Ollama

### Fase 3 — Pipeline automatizado
- Script para recopilar traces → formatear → entrenar → evaluar
- Reentrenamiento periódico con datos nuevos
- Dashboard de calidad modelo custom vs cloud

### Fase 4 — Multi-agente
- Fine-tune modelos especializados para cada Tier 1 y Tier 2
- Routing: Savia decide qué modelo usar (local vs cloud) según tarea
- Fallback: si modelo local falla, escalar a cloud

## 8. Riesgos

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Hardware insuficiente | Alto | QLoRA reduce VRAM. Mínimo: 8GB VRAM |
| Calidad inferior | Alto | A/B test obligatorio. Cloud como fallback |
| Datos insuficientes | Medio | Empezar con agentes de alto volumen (más traces) |
| Overfitting | Medio | Validación cruzada + eval en datos no vistos |
| Mantenimiento | Medio | Reentrenamiento automático en pipeline |

## 9. Integración con pm-workspace existente

| Componente | Cambio |
|-----------|--------|
| `pm-config.md` | Nuevas constantes: CUSTOM_MODEL_PATH, CUSTOM_MODEL_ENABLED |
| `assignment-matrix.md` | Columna "Modelo custom" por agente |
| `agent-cost` | Tracking de invocaciones custom vs cloud |
| Ollama (ya instalado) | Cargar modelos custom con `ollama create` |
| `data-sovereignty.md` | Modelos custom son N2 (empresa, nunca en git) |

---

*SPEC-080 — Investigación · 2026-04-07 · Fuente: unslothai/unsloth*
