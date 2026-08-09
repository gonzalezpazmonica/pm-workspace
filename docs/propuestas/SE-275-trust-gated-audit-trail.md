# SE-275 — Trust-Gated Audit Trail: cadena de hash verificable para gobierno de decisiones de agentes

**Status:** IMPLEMENTED
**Fecha:** 2026-07-30
**Area:** Agent governance / Audit / Tribunal integrity
**Branch:** agent/se275-trust-audit-trail
**Estimacion total:** ~32h (4 slices)
**Inspiracion:** `Shubhamsaboo/awesome-llm-apps` (Trust-Gated Agent Team) + `ericrisco/rsc-harness` (Result Envelope, SDD chain gates)

---

## Origen

Los tres tribunales de Savia (Code Review Court, Truth Tribunal,
Recommendation Tribunal) producen decisiones que afectan codigo, specs, y
recomendaciones. Hoy esas decisiones son texto no estructurado en
`.review.crc`, `output/` o stdout. No hay forma de:

1. **Verificar que un veredicto no fue alterado** despues de emitirse.
2. **Trazar que agente contribuyo que** a una decision colegiada.
3. **Detectar si un juez fue excluido** de un tribunal sin registro.
4. **Auditar una cadena completa de decisiones** (spec → implementacion →
   review → fix → re-review → merge) como una secuencia verificable.

Dos fuentes externas ofrecen soluciones maduras:

1. **awesome-llm-apps / trust_gated_agent_team**: Hash-chained audit trail
   donde cada accion de agente recibe un SHA-256 que encadena con la
   entrada anterior. Tampering con cualquier registro invalida todos los
   hashes subsiguientes. Trust scoring 0-100 con tier gold/silver/bronze.
   Zero dependencias externas.

2. **rsc-harness / SDD chain**: Result Envelope — JSON estructurado al
   final de cada fase con status, artifact path, next phase, risk,
   evidence, skill_resolution. Permite encadenamiento programatico sin
   interpretar texto no estructurado.

**El hueco.** Savia tiene agent-notes-protocol.md para handoffs entre
agentes, pero no hay integridad criptografica de las decisiones. Un
veredicto de tribunal puede editarse manualmente, un juez puede silenciarse
sin registro, y la cadena spec→merge no es auditable como secuencia
verificable.

---

## Objetivo

Dotar a los tres tribunales y a la cadena SDD de un audit trail con
hash-chained integrity (S1), scoring de confianza por agente con tiered
participation (S2), result envelope estandar para todas las decisiones de
agente (S3), y verificacion de integridad de cadena en CI (S4).

---

## Out of scope explicito

- NO aplicar audit trail a cada tool call individual de cada agente.
  Solo a decisiones de tribunal y fases SDD (limite de scope).
- NO reimplementar los tribunales. El audit trail se integra en los
  orchestrators existentes (court-orchestrator, truth-tribunal-orchestrator,
  recommendation-tribunal-orchestrator).
- NO crear un blockchain ni requerir consenso distribuido. Hash chain
  local, deterministica, verificable offline.
- NO modificar el formato de los veredictos existentes; el envelope
  envuelve, no reemplaza.

---

## Diseno

### S1 — Hash-Chained Audit Trail

Cada decision de tribunal genera una entrada en la cadena:

```json
{
  "chain_id": "court-20260730-001",
  "seq": 3,
  "prev_hash": "sha256:e3b0c442...",
  "agent": "correctness-judge",
  "agent_tier": "mid",
  "action": "verdict",
  "timestamp": "2026-07-30T14:46:00Z",
  "input_hash": "sha256:def789...",
  "output_hash": "sha256:abc123...",
  "signature": "hmac-sha256:ff0011..."
}
```

**Propiedades**:
- Cada entrada referencia el hash de la entrada anterior → cadena inmutable
- `input_hash` = hash del spec/diff/contexto que el agente recibio
- `output_hash` = hash de la decision/veredicto del agente
- `signature` = HMAC-SHA256 con clave local (`~/.savia/audit-key`)
- Modificar cualquier entrada invalida todos los `prev_hash` subsiguientes

**Donde se registra**:

| Tribunal / Fase | Chain ID | Ubicacion |
|---|---|---|
| Code Review Court | `court-{date}-{pr}` | `output/audit/court-{date}-{pr}.jsonl` |
| Truth Tribunal | `truth-{date}-{report}` | `output/audit/truth-{date}-{report}.jsonl` |
| Recommendation Tribunal | `rec-{date}-{draft}` | `output/audit/rec-{date}-{draft}.jsonl` |
| SDD Chain (spec→merge) | `sdd-{spec-id}` | `output/audit/sdd-{spec-id}.jsonl` |

