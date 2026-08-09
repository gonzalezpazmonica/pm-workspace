---
id: SE-314
title: "SE-314 — Clasificador de soberanía de datos: rediseño determinista"
status: IMPLEMENTED
priority: alta
---

# SE-314 — Clasificador de soberanía de datos: rediseño determinista

**Status:** IMPLEMENTED
**Fecha:** 2026-08-08
**Area:** Security / Data sovereignty / AI governance
**Branch sugerida:** `agent/se314-sovereignty-classifier-redesign`
**Estimacion total:** ~48h (5 slices)
**Inspiracion:** Presidio (confidence scoring + thresholds), OWASP LLM06 hybrid approach, Ollama determinism (seed + top_k=1)

---

## 1. Contexto y evidencia (2026-08-08, reproducible)

El clasificador local `scripts/ollama-classify.sh` etiqueta contenido como
CONFIDENTIAL/PUBLIC/AMBIGUOUS vía un modelo local (qwen2.5:3b). Lo invocan
los gates de soberanía (TS y bash) y hooks de análisis como capa de decisión
sobre ediciones en destinos públicos (N1).

### 1.1 Falsos positivos bloqueantes

Durante la implementación de SE-313, ficheros legítimos fueron bloqueados con
mensajes de contenido confidencial detectado:

| Fichero | Contenido | Veredicto |
|---|---|---|
| `scripts/savia-env.sh` | función de resolución de modelos con referencia a config | CONFIDENTIAL (2x) |
| `scripts/subagent-dispatch-gate.sh` | header bash de resolución de tiers | CONFIDENTIAL (2x) |
| `docs/rules/domain/model-alias-schema.md` | documentación de schema de modelos | CONFIDENTIAL (2x) |
| este mismo spec (SE-314) | describe el propio clasificador | CONFIDENTIAL (self-block) |

### 1.2 No determinismo (medido)

El mismo texto, el mismo modelo, temperature=0, sin semilla explícita:

- bloque de código con referencia a config → CONFIDENTIAL 10/10
- fragmentos más cortos del mismo bloque (200 chars) → PUBLIC
- umbral de activación ~350 chars: 300 chars → PUBLIC; 350 chars → CONFIDENTIAL
- mismo fichero completo: CONFIDENTIAL, CONFIDENTIAL, luego PUBLIC x4 (sin
  cambio de input)

Es sensible a la longitud del contexto y a tokens de configuración. Para el
operador es indistinguible de aleatorio: el mismo archivo a veces pasa, a
veces bloquea.

### 1.3 Histórico (656 decisiones en output/data-sovereignty-validation/classifier-decisions.jsonl)

- 467 PUBLIC (71%)
- 99 CONFIDENTIAL (15%)
- 72 AMBIGUOUS (11%)

El 15% de CONFIDENTIAL sobre código técnico del workspace es inaceptable como
gate bloqueante: la capa debe detener fugas reales (credenciales, PII, datos
de cliente), no bloquear código que menciona configuración.

### 1.4 Causa raíz

1. Modelo pequeño (qwen2.5:3b, Q4_K_M): confunde "código que lee un fichero
   de config" (`_read_pref`, `preferences.yaml`, `provider`) con "fuga de
   credenciales". No distingue referenciar un path de filtrar su contenido.
