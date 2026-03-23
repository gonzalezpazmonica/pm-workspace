# SPEC-036: Agent Evaluation Framework — Medir para Mejorar

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.65
> Origen: DeepEval (14K) + Giskard (5K) — testing de agentes LLM
> Impacto: De "confio en que funciona" a "mido que funciona"

---

## Problema

pm-workspace tiene 46 agentes pero no mide su calidad objetivamente.
No sabemos si un agente alucina, si un cambio de prompt degrada el
output, ni si el Equality Shield realmente elimina sesgos.

DeepEval y Giskard resuelven esto con metricas G-Eval, deteccion de
alucinaciones y benchmarks de sesgos.

## Principio inmutable

**Los resultados se guardan en .md y JSONL.** Los evals son ficheros
en `output/evals/` y `tests/evals/`, no en bases de datos externas.
Reproducibles con un solo comando.

## Solucion

Framework de evaluacion que mide 4 dimensiones por agente.

### Dimensiones

| Dimension | Metrica | Herramienta |
|-----------|---------|-------------|
| Precision | Hallazgos correctos vs falsos positivos | Golden set por agente |
| Coherencia | Output alineado con spec/objetivo | coherence-validator |
| Sesgo | Test contrafactual (Equality Shield) | bias-check mecanizado |
| Alucinacion | Afirmaciones sin soporte en context | Verificacion contra fuentes |

### Golden sets (test fixtures)

Cada agente critico tiene un golden set en `tests/evals/{agente}/`:

```
tests/evals/
  security-attacker/
    input-01.md          -- Codigo con SQL injection conocida
    expected-01.yaml     -- Hallazgo esperado (CWE-89, linea, severidad)
    input-02.md          -- Codigo limpio (no debe encontrar nada)
    expected-02.yaml     -- Hallazgo esperado: ninguno
  code-reviewer/
    input-01.diff        -- Diff con secret hardcodeado
    expected-01.yaml     -- REJECT con mencion de secret
  business-analyst/
    input-01.md          -- PBI ambiguo
    expected-01.yaml     -- Preguntas de clarificacion esperadas
```

### Metricas por evaluacion

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
    vs_previous: "+3% precision, -1% recall"
```

### Comando

`/eval-agent {agente} [--compare {fecha}]`

- Ejecuta el golden set contra el agente
- Calcula metricas
- Compara con ejecucion anterior
- Guarda resultado en `output/evals/{agente}/{fecha}.yaml`

### Deteccion de regresion

Si precision o recall bajan >10% vs evaluacion anterior:
```
REGRESION DETECTADA en {agente}
  Precision: 85% -> 72% (-13%)
  Causa probable: cambio de prompt en Era {N}
  Accion: revisar commit {hash} que modifico el agente
```

## Integracion con SPEC-032 (Security Benchmarks)

SPEC-032 es un caso especifico de este framework:
- Golden set = vulnerabilidades conocidas de Juice Shop
- Agentes evaluados = security-attacker + pentester + nuclei
- Metricas = detection rate + false positive rate

## Esfuerzo

Alto — 2 sprints. Requiere crear golden sets (curado manual),
implementar framework de ejecucion, y calibrar metricas.

## Dependencias

- SPEC-032 (Security Benchmarks) como primer caso de uso
- eval-criteria.md (existente) para metricas G-Eval
- consensus-protocol.md (existente) para validacion cruzada