**Scripts**:
- `scripts/audit-chain-append.sh` — añade entrada a cadena existente
- `scripts/audit-chain-verify.sh` — verifica integridad completa de una cadena
- `scripts/audit-chain-prune.sh` — rota cadenas de mas de 90 dias a `output/audit/archive/`

### S2 — Agent Trust Scoring + Tiered Participation

**Scoring**:
- Cada agente arranca con trust_score = 50 (neutral)
- Sube cuando sus veredictos son confirmados por otros jueces o por override humano
- Baja cuando sus veredictos son revertidos, ignorados, o marcados como incorrectos
- Se recalcula semanalmente (`scripts/trust-score-recalc.sh`)

**Tiers**:

| Tier | Score | Efecto en tribunal |
|---|---|---|
| Gold | >= 75 | Voto completo. Veredicto visible en el resultado final. |
| Silver | 50-74 | Voto completo. Veredicto visible con flag `[advisory]`. |
| Bronze | 25-49 | Voto consultivo. No cuenta en el aggregation; visible como `[consultive]`. |
| Unranked | < 25 o < 10 decisiones | Excluido del tribunal. No participa. |

**Trust gating por tribunal**:

| Tribunal | Threshold | Jueces minimos |
|---|---|---|
| Code Review Court | 3 gold + 2 silver | 5 |
| Truth Tribunal | 2 gold + 3 silver | 5 |
| Recommendation Tribunal | 1 gold + 3 silver + 2 bronze | 6 |

Si el threshold no se alcanza (no hay suficientes jueces en el tier requerido),
el orchestrator emite `TRUST_THRESHOLD_NOT_MET` y escala a operador humano.

**Artefacto**: `config/agent-trust-scores.yaml` — mantenido por
`scripts/trust-score-recalc.sh`, leido por los orchestrators.

### S3 — Result Envelope Estandar

Cada decision significativa de agente (veredicto de tribunal, spec generada,
plan de implementacion, review completada) se empaqueta en:

```json
{
  "envelope_version": "1.0",
  "chain_id": "court-20260730-001",
  "status": "complete|blocked|failed",
  "agent": "correctness-judge",
  "agent_tier": "mid",
  "timestamp": "2026-07-30T14:46:00Z",
  "executive_summary": "2 blockers, 3 should-fix, 1 nit found",
  "artifact": ".review.crc",
  "artifact_hash": "sha256:abc123...",
  "next_recommended": "fix-assigner",
  "risk": "low|medium|high",
  "confidence": 0.85,
  "evidence": [
    {"type": "diff", "path": "src/services/auth.cs", "lines": "45-78"},
    {"type": "spec_ac", "id": "AC-03", "verdict": "violated"}
  ],
  "skill_resolution": {
    "used": ["code-reviewer", "ast-quality-gate"],
    "missing": [],
    "fallback": []
  },
  "budget": {
    "tokens_allocated": 8000,
    "tokens_used": 6200,
    "wall_time_ms": 45000
  },
  "signature": "hmac-sha256:ff0011..."
}
```

**Integracion**:
- `agent-notes-protocol.md` se actualiza para requerir envelope en handoffs
- `court-orchestrator` emite envelope al cerrar cada review
- `truth-tribunal-orchestrator` emite envelope al completar evaluacion
- `recommendation-tribunal-orchestrator` emite envelope al emitir recomendacion
- `dev-orchestrator` emite envelope por cada slice completado

### S4 — Verificacion de Integridad en CI

**Script**: `scripts/audit-chain-verify.sh` que:
1. Escanea `output/audit/*.jsonl` buscando cadenas activas
2. Verifica `prev_hash` consistency en cada cadena
3. Verifica `signature` HMAC contra `~/.savia/audit-key`
4. Reporta cadenas con integridad rota
5. Sale 0 si todas las cadenas son integras, 1 si alguna esta corrupta

**CI integration**: Nuevo job `Audit Chain Integrity` en CI que corre
`audit-chain-verify.sh` en cada PR y weekly. No bloquea PRs (WARN), pero
alerta en canal de operador si detecta corrupcion.

---

## Slices de implementacion

### S1 — Hash-Chained Audit Trail (10h)
- Definir schema JSON de entrada de cadena (1h)
- Escribir `scripts/audit-chain-append.sh` (3h)
- Escribir `scripts/audit-chain-verify.sh` (3h)
- Integrar en `court-orchestrator`: emitir entradas por cada juez (1h)
- Integrar en `truth-tribunal-orchestrator` (1h)
- Integrar en `recommendation-tribunal-orchestrator` (1h)