2. Sin determinismo configurado: Ollama con temperature=0 NO garantiza
   reproducibilidad (requiere seed fijo + top_k=1; ver ollama#586, #5321).
   El script no envía seed ni top_k.
3. Prompt de clasificación con categorías solapadas: "business rules" e
   "internal IPs" como CONFIDENTIAL hacen que cualquier bloque técnico que
   hable de configuración interna caiga en CONFIDENTIAL.
4. Fallo seguro invertido: ante salida inesperada el script asume
   CONFIDENTIAL. El gate bloquea por defecto, con falsos positivos altos,
   sin fallback de verificación.
5. Sin scoring de confianza: etiqueta sin probabilidad. No se puede ajustar
   el umbral precision/recall (guardml.io, Presidio: dial 0.7-0.85).
6. Caché de decisión ausente: el mismo contenido se re-clasifica cada vez.
7. Dos implementaciones divergentes: gate TS evalúa solo `newString`; el gate
   bash evalúa contenido completo normalizado. El TS pasó el mismo bloque 2x
   por Ollama → 2 bloqueos.

---

## 2. Objetivo

Reemplazar la capa de clasificación por un sistema determinista, verificable y
con umbral ajustable que:

1. Nunca bloquee contenido técnico legítimo del workspace por mencionar
   configuración (preferences, provider, paths internos).
2. Sea reproducible: mismo input + misma versión → mismo veredicto
   (seed fijo + top_k=1 + prompt versionado).
3. Devuelva confianza (0-1) además de etiqueta, para ajustar precision/recall
   por destino.
4. Separe responsabilidades: las fugas reales (regex determinista + NER)
   bloquean; el LLM solo evalúa "contexto de negocio/personas" en contenido
   que superó la detección determinista, con fallback a WARN (no BLOCK) en N1.
5. Cachee decisiones por hash de contenido para eliminar re-clasificación.
6. Registre telemetría compatible con SE-313 (eventos classifier.*).

**Métrica de éxito**: 0 falsos positivos bloqueantes en 4 semanas sobre código
técnico del workspace (hoy: 6 observados en una sesión); tasa de CONFIDENTIAL
sobre contenido técnico < 2%; latencia p95 < 500ms en el gate.

---

## 3. Estado del arte (investigación 2026-08-08)

### 3.1 Determinismo en Ollama/llama.cpp
- temperature=0 por sí solo NO garantiza reproducibilidad en Ollama.
- Para salida reproducible: seed fijo + top_k=1 (greedy puro).
- num_predict bajo + format json para salida estructurada estable.
- Fuentes: github.com/ollama/ollama#586, #5321; makandracards.com.

### 3.2 PII con scoring
- Microsoft Presidio: estándar OSS para PII. Confianza por entidad, umbral
  ajustable (guardml.io: 0.7 catch-more, 0.85 trim-FP).
- El threshold es el dial precision/recall.
- OWASP LLM06: enfoque híbrido detección (regex+NER) + LLM-judge con Dynamic
  Threshold Controller — la arquitectura que necesita Savia.

### 3.3 Arquitectura recomendada (hybrid detection, no LLM-only)

```
Capa 1 (determinista): regex credenciales + IPs + base64  → bloquea siempre
Capa 2 (determinista): NER local (Presidio/spaCy) con threshold por entidad
Capa 3 (LLM, SOLO contexto): evalúa "¿dato de negocio/persona real?" y
   devuelve {label, confidence}
Gate: decide por umbral, no por etiqueta binaria.
```

### 3.4 Lección del caso Savia
El error de diseño es usar un LLM 3B como gate binario fail-closed sobre todo
el contenido. Debe ser un clasificador de contexto con umbral que actúa solo
cuando la detección determinista no es concluyente, y en destinos N1 debe
degradar a WARN (no BLOCK) ante incertidumbre.

---

## 4. Diseño propuesto

### 4.1 Nueva interfaz del clasificador

`scripts/sovereignty-classify.sh` (reemplaza a `ollama-classify.sh` como API
pública; `ollama-classify.sh` queda como shim deprecado):

```
Entrada: contenido por stdin + flags:
  --context-path <path>    # destino (N1/N4) → umbral
  --model <id>             # default qwen2.5:3b
Salida (JSON, determinista):
{
  "schema": "savia.classify/2.0",
  "hash": "sha256:...",
  "label": "public|confidential|ambiguous",
  "confidence": 0.87,
  "deterministic_matches": ["aws_key", "internal_ip"],
  "llm_verdict": "confidential|public|ambiguous",
  "llm_confidence": 0.87,
  "cache_hit": true|false,
  "model": "qwen2.5:3b",
  "seed": 42,
  "prompt_version": "classify-prompt-v2"
}
```

### 4.2 Determinismo (Slice 1)
- Enviar a Ollama options { temperature: 0, seed: 42, top_k: 1 }.
- format json para salida estructurada.
- num_predict 32 (espacio para JSON).
- Prompt versionado en config/classifier/prompt-v2.txt (fuente única).
- Hash de contenido (sha256 del texto normalizado) como clave de caché.

### 4.3 Scoring y umbral (Slice 2)
- El LLM devuelve {label, confidence} (0-1). El gate decide:
  - confidence >= 0.90 → BLOCK (solo si label=confidential)
  - 0.70 <= confidence < 0.90 → WARN (N1) / BLOCK (N4)
  - confidence < 0.70 → allow
- Umbral configurable en config/sovereignty-thresholds.yaml por destino.
- Capas 1-2 deterministas SIEMPRE bloquean en N1 (fuga real != contexto).

### 4.4 Separación regex/LLM (Slice 3)
- Detección determinista (credenciales, IPs, base64, Presidio) → función que
  devuelve deterministic_matches[] con severidad.
- Match de severidad alta → BLOCK sin LLM.
- El LLM SOLO se llama sin match concluyente Y contenido > longitud mínima.
- Allowlist léxica de "sujetos técnicos" en el prompt (código que referencia
  config paths, provider ids, model registry, hooks) → PUBLIC salvo secretos
  reales (ya cubiertos por regex).

### 4.5 Caché de decisión (Slice 4)
- output/classifier-cache/{sha256}.json (hash, veredicto, timestamp, modelo).
- TTL configurable (default 30 días). Invalida si cambia modelo o prompt.
- Elimina la re-clasificación del mismo contenido (caso savia-env.sh 10x).

### 4.6 Telemetría SE-313 (Slice 5)
- Eventos classifier.verdict, classifier.block, classifier.false_positive
  a output/telemetry-events.jsonl.
- Migrar classifier-decisions.jsonl a formato con hash, confidence, cache_hit.

### 4.7 Alineación con gates (Slice 5)
- data-sovereignty-gate.ts: usar el nuevo clasificador con --context-path;
  decidir por umbral; ante LLM indisponible → WARN en N1 (nunca BLOCK).
- data-sovereignty-gate.sh: misma interfaz (evitar divergencia TS/bash).
- shield-ner-hook.sh: apuntar al nuevo clasificador.

---

## 5. Slices de implementación

### S1 — Determinismo (8h)
- config/classifier/prompt-v2.txt (prompt versionado).
- scripts/sovereignty-classify.sh con seed + top_k=1 + format=json +
  num_predict=32 + hash de contenido.
- Salida JSON estricta (schema savia.classify/2.0).
- AC-S1.1: mismo input 10x → misma salida JSON (byte-idéntico salvo ts).
- AC-S1.2: el caso savia-env.sh clasifica public/confidence<0.70 10/10.
- AC-S1.3: salida JSON válida con jq empty; jq .hash = sha256 del input.

### S2 — Scoring + umbrales (10h)
- config/sovereignty-thresholds.yaml (n1/n4).
- El gate decide por umbral, no por etiqueta binaria.
- AC-S2.1: confidential confidence 0.95 en N1 → BLOCK.
- AC-S2.2: ambiguous confidence 0.55 en N1 → WARN + allow.
- AC-S2.3: confidence < 0.70 → allow (documentado).
- AC-S2.4: política en YAML validado (no hardcode).

### S3 — Separación regex/LLM (10h)
- Refactor: la detección determinista devuelve deterministic_matches[] con
  severidad; el LLM solo se llama sin match alto.
- Allowlist de sujetos técnicos en el prompt.
- AC-S3.1: savia-env.sh, subagent-dispatch-gate.sh, model-alias-schema.md
  NUNCA bloquean (3 ficheros del caso real).
- AC-S3.2: un secreto real (API key, private key) SIEMPRE bloquea en N1 sin
  depender del LLM.
- AC-S3.3: deterministic_matches presente en la salida JSON.

### S4 — Caché (10h)
- output/classifier-cache/{sha256}.json con TTL.
- AC-S4.1: clasificar el mismo contenido 2x → 2ª cache_hit=true, sin Ollama.
- AC-S4.2: cambio de prompt_version o modelo invalida la caché.
- AC-S4.3: TTL vencido re-clasifica.

### S5 — Integración gates + telemetría (10h)
- gates TS y bash usan el nuevo clasificador con umbral y --context-path;
  LLM indisponible → WARN en N1.
- shield-ner-hook.sh → nuevo clasificador.
- Eventos SE-313 classifier.verdict|block|false_positive.
- AC-S5.1: gate TS y bash producen el mismo veredicto (paridad).
- AC-S5.2: LLM caído → edición en N1 no bloqueada (WARN) + evento.
- AC-S5.3: evento classifier.false_positive al corregir un bloqueo.
- AC-S5.4: reporte mensual de FP (script) con casos corregidos.

---

## 6. Dependencias

- S1 → S2: el scoring necesita salida determinista con confidence.
- S3 → S1: separación regex/LLM requiere prompt versionado.
- S4 → S1: caché necesita hash de contenido.
- S5 → S2, S4: gates consumen umbrales y caché.
- S5 → SE-313: eventos usan otel-emit.sh.
- No requiere modelos nuevos (qwen2.5:3b ya disponible); Presidio opcional.

---

## 7. Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Seed/top_k no garantiza determinismo en hardware distinto | Media | Bajo | Aceptar determinismo en la misma máquina; documentar |
| Quitar BLOCK por defecto permite una fuga real por LLM | Baja | Alto | Capas 1-2 deterministas SIEMPRE bloquean |
| Allowlist de sujetos técnicos demasiado amplia | Media | Medio | Allowlist léxica; un secreto real sigue bloqueando (regex) |
| Caché con contenido sensible persistida | Media | Bajo | output/ gitignored; TTL; solo guarda veredicto+hash |
| Presidio no disponible | Media | Bajo | Degrada a regex sola; LLM cubre con umbral alto |

---

## 8. Criterios de aceptación (resumen)

- [x] AC-S1: determinismo byte-idéntico 10/10; caso savia-env.sh PUBLIC.
- [x] AC-S2: umbrales por destino en YAML; decisión por confidence.
- [x] AC-S3: 3 ficheros del caso real nunca bloquean; secretos reales siempre.
- [x] AC-S4: caché con hash y TTL; 2ª clasificación sin LLM.
- [x] AC-S5: paridad TS/bash; degradación WARN en N1; telemetría SE-313.
- [x] AC-EV: corpus de regresión en tests/evals/classifier-corpus.json (>=20
      casos: código técnico, secretos reales, PII, prompts) con veredictos
      esperados; CI lo ejecuta.

---

## 9. Métrica de éxito

- 0 falsos positivos bloqueantes en 4 semanas sobre código técnico.
- Tasa CONFIDENTIAL sobre contenido técnico < 2% (hoy 15%).
- Latencia gate p95 < 500ms.
- 100% de secretos reales del corpus bloqueados en N1.

---

## 10. OpenCode Implementation Plan

### Clasificación
- Type: Scripts bash + plugin TS + config.
- Autonomy: L1-L2; S5 (gates) con revisión humana.
- Reversibility: Alta — ollama-classify.sh queda como shim.

### Bindings
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| scripts/sovereignty-classify.sh | bash | idéntico |
| config/classifier/prompt-v2.txt | fichero | idéntico |
| config/sovereignty-thresholds.yaml | fichero | idéntico |
| data-sovereignty-gate.ts | — | plugin TS |
| data-sovereignty-gate.sh | hook bash | — |
| caché + telemetría | output/ | idéntico |

### Portability
- [x] DUAL_BINDING: script agnóstico; el determinismo depende solo de Ollama local.

---

## 11. Referencias

- Ollama determinism: github.com/ollama/ollama#586, #5321
- Presidio threshold dial: guardml.io/posts/output-classification-pii-secrets-detector
- OWASP LLM06 hybrid approach: app.readytensor.ai
- SE-313 (telemetría): docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md
- Código actual: scripts/ollama-classify.sh, data-sovereignty-gate.ts/.sh,
  scripts/shield-ner-hook.sh
- Evidencia: output/data-sovereignty-validation/classifier-decisions.jsonl
