# SPEC-036: Agent Evaluation Framework — Medir para Mejorar

> Status: **APPROVED** · Fecha: 2026-03-24 · Score: 4.65
> Origen: DeepEval (14K) + Giskard (5K) — testing de agentes LLM
> Impacto: De "confio en que funciona" a "mido que funciona"

---

## Problema

pm-workspace tiene 46 agentes pero no mide su calidad objetivamente.
No sabemos si un agente alucina, si un cambio de prompt degrada el
output, ni si el Equality Shield realmente elimina sesgos.

DeepEval y Giskard resuelven esto con métricas G-Eval, detección de
alucinaciones y benchmarks de sesgos.

## Principio inmutable

**Los resultados se guardan en .md y JSONL.** Los evals son ficheros
en `output/evals/` y `tests/evals/`, no en bases de datos externas.
Reproducibles con un solo comando.

## Solución

Framework de evaluación que mide 4 dimensiones por agente.

### Dimensiones

| Dimensión | Métrica | Herramienta |
|-----------|---------|-------------|
| Precisión | Hallazgos correctos vs falsos positivos | Golden set por agente |
| Coherencia | Output alineado con spec/objetivo | coherence-validator |
| Sesgo | Test contrafactual (Equality Shield) | bias-check mecanizado |
| Alucinación | Afirmaciones sin soporte en context | Verificación contra fuentes |

### Golden sets (test fixtures)

Cada agente crítico tiene un golden set en `tests/evals/{agente}/`:

```
tests/evals/
  security-attacker/
    input-01.md          -- Código con SQL injection conocida
    expected-01.yaml     -- Hallazgo esperado (CWE-89, línea, severidad)
    input-02.md          -- Código limpio (no debe encontrar nada)
    expected-02.yaml     -- Hallazgo esperado: ninguno
  code-reviewer/
    input-01.diff        -- Diff con secret hardcodeado
    expected-01.yaml     -- REJECT con mención de secret
  business-analyst/
    input-01.md          -- PBI ambiguo
    expected-01.yaml     -- Preguntas de clarificación esperadas
```

### Métricas por evaluación

```yaml
eval_result:
  agent: security-attacker
  date: 2026-03-23
  golden_set: tests/evals/security-attacker/
  metrics:
    precision: 0.85      # hallazgos correctos / total hallazgos
    recall: 0.90          # hallazgos encontrados / hallazgos en golden set
    f1: 0.87
    false_positives: 2
    hallucinations: 0     # afirmaciones sin soporte
    bias_score: 0.0       # 0 = sin sesgo detectado
  comparison:
    vs_previous: "+3% precisión, -1% recall"
```

### Comando

`/eval-agent {agente} [--compare {fecha}]`

- Ejecuta el golden set contra el agente
- Calcula métricas
- Compara con ejecución anterior
- Guarda resultado en `output/evals/{agente}/{fecha}.yaml`

### Detección de regresión

Si precisión o recall bajan >10% vs evaluación anterior:
```
REGRESIÓN DETECTADA en {agente}
  Precisión: 85% -> 72% (-13%)
  Causa probable: cambio de prompt en Era {N}
  Acción: revisar commit {hash} que modificó el agente
```

## Integración con SPEC-032 (Security Benchmarks)

SPEC-032 es un caso específico de este framework:
- Golden set = vulnerabilidades conocidas de Juice Shop
- Agentes evaluados = security-attacker + pentester + nuclei
- Métricas = detection rate + false positive rate

## Esfuerzo

Alto — 2 sprints. Requiere crear golden sets (curado manual),
implementar framework de ejecución, y calibrar métricas.

## Dependencias

- SPEC-032 (Security Benchmarks) como primer caso de uso
- eval-criteria.md (existente) para métricas G-Eval
- consensus-protocol.md (existente) para validación cruzada
