---
spec_id: SPEC-106
title: Truth Tribunal — Multi-judge report reliability gate (≥90% threshold)
status: Phase 1 Implemented (v4.88.0, Era 242)
origin: User request (2026-04-15) — "Savia tiene que ser fiable" — urgent
severity: Alta
effort: ~40h (sprint dedicado recomendado)
phase_1_artifacts:
  - scripts/truth-tribunal.sh
  - .claude/agents/truth-tribunal-orchestrator.md
  - .claude/agents/{factuality,source-traceability,hallucination,coherence,calibration,completeness,compliance}-judge.md
  - docs/rules/domain/truth-tribunal-weights.md
  - .claude/commands/report-verify.md
  - tests/test-truth-tribunal.bats (BATS suite, certified)
phase_1_decisions:
  - sync invocation (manual /report-verify) — async hooks deferred to Phase 2
  - Opus for factuality/hallucination/compliance, Sonnet for the other 4
  - SHA256 cache, 24h TTL
  - subjective profile included with ajusted weights
---

# SPEC-106: Truth Tribunal — Report Reliability Gate

## Problema

Savia y sus agentes generan informes consumidos para tomar decisiones:
ceo-report, compliance-report, sprint-review, audit, meeting-digest,
governance-report, stakeholder-report, y decenas más. **Un error en un
informe no es un bug aislado: propaga a la decisión que lo usa.**

Hoy no existe un gate sistemático de fiabilidad para estos outputs. Cada
comando produce su informe y lo entrega. La validación se delega al
humano consumidor, que puede no tener contexto para detectar:

- **Alucinaciones**: números, fechas, nombres inventados
- **Factualidad**: afirmaciones no soportadas por las fuentes citadas
- **Trazabilidad**: claims sin `@ref` verificable
- **Coherencia**: totales que no suman, fechas contradictorias
- **Calibración**: "muy confiado" sobre datos que el sistema no tiene
- **Compleción**: informes que prometen cobertura y no la dan
- **Compliance**: PII en N1, datos N4 en output público

Los jueces que SÍ tenemos (Code Review Court: correctness, architecture,
security, cognitive, spec) están orientados a **código y specs**, no a
informes. Sus criterios no se aplican a prosa ejecutiva ni a tablas de
sprint review.

