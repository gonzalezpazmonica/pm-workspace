---
context_tier: L2
token_budget: 600
spec: SE-207
usage: reference-only
dormant_since: "2026-06-24"
review_note: "Quarterly review 2026-Q2"
---

# Lightweight Engineering Review (LER) — SE-207

> Template ligero para cambios de infraestructura del workspace.
> Inspirado en el patrón de design docs de Orca (stablyai/orca — 540+ releases).
> Referencia: `docs/propuestas/SE-207-lightweight-eng-review.md`

## Cuándo usar LER (vs SDD completo)

| Situación | Usar |
|---|---|
| Nueva feature de usuario, agente nuevo, spec ejecutable | **SDD completo** (Rule #8) |
| Script bash nuevo, hook nuevo, config change, refactor de skill | **LER** |
| Fix de bug con causa conocida, dependency update | **LER** |
| Cambio que toca >3 agentes o afecta flujo PM | **SDD completo** |

## Template LER

Copiar desde: `docs/templates/lightweight-eng-review.md`

Secciones obligatorias:

1. **Problem** — qué falla o qué falta (1-3 frases)
2. **Root Cause** — por qué existe el problema
3. **Non-Goals** — qué explícitamente NO se resuelve
4. **Design** — la solución propuesta (puede incluir pseudocódigo o bash)
5. **Data Flow** — cómo fluyen los datos (ASCII o descripción)
6. **Edge Cases** — al menos 3 casos límite considerados
7. **Test Plan** — qué tests se añaden o modifican
8. **Rollout** — cómo se despliega / activa (feature flag, PR, script)
9. **Lightweight Eng Review** — checklist obligatorio:
   - `[ ]` Failure modes cubiertos (¿qué pasa si falla?)
   - `[ ]` Blast radius estimado (¿qué se rompe si hay bug?)
   - `[ ]` Test coverage requerida (≥80% BATS score)
   - `[ ]` Residual risks documentados

## Ejemplo: SE-206 agent-wait-idle.sh

**Problem**: overnight-sprint usa `sleep` fijos. Agente idle no detectado hasta timeout.

**Root Cause**: No existe mecanismo de detección de actividad de proceso. Polling manual con `sleep` es la única opción actual.

**Non-Goals**: No reemplazar el sistema de hooks. No detectar idle en agentes remotos (SSH).

**Design**: Monitorizar `/proc/PID/fdinfo` — si la suma de posiciones no cambia en `--idle-threshold` segundos, el proceso está idle.

**Data Flow**: `overnight-sprint` → `agent-wait-idle.sh --pid N` → poll fdinfo cada 2s → exit 0 (idle) | exit 1 (timeout) | exit 2 (dead).

**Edge Cases**:
- PID no existe → exit 2 inmediato
- PID=0 → exit 3 (arg inválido)
- Log file no existe todavía → tratar como silencio (no error)

**Test Plan**: BATS suite `tests/test-se-206-agent-idle.bats` (20 tests, ≥80 score).

**Rollout**: Script nuevo en `scripts/`. Mención en overnight-sprint SKILL. Sin breaking changes.

**LER**:
- [x] Failure modes: PID dead → exit 2, timeout → exit 1
- [x] Blast radius: script independiente, no toca lógica existente
- [x] Test coverage: 20 BATS tests
- [x] Residual risks: fdinfo approach Linux-only; macOS usa approx distinta
