---
spec_id: SE-106
title: Tiered tribunal execution — sequential Tier 0 + parallel Tier 1, early-stop on veto
status: APPROVED
priority: media
effort: M
estimated_time: 5h
depends_on: [SPEC-106, SPEC-124, SPEC-125, SPEC-127]
source: user request 2026-05-30 (token savings on tribunal runs)
---

# SE-106 — Tiered tribunal execution

## Problema

Los 3 tribunales agénticos de Savia ejecutan **todos los jueces en paralelo siempre**, incluso cuando uno solo de los jueces críticos vetaría el resultado. Coste actual por run:

| Tribunal | Jueces | Modelo | Tokens/run (P50) |
|---|---|---|---|
| Truth Tribunal | 7 | 3 heavy + 4 mid | ~91k |
| Code Review Court | 4-5 | 4 mid (+1 ext) | ~25k |
| Recommendation Tribunal | 4 | 4 fast | ~6k |

El modelo actual es correcto para sync con latencia dura (Recommendation Tribunal p95 <3s), pero **derrocha tokens en los async** (Truth, Court) cuando un juez vetador rechaza el contenido en el primer slot — los otros 4-6 jueces ya han corrido en paralelo y su trabajo se descarta.

Distribución estimada (basada en patrones observados):
- ~15% de runs producen veto en uno de los 3 jueces "vetadores" (compliance, hallucination, factuality para Truth; security, correctness para Court).
- En esos runs, los 4-5 jueces no-vetadores corren para nada.
- Coste descartado por run vetado: Truth ~78k tok, Court ~15k tok.
- En 100 runs Truth/mes: ~15 vetos × 78k = **~1.17M tokens/mes evitables** solo en Truth.

## Solución

Modelo **tiered híbrido** aplicable a Truth Tribunal y Code Review Court (NO a Recommendation Tribunal — su constraint es latencia, no tokens):

### Tier 0 — secuencial, early-stop on veto

Jueces ordenados por probabilidad de veto × coste evitado. Si cualquiera vota VETO, el run termina inmediatamente. Tier 1 no se ejecuta.

**Truth Tribunal — Tier 0 (orden propuesto):**

| # | Juez | Modelo | Razón orden |
|---|---|---|---|
| 1 | compliance-judge | heavy | PII/N-tier leak — veto regulatorio absoluto |
| 2 | hallucination-judge | heavy | Fabricaciones confidence ≥0.8 — frecuente en reports IA |
| 3 | factuality-judge | heavy | Claims contradichos por evidencia |

**Code Review Court — Tier 0:**

| # | Juez | Modelo | Razón orden |
|---|---|---|---|
| 1 | security-judge | mid | OWASP/credentials — bloqueante de merge |
| 2 | correctness-judge | mid | Lógica/tests rotos — el resto no importa si no compila |

### Tier 1 — paralelo, fan-out (solo si Tier 0 PASS)

**Truth Tribunal — Tier 1 (4 jueces en paralelo):**
source-traceability, coherence, calibration, completeness.

**Code Review Court — Tier 1 (2-3 jueces en paralelo):**
spec-judge (skip si no hay spec), architecture-judge, cognitive-judge. Si `COURT_INCLUDE_PR_AGENT=true`, pr-agent-judge también.

### Recommendation Tribunal — sin cambio

Hard rule "4 judges in parallel, never sequential" se mantiene. El budget de latencia p95 < 3s es incompatible con secuencial. Documentado en el spec como decisión explícita.

## Ahorros esperados

| Métrica | Actual | Tiered | Δ |
|---|---|---|---|
| Truth P50 PASS tokens | 91k | 91k | 0% |
| Truth P50 VETO tokens | 91k | ~30k | **-67%** |
| Truth P50 PASS latencia | 60s | 70-80s | +15-25% |
| Truth P50 VETO latencia | 60s | 15-20s | **-70%** |
| Court P50 PASS tokens | 25k | 25k | 0% |
| Court P50 VETO tokens | 25k | ~10k | **-60%** |
| Estimado mensual Truth (100 runs, 15% veto) | 9.1M tok | 7.9M tok | -13% (1.2M tok/mes) |
| Estimado mensual Court (200 runs, 10% veto) | 5.0M tok | 4.7M tok | -6% (300k tok/mes) |

## Diseño técnico

### Reutilización SPEC-127 Slice 4

El modo "single-shot" del helper `scripts/savia-orchestrator-helper.sh mode` ya implementa **early-stop on veto secuencial** para frontends sin Task fan-out (Copilot Enterprise, LocalAI). Este spec extrae esa lógica como modo independiente aplicable también en modo "fan-out":

```bash
scripts/savia-orchestrator-helper.sh tier   # → "tier0" | "tier1"
scripts/savia-orchestrator-helper.sh judges TIER TRIBUNAL  # lista ordenada
```

### Cambios en orchestrators