Estado del arte externo (2026) confirma que:
- Un solo juez LLM tiene alta variance (Label Your Data 2026)
- Métodos distintos (G-Eval, RAGAS, DeepEval) divergen substancialmente
  bajo misma entrada ([benchmark cleanlab.ai 2026](https://cleanlab.ai/blog/rag-tlm-hallucination-benchmarking/))
- Panel-of-Experts con weighted consensus reduce variance significativamente
- Abstención ("don't know") > score forzado cuando hay ambigüedad real

## Solucion

**Truth Tribunal**: panel de 7 jueces especializados en fiabilidad de
informes, ejecutados con **contexto fresco e independiente** por informe.
Score ponderado según tipo de informe. Iteración automática hasta
≥90% o escalamiento humano.

### 7 jueces especializados

| Juez | Criterio | Cómo mide |
|------|----------|-----------|
| `factuality-judge` | Factual accuracy | Verifica claims contra fuentes (git log, WIQL, memoria, grep proyecto) |
| `source-traceability-judge` | Every claim cited | Cada afirmación tiene `@ref` verificable. Detecta `@ref` rotas |
| `hallucination-judge` | No inventos | SelfCheckGPT pattern: re-genera partes del informe 3x, mide consistencia. Alta inconsistencia = alucinación |
| `coherence-judge` | Consistencia interna | Totales suman, fechas ordenadas, porcentajes ≤100, entidades referenciadas consistentemente |
| `calibration-judge` | Confianza calibrada | "Alta confianza" requiere ≥3 fuentes independientes. Warnings sobre afirmaciones sin respaldo |
| `completeness-judge` | Cubre lo prometido | El abstract/título promete cobertura X; el body la cumple. Detecta omisiones |
| `compliance-judge` | N1-N4b + PII + formato | Datos N4 no en output público, PII no presente, formato cumple reglas del comando |

Cada juez:
- **Contexto fresco**: fork agent sin historial (ver fork-agent-protocol.md)
- **Score 0-100** + confidence 0-1
- **Abstención permitida**: "no puedo evaluar" en lugar de score inventado
- **Razonamiento explícito**: debe citar evidencia para su score
- **Output JSON estructurado**: parseable para aggregation

### Scoring ponderado por tipo de informe

```yaml
weights:
  default:
    factuality: 0.20
    source_traceability: 0.15
    hallucination: 0.20
    coherence: 0.10
    calibration: 0.10
    completeness: 0.10
    compliance: 0.15

  executive:         # ceo-report, stakeholder-report
    completeness: 0.25
    factuality: 0.25
    calibration: 0.15
    hallucination: 0.15
    coherence: 0.10
    compliance: 0.05
    source_traceability: 0.05

  compliance:        # compliance-report, governance-report, audit
    compliance: 0.30
    factuality: 0.25
    hallucination: 0.15
    source_traceability: 0.15
    coherence: 0.05
    completeness: 0.05
    calibration: 0.05

  audit:             # project-audit, security-review, drift-check
    factuality: 0.30
    source_traceability: 0.25
    completeness: 0.15
    hallucination: 0.10
    coherence: 0.10
    calibration: 0.05
    compliance: 0.05

  digest:            # meeting-digest, pdf-digest, word-digest
    factuality: 0.25
    hallucination: 0.25
    source_traceability: 0.20
    completeness: 0.15
    compliance: 0.10
    coherence: 0.03
    calibration: 0.02
```

Detección automática del tipo por mapping comando→perfil. Override en
frontmatter del informe si aplica.

### Umbrales y verdicts

| Score | Verdict | Acción |
|-------|---------|--------|
| ≥90 | PUBLISHABLE | Entregar al humano |
| 70-89 | CONDITIONAL | Entregar con banner de warnings + findings |
| <70 | ITERATE | Feedback al agente generador, re-generate |
| <70 tras 3 iteraciones | ESCALATE | Escalar a humano con reporte de fallos |

### Veto rules (override del score)

Automático VETO y entrega bloqueada si cualquier juez encuentra:

- **PII leak en N1** (compliance-judge) → VETO, no publicar
- **Alucinación cuantificable** (hallucination-judge con confidence ≥0.8) → VETO
- **Claim sin fuente localizable** (source-traceability-judge) → VETO en compliance/audit
- **Contradicción interna clara** (coherence-judge con evidencia) → VETO

### Loop de iteración

```
1. Agente genera informe v1
2. Hook PostToolUse captura (Write en output/ path)
3. Tribunal convoca 7 jueces en paralelo (fork agents)
4. Orchestrator agrega scores + aplica vetos + weights
5. Si ≥90 y sin veto → publicar
6. Si <90 o veto:
   a. Orchestrator compila findings estructurados
   b. Feedback al agente generador con findings específicos
   c. Agente regenera (iteración N+1)
   d. Tribunal re-evalúa
   e. Max 3 iteraciones (config autonomous-safety)
   f. Tras 4ª → escalar humano con reporte completo
```

### Integración arquitectónica

**Hook nuevo**: `post-report-write.sh` (PostToolUse, async)
- Trigger: Write a `output/*.md` con frontmatter `report_type:` o heurística por path
- Acción: encola invocación del Tribunal en background
- NO bloquea la escritura (async para no penalizar comandos)

**Comando nuevo**: `/report-verify {path}`
- Invocación manual: `/report-verify output/ceo-report-20260415.md`
- Ejecuta tribunal sincrónicamente, muestra veredicto
- Útil para depurar o validar informes existentes

**Orchestrator nuevo**: `truth-tribunal-orchestrator` (agent L2)
- Convoca los 7 jueces en fork paralelo
- Aplica weights + vetos
- Compila findings para el generador si score <90
- Persiste `.truth.crc` junto al informe (análogo a `.review.crc`)

**Agentes nuevos** (7):
- `factuality-judge` (L1, Opus, 13000 budget)
- `source-traceability-judge` (L1, Sonnet, 8500)
- `hallucination-judge` (L1, Opus, 13000 — requiere 3 re-generaciones)
- `coherence-judge` (L1, Sonnet, 8500)
- `calibration-judge` (L1, Sonnet, 8500)
- `completeness-judge` (L1, Sonnet, 8500)
- `compliance-judge` (L1, Opus, 13000 — compliance es crítico)

### .truth.crc artifact (análogo a .review.crc del Court)

```yaml
---
tribunal_id: TT-20260415-143022
report_path: output/ceo-report-20260415.md
report_type: executive
iterations: 2
final_score: 92
final_verdict: PUBLISHABLE
judges:
  factuality: {score: 95, confidence: 0.9, findings: []}
  source_traceability: {score: 88, confidence: 0.85, findings: [...]}
  hallucination: {score: 94, confidence: 0.88, ...}
  coherence: {score: 97, confidence: 0.95, ...}
  calibration: {score: 85, confidence: 0.7, findings: [...]}
  completeness: {score: 91, confidence: 0.8, ...}
  compliance: {score: 98, confidence: 0.95, ...}
vetos: []
human_approved: pending
---
```

### Benchmark y calibración

Harness `scripts/tribunal-benchmark.sh` que:
1. Acepta dataset de informes pre-etiquetados (bueno/malo por criterio)
2. Ejecuta tribunal contra cada uno
3. Calcula accuracy, precision, recall, F1, Brier score por juez
4. Reporta si algún juez tiene calibration pobre (Brier >0.2)
5. Input recalibra weights o el prompt del juez

## Criterios de aceptacion

### Fase 1 — Infraestructura (MVP)
- [ ] `truth-tribunal-orchestrator` agent implementado
- [ ] Los 7 jueces implementados con prompts diferenciados
- [ ] `/report-verify {path}` comando manual
- [ ] `.truth.crc` artifact format definido + parseable
- [ ] Tests BATS >= 20 casos (incluye mocks de informes)

### Fase 2 — Integración
- [ ] Hook `post-report-write.sh` async
- [ ] Loop de iteración con max 3 retries (autonomous-safety)
- [ ] Feedback estructurado al agente generador
- [ ] Persistencia de `.truth.crc` junto al informe
- [ ] Dashboard `/tribunal-status` con histórico

### Fase 3 — Calibración
- [ ] `scripts/tribunal-benchmark.sh` con dataset etiquetado
- [ ] Métricas por juez (accuracy, precision, recall, Brier)
- [ ] Ajuste de weights basado en benchmark real
- [ ] Documentación de calibración en docs/tribunal-guide.md

## Restricciones

- **TT-01**: Jueces ejecutan con contexto fresco (fork agent). NUNCA comparten historial con el generador ni entre sí.
- **TT-02**: Max 3 iteraciones por informe. 4ª → escalar humano obligatorio.
- **TT-03**: Veto es absoluto — un solo veto bloquea publicación, sin importar score.
- **TT-04**: El informe con score <90 NO se publica hasta iterar (a menos que humano acepte CONDITIONAL explícitamente).
- **TT-05**: Compliance judge tiene PRIORIDAD ABSOLUTA en informes de tipo compliance/audit. Su score es gate independiente (≥95 required).
- **TT-06**: Si los 7 jueces abstienen en >3 criterios → NOT_EVALUABLE → escalar humano (señal de que el informe carece de contexto evaluable).

## Riesgos

| Riesgo | Mitigación |
|--------|-----------|
| **Coste API alto** (7 jueces × N iteraciones × N informes/día) | Budget cap por tribunal run; async para no bloquear; cache por hash de informe |
| **Variance entre jueces** (cada run da scores distintos) | N=3 runs por juez, usar mediana; benchmark de calibración |
| **False positives de veto** (juez bloquea injustamente) | Confidence threshold 0.8 para veto; log de decisiones para auditoría |
| **Loop infinito** (agente no mejora tras feedback) | Max 3 iter + escalate; heurística "peor score tras iterar" → abort |
| **Judges colapsan al mismo error** (shared blind spot) | Prompts independientes; modelos distintos por juez (opus/sonnet mix) |

## Out of scope

- Benchmark externo público (GAIA-like, SPEC-100)
- Ajuste automático de prompts basado en feedback (LLM-tuning)
- UI web para revisar veredictos (markdown + CLI basta)
- Integración con external judges (openai eval, RAGAS, etc.) — futura
- Tribunal para código (ya lo hace Code Review Court — 5 jueces)

## Justificacion

**La fiabilidad de Savia NO es negociable.** Un CEO-report con número
erróneo, un compliance-report con PII filtrada, un sprint-review con
velocity mal calculada → decisiones erradas con coste real.

Lo que hoy tenemos es un BEST-EFFORT sin gate medible. Tribunal convierte
fiabilidad en una métrica observable (score ≥90), iterable (findings ×
regenerate), y bloqueable (veto). Costo: +7 invocaciones LLM por
informe crítico. Beneficio: cero informes con errores conocidos publicados.

**Urgencia**: cada informe que publica Savia sin tribunal es deuda de
fiabilidad. Cuanto más tardemos, más decisiones se toman sobre base
frágil. Pero urgencia NO justifica implementación frágil — se lanza
Fase 1 (MVP manual) mientras Fase 2 (hook async) se itera.

## Rollout sugerido (3 sprints)

**Sprint 1 — MVP (~16h)**:
- 7 judge agents + orchestrator + `/report-verify`
- Tests BATS básicos
- Documentación inicial

**Sprint 2 — Integración (~16h)**:
- Hook async
- Loop iterativo
- `.truth.crc` artifact
- Dashboard

**Sprint 3 — Calibración (~8h)**:
- Benchmark harness
- Dataset etiquetado
- Ajuste weights basado en datos

## Preguntas abiertas (para review humano)

1. ¿Tribunal debe correr ASÍNCRONO (mejor UX) o SÍNCRONO (más seguro)?
   - Async: informe se publica, 30 seg después llega veredicto → si FAIL, se retira. Pero el humano ya puede haberlo visto.
   - Sync: informe bloqueado hasta veredicto. Mejor garantía, peor latencia.
   - **Propuesta**: sync para compliance/audit, async para executive/digest.

2. ¿Los jueces usan mismo modelo (Opus) o mix?
   - Mismo modelo: más barato, potencial shared blind spot.
   - Mix: más robusto, más caro.
   - **Propuesta**: mix (hallucination y compliance Opus, resto Sonnet).

3. ¿Cache por hash del informe?
   - Mismo informe 2 veces debería dar mismo veredicto.
   - Pero si cache, no validamos al regenerar (variance).
   - **Propuesta**: cache 24h por hash, invalida si hay re-generación.

4. ¿Cómo manejamos informes que SON subjetivos (sprint-retro, etc.)?
   - Subjetivo ≠ no evaluable. Coherencia + factualidad sí aplican.
   - **Propuesta**: report type `subjective` con weights ajustados.

## Referencias

- [Code Review Court — SPEC interno](`docs/rules/domain/code-review-court.md`)
- [Consensus Protocol — SPEC interno](`docs/rules/domain/consensus-protocol.md`)
- [Verification Lattice — skill interno](`.claude/skills/verification-lattice/`)
- [Fork Agent Protocol — SPEC interno](`docs/rules/domain/fork-agent-protocol.md`)
- [G-Eval chain-of-thought judge](https://arxiv.org/abs/2303.16634)
- [RAGAS faithfulness metric](https://github.com/explodinggradients/ragas)
- [DeepEval framework](https://github.com/confident-ai/deepeval)
- [LLM-as-Judge 2026 guide](https://labelyourdata.com/articles/llm-as-a-judge)
- [Hallucination benchmark — cleanlab 2026](https://cleanlab.ai/blog/rag-tlm-hallucination-benchmarking/)
- [SelfCheckGPT](https://arxiv.org/abs/2303.08896)
- [Abstention under uncertainty — Preprints.org 2026](https://www.preprints.org/manuscript/202510.0418/v1/download)

## Nota de humildad técnica

Este spec es una arquitectura ambiciosa. Su éxito depende de:
- Calibración real (no solo diseñada) vía Fase 3
- Benchmark continuo contra dataset representativo
- Iteración honesta: si un juez es ruido, retirarlo; si otro falta, añadirlo

No es un sistema que funciona perfecto al día 1. Es una infraestructura
que MEJORA CON USO. Publicar fiabilidad requiere medirla con rigor.

## Siguiente paso

Review humano de este spec. Decisiones clave a confirmar:
1. ¿Aprobar alcance de 3 sprints?
2. ¿Sync vs Async para MVP?
3. ¿Orden de tipos de informe a cubrir primero?
4. ¿AUTONOMOUS_REVIEWER para iteraciones?

Tras aprobar → arrancar Fase 1 (MVP manual) en sprint dedicado.
