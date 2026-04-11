# Savia Enterprise — Plan de desarrollo autónomo

> **Inicio:** 2026-04-11 · **Autora operativa:** Savia · **Reviewer:** Mónica
> **Principio rector:** dev-session-protocol + /pr-plan + commit-guardian en CADA spec.
> Zero atajos. Zero bypasses. Zero merge autónomo. PRs siempre en draft.

---

## 1. Contrato de ejecución

Cada spec se ejecuta con las 5 fases de `dev-session-protocol.md`:

1. **Spec Load & Slice** — dev-orchestrator descompone en slices ≤3 ficheros
2. **Context Prime** — cargar sólo lo necesario (spec excerpt + target files)
3. **Implement via Subagent** — delegar a `{lang}-developer` con contexto fresco
4. **Validate** — test-engineer + coherence-validator en paralelo
5. **Integrate & Review** — code-reviewer → PR Draft con reviewer humano

Gates obligatorios antes de cada PR:
- `bash scripts/validate-ci-local.sh` — CI local
- `/pr-plan` — 11 gates G0-G11 (Rule #25)
- `commit-guardian` — 10 checks pre-commit
- `confidentiality-sign.sh sign` — firma confidencialidad

**Nunca** se hace `push-pr.sh` directamente (Rule #25, gated por `.pr-plan-ok`).

---

## 2. DAG de ondas (paralelismo máximo respetando deps)

```
┌─────────── ONDA 0 ───────────┐
│  SE-001 (foundations, 3d)    │ ← arranca YA
│  SE-008 (licensing,    2d)   │ ← arranca YA
└─────────┬──────────┬─────────┘
          │          │
          ▼          ▼
┌─────────────────── ONDA 1 ────────────────────┐
│  SE-002 (multi-tenant, 5d)   [bloq: SE-001]  │
│  SE-003 (mcp catalog,  8d)   [bloq: 1+8]     │
│  SE-011 (docs restruct,6d)   [bloq: 1+8]     │
└─────────┬──────────┬──────────────────────────┘
          │          │
          ▼          ▼
┌─────────────────── ONDA 2 ────────────────────┐
│  SE-005 (sovereign,    6d)   [bloq: 1+2]     │
│  SE-006 (governance,   8d)   [bloq: 1+2]     │
│  SE-010 (migration,    4d)   [bloq: 1+2]     │
│  SE-007 (onboarding,   5d)   [bloq: 1+2]     │
│  SE-004 (agent interop,10d)  [bloq: 1+3]     │
└─────────┬──────────────────────────────────────┘
          │
          ▼
┌─────────────── ONDA 3 ────────────┐
│  SE-009 (observability,5d) [1+5] │
└───────────────────────────────────┘
```

**Paralelismo efectivo:** hasta 5 specs simultáneas en ondas 1-2.
**Critical path:** SE-001 → SE-002 → SE-005 → SE-009 = 19 días agente.
**Total con paralelismo real:** ~30-35 días agente (vs 62 secuencial).

---

## 3. Mapa de PRs (uno por spec, siempre draft)

| PR | Rama | Spec | Base | ETA |
|----|------|------|------|-----|
| #1 | `feat/savia-enterprise-foundations` | SE-001 | main | Sesión 1-2 |
| #2 | `feat/savia-enterprise-licensing` | SE-008 | main | Sesión 1-2 |
| #3 | `feat/savia-enterprise-docs` | SE-011 | main (post #1, #2) | Sesión 3-4 |
| #4 | `feat/savia-enterprise-multi-tenant` | SE-002 | main (post #1) | Sesión 3-5 |
| #5 | `feat/savia-enterprise-mcp-catalog` | SE-003 | main (post #1, #2) | Sesión 5-7 |
| #6 | `feat/savia-enterprise-sovereign` | SE-005 | main (post #1, #4) | Sesión 7-8 |
| #7 | `feat/savia-enterprise-migration` | SE-010 | main (post #1, #4) | Sesión 7-8 |
| #8 | `feat/savia-enterprise-governance` | SE-006 | main (post #1, #4) | Sesión 8-9 |
| #9 | `feat/savia-enterprise-onboarding` | SE-007 | main (post #1, #4) | Sesión 9 |
| #10 | `feat/savia-enterprise-agent-interop` | SE-004 | main (post #1, #5) | Sesión 9-10 |
| #11 | `feat/savia-enterprise-observability` | SE-009 | main (post #1, #6) | Sesión 10 |

Cada PR incluye: código + tests + changelog entry + actualización SE-XXX.md
con marca `status: implemented YYYY-MM-DD`.

---

## 4. Protocolo de resumabilidad (cross-session)

Cada sesión que Savia arranca debe:

1. **Leer** `session-journal.md` del workspace (crash recovery)
2. **Leer** memoria `project_savia_enterprise_migration.md`
3. **Comprobar** estado con `git branch -a | grep savia-enterprise`
4. **Ejecutar** `TaskList` para ver qué está pending/in_progress/completed
5. **Continuar** la spec in_progress o coger la siguiente no bloqueada
6. **Nunca** empezar una spec nueva si hay una in_progress a medias

Al final de cada sesión (o antes de compactar), Savia actualiza:
- `session-journal.md` con estado exacto (spec, slice, ficheros tocados)
- Memoria `project_savia_enterprise_migration.md` con progreso
- TaskUpdate para marcar estado real

---

## 5. Criterios de atajo (cuándo PARAR)

Savia PARA y escala a Mónica si:

- 3 fallos consecutivos en el mismo slice → escalar (regla `autonomous-safety.md`)
- `/pr-plan` falla G0-G11 y no puede resolver sin cambiar acceptance criteria → escalar
- Coherence-validator score <0.75 tras 2 iteraciones → escalar
- Detección de conflicto con principios fundacionales → escalar INMEDIATAMENTE
- Context >85% sin posibilidad de `/compact` útil → escalar + resume-plan

Escalada = crear issue con contexto completo, NO merge, NO atajo, NO bypass.

---

## 6. Presupuesto por spec (token budget)

Cada spec ~40-80K tokens efectivos tras compactaciones. Si una spec supera
120K sin completar un slice → romper en sub-slices y crear PR parcial.

Agentes delegados usan subagent (Task) para mantener contexto principal limpio.
Los 46 agentes actuales tienen `token_budget` declarado — respetar.

---

## 7. Tests por spec (innegociable)

Cada spec cierra con:

1. **Tests unitarios nuevos** para la capa introducida
2. **Tests regresión** — golden set de flujos Core funciona idéntico
3. **BATS** para hooks nuevos (`tests/run-all.sh` debe pasar)
4. **validate-ci-local.sh** en verde
5. **Coverage delta** ≥0 vs rama base (regla #22)

Si algún test falla, se delega a `{lang}-developer` (dev-session fase 4).
NUNCA se marca una spec como completa con tests en rojo (regla #22).

---

## 8. Comunicación con Mónica

Savia notifica a Mónica vía Nextcloud Talk cuando:
- Cada PR draft está listo para review
- Se escala un bloqueo
- Se detecta drift con los principios fundacionales
- Una onda completa se cierra (hito)

Formato del mensaje: enlace al PR + resumen 3 líneas + siguientes pasos.

---

## 9. Estado actual (live)

Actualizado: **2026-04-11** (arranque)

```
ONDA 0:
  SE-001  [ ] pending  → arrancando ahora
  SE-008  [ ] pending  → arrancando en paralelo tras SE-001 setup

ONDA 1-3: bloqueadas por ONDA 0
```

Ver `TaskList` para estado vivo.

---

## 10. Principios inmutables durante la ejecución

Citados textualmente para que ninguna sesión futura los olvide:

1. **Soberanía del dato**: `.md` es la verdad. Sin excepción.
2. **Independencia del proveedor**: adaptadores, nunca acoplamientos.
3. **Honestidad radical**: tests en rojo se dicen, no se esconden.
4. **Privacidad absoluta**: N4 nunca sale.
5. **El humano decide**: Mónica revisa cada PR. Cero merge autónomo.
6. **Igualdad**: Equality Shield aplicado en cualquier decisión de diseño.
7. **Protección de identidad**: Savia sigue siendo Savia durante y después.

**Si alguna sesión percibe que uno de estos 7 principios está en riesgo,
PARA, escala y documenta el incidente. Sin excepción. Sin override.**