**truth-tribunal-orchestrator.md**:
- Reemplazar paso 2 ("Convene the 7 judges via Task in parallel") por dos pasos:
  - 2a. Tier 0 secuencial: compliance → hallucination → factuality. Si cualquiera VETO → goto 4 (aggregate parcial).
  - 2b. Tier 1 paralelo: source-trace + coherence + calibration + completeness (fan-out).
- Aggregate function recibe verdicts parciales si veto early (campo `early_stopped: true`).

**court-orchestrator.md**:
- Reemplazar paso 2 ("launch 5 judge subagents in parallel") por:
  - 2a. Tier 0 secuencial: security → correctness. Si VETO → goto 4.
  - 2b. Tier 1 paralelo: spec + architecture + cognitive (+ pr-agent si opt-in).

**recommendation-tribunal-orchestrator.md**: sin cambios. Documentar explícitamente que el constraint de latencia p95 < 3s justifica paralelo puro.

### Schema `.truth.crc` y `.review.crc`

Añadir campos:

```yaml
execution_mode: tiered  # vs "parallel" legacy
tier_0:
  judges_run: [compliance, hallucination]   # los que efectivamente corrieron
  stopped_at: hallucination
  stop_reason: veto_pii_leak
tier_1:
  judges_run: []           # vacío si tier 0 paró
  execution: parallel|skipped
```

### Override

Variable de entorno `TRIBUNAL_FORCE_FULL_PANEL=1` desactiva el tiered y vuelve al paralelo total. Casos de uso:
- Auditoría externa que requiere panel completo aunque alguien vete.
- Debug: ver qué hubieran votado todos.
- Calibración: medir tasa de acuerdo entre jueces.

Documentar en CLAUDE.md y en cada orchestrator.

## Aceptación

- [ ] AC-1: `scripts/savia-orchestrator-helper.sh tier` y `judges` funcionan.
- [ ] AC-2: `truth-tribunal-orchestrator.md` reescrito con Tier 0/Tier 1, mantiene schema `.truth.crc` con campos nuevos.
- [ ] AC-3: `court-orchestrator.md` reescrito con Tier 0/Tier 1, mantiene schema `.review.crc` con campos nuevos.
- [ ] AC-4: `recommendation-tribunal-orchestrator.md` añade nota explicativa de por qué NO aplica tiered (latencia sync).
- [ ] AC-5: Variable `TRIBUNAL_FORCE_FULL_PANEL=1` documentada y testeada.
- [ ] AC-6: Tests BATS verifican early-stop on veto en Tier 0 (mock judges).
- [ ] AC-7: Tests BATS verifican fan-out Tier 1 cuando Tier 0 PASS.
- [ ] AC-8: Schema legacy `.truth.crc` v1 sigue siendo válido (backward-compat). Campo `execution_mode` opcional, default "parallel" si ausente.
- [ ] AC-9: Documentado en `docs/rules/domain/tribunal-execution.md` (regla nueva, ≤150L).
- [ ] AC-10: Métrica de tokens ahorrados expuesta en `output/recommendation-tribunal/` y `output/truth-tribunal/` audit logs (campo `tokens_saved_vs_parallel`).
- [ ] AC-11: Path: `.opencode/agents/truth-tribunal-orchestrator.md` modificado.
- [ ] AC-12: Path: `.opencode/agents/court-orchestrator.md` modificado.
- [ ] AC-13: Path: `.opencode/agents/recommendation-tribunal-orchestrator.md` modificado (solo nota).
- [ ] AC-14: Path: `scripts/savia-orchestrator-helper.sh` extendido con `tier`/`judges` actions.
- [ ] AC-15: Path: `docs/rules/domain/tribunal-execution.md` creado.

## Riesgos

- **Latencia PASS sube ~20%** en async: aceptable. No aceptable en sync — por eso Recommendation queda fuera.
- **Jueces Tier 1 pierden contexto cruzado**: hoy ven el mismo input simultáneamente. Mitigación: pasar verdicts Tier 0 como contexto adicional a Tier 1.
- **Falsos positivos de Tier 0 bloquean panel completo**: mitigación con `TRIBUNAL_FORCE_FULL_PANEL=1`.
- **Duplicación con SPEC-127 Slice 4**: si no se extrae lógica común, hay deuda. AC-1 obliga a reutilizar el helper script.

## Notas de implementación

- Implementar primero en Code Review Court (menor blast radius, fewer judges). Validar 2 semanas en runs reales. Después extender a Truth Tribunal.
- Recommendation Tribunal queda explícitamente fuera de scope: documentado en su orchestrator como decisión de diseño (latencia sync incompatible).
- El campo `execution_mode` permite A/B testing entre runs paralelos legacy y tiered nuevo durante el rollout.

## Próximos pasos tras APPROVED

1. Implementar Code Review Court tiered (AC-3, AC-6, AC-7).
2. Medir 2 semanas en runs reales — comparar tokens y latencia vs baseline.
3. Si métricas confirman, implementar Truth Tribunal tiered (AC-2).
4. Publicar regla `docs/rules/domain/tribunal-execution.md` con la política.
5. Actualizar `docs/agent-teams-sdd.md` si afecta orquestación SDD.