### S2 — Agent Trust Scoring + Tiered Participation (10h)
- Escribir `scripts/trust-score-recalc.sh` (3h)
- Crear `config/agent-trust-scores.yaml` inicial con scores neutrales (1h)
- Integrar tiered participation en los 3 orchestrators (3h)
- Añadir flag `[advisory]` / `[consultive]` en output de veredictos (2h)
- Documentar en `docs/rules/domain/agent-trust-scoring.md` (1h)

### S3 — Result Envelope Estandar (8h)
- Definir JSON schema del envelope v1.0 (1h)
- Actualizar `agent-notes-protocol.md` con envelope requirement (1h)
- Integrar envelope en `court-orchestrator` (1.5h)
- Integrar envelope en `truth-tribunal-orchestrator` (1.5h)
- Integrar envelope en `recommendation-tribunal-orchestrator` (1.5h)
- Integrar envelope en `dev-orchestrator` (1.5h)

### S4 — Verificacion de Integridad en CI (4h)
- Añadir `Audit Chain Integrity` job al CI workflow (2h)
- Integrar `scripts/audit-chain-verify.sh` en el job (1h)
- Añadir alerta de corrupcion al operador (webhook/issue) (1h)

---

## Dependencias

- **S1 → S2, S3**: La cadena de hash es la base; trust scoring y envelope referencian chain_id
- **S3 → S2**: El envelope incluye `agent_tier` que viene del trust scoring
- **S4 → S1**: Verifica las cadenas creadas en S1
- **Requiere**: acceso a los 3 orchestrators existentes para integrar
- **No requiere**: nuevos agentes, nuevos hooks, cambios en pr-plan

---

## Riesgos

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| Overhead de I/O en tribunales con muchos jueces | Media | Bajo | Append-only JSONL es O(1); el coste es trivial (~200 bytes por entrada) |
| Trust scores iniciales todos neutrales (50) | Alta | Medio | Fase de calibracion de 4 semanas antes de activar gating; documentar en S2 |
| Clave HMAC (`~/.savia/audit-key`) no existe en CI | Alta | Bajo | CI verifica solo `prev_hash` consistency (deterministico, no requiere clave); HMAC solo en local |
| Cadenas acumuladas llenan disco | Baja | Bajo | `audit-chain-prune.sh` rota cadenas >90 dias a archive comprimido |

---

## Criterios de aceptacion

### AC-S1: Hash chain operativa
- [x] AC-S1.1: `scripts/audit-chain-append.sh` crea entradas con `prev_hash` correcto
- [x] AC-S1.2: `scripts/audit-chain-verify.sh` detecta corrupcion (hash roto, entrada faltante, orden alterado)
- [x] AC-S1.3: `court-orchestrator` emite entrada por cada juez al emitir veredicto
- [x] AC-S1.4: `truth-tribunal-orchestrator` emite entrada por cada juez
- [x] AC-S1.5: `recommendation-tribunal-orchestrator` emite entrada por cada juez

### AC-S2: Trust scoring funcional
- [ ] AC-S2.1: `config/agent-trust-scores.yaml` existe con scores iniciales para todos los jueces
- [ ] AC-S2.2: `scripts/trust-score-recalc.sh` recalcula scores basado en historial de veredictos
- [ ] AC-S2.3: Jueces bajo threshold aparecen con flag `[advisory]` o `[consultive]` en output
- [ ] AC-S2.4: Orchestrator emite `TRUST_THRESHOLD_NOT_MET` si no hay suficientes jueces gold+silver

### AC-S3: Result envelope en todos los orchestrators
- [x] AC-S3.1: JSON schema del envelope v1.0 validado contra todos los orchestrators
- [x] AC-S3.2: `court-orchestrator` emite envelope al cerrar review
- [x] AC-S3.3: `truth-tribunal-orchestrator` emite envelope al completar evaluacion
- [x] AC-S3.4: `recommendation-tribunal-orchestrator` emite envelope al emitir recomendacion
- [x] AC-S3.5: `agent-notes-protocol.md` actualizado con envelope requirement

### AC-S4: CI verifica integridad
- [ ] AC-S4.1: `Audit Chain Integrity` job existe en CI
- [ ] AC-S4.2: Job corre `audit-chain-verify.sh` y reporta WARN en corrupcion
- [ ] AC-S4.3: Job no bloquea PRs (WARN, no FAIL)

---

## Metrica de exito

- **S1**: 3/3 tribunales emitiendo entradas de audit chain
- **S2**: Trust scores iniciales asignados; recalculo semanal operativo
- **S3**: 4/4 orchestrators emitiendo envelope estandar
- **S4**: CI job verificando integridad de cadenas activas
