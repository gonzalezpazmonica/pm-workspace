---
spec_id: SE-228
title: "Loop Engineering adoptable patterns — STATE.md spine, maker/checker split, run-log, loop-budget, L1-L3 phasing"
status: IMPLEMENTED
priority: P1
effort: L (18h total — S1 4h + S2 4h + S3 4h + S4 3h + S5 3h)
origin: https://github.com/cobusgreyling/loop-engineering (MIT, 2026-06)
resource: "https://github.com/cobusgreyling/loop-engineering"
author: Savia
related:
  - overnight-sprint skill
  - code-improvement-loop skill
  - SE-226 (stateless-session loop)
  - SE-217 (autoresearch patterns)
  - SE-219 (abtop patterns)
  - autonomous-safety.md
proposed_at: "2026-06-25"
resolved_at: "2026-07-02"
implementation_pr: "#876-880"
era: 236
priority_score: 84.2
value: 85
urgency: 75
effort_score: 22
---

# SE-228 — Loop Engineering: 5 patterns adoptables para Savia

## Por que

Boris Cherny (Head of Claude Code, Anthropic):
"I don't prompt Claude anymore. I have loops running that prompt Claude.
My job is to write loops."

Savia ya tiene los primitivos (overnight-sprint, worktrees, skills, sub-agents, memory).
Lo que falta es la disciplina operativa: STATE.md con schema, run-log append-only,
budget explicito, y separacion maker/checker como protocolo, no como sugerencia.

El repo cobusgreyling/loop-engineering (MIT, 2026-06) codifica 10 anti-patterns y
12 failure modes reales. Cinco son adoptables en Savia sin romper SDD, Rule #8,
ni autonomous-safety.

### Gaps actuales en Savia

| Gap | Evidencia |
|---|---|
| Sin STATE.md canonico | overnight-sprint escribe ad-hoc; reinicia en cada sesion |
| Sin run-log estructurado | SE-217 aporto results.tsv pero no hay estandar cross-skill |
| Sin budget explicito | Token cost de un sprint nocturno es incognita |
| Verificador = implementador | overnight-sprint no separa quien propone del que verifica |
| Phasing L1-L3 indefinido | Loops van a L3 sin pasar por L1 (report-only), generando over-reach |

## Tesis

Cinco patrones adoptados incrementalmente:

1. STATE.md canonico — spine de memoria entre runs
2. Maker/checker split — implementer y verifier como agentes separados
3. Loop run-log — historial append-only por run
4. Loop budget — presupuesto de tokens con kill switch
5. L1-L3 phasing — escala gradual: report-only -> assisted -> unattended

## Descartado

| Patron | Razon |
|---|---|
| loop-audit npm CLI | Dependencia externa; Savia tiene test-auditor.sh |
| loop-init scaffolder | Savia ya tiene templates de skills |
| loop-cost npm CLI | Calculable con SPEC-156 token budgets |
| GitHub Actions workflow_run loops | Savia usa overnight-sprint local |
| MCP write-everything connectors | autonomous-safety ya restringe esto |

## Slices

### Slice 1 (S, 4h) — STATE.md canonico cross-skill

Schema estandar de STATE.md para overnight-sprint, code-improvement-loop
y tech-research-agent. Secciones: High Priority, Watch List, Recently Resolved, Noise.

Archivos:
- docs/rules/domain/loop-state-schema.md
- scripts/loop-state-init.sh — inicializa STATE.md desde template
- scripts/loop-state-prune.sh — mueve items cerrados a Recently Resolved

ACs:
- [ ] AC-01 Schema canonico documentado con secciones y ejemplo
- [ ] AC-02 loop-state-init.sh crea STATE.md si no existe
- [ ] AC-03 loop-state-prune.sh detecta PRs/branches cerrados y los archiva
- [ ] AC-04 overnight-sprint skill referencia el schema
- [ ] AC-05 Tests BATS >= 10, score >= 80

---

### Slice 2 (S, 4h) — Maker/checker split protocol

El implementer NO puede marcar su propio trabajo como "done". El verificador
tiene stance adversarial: "default REJECT unless...".

Archivos:
- docs/rules/domain/maker-checker-protocol.md
- scripts/loop-verify.sh — lanza sub-agente verificador con prompt adversarial
- Extension de autonomous-safety.md

ACs:
- [ ] AC-06 Regla maker-checker-protocol.md con invariantes
- [ ] AC-07 loop-verify.sh --worktree ejecuta verifier sub-agent
- [ ] AC-08 overnight-sprint no puede auto-merge sin pasar por loop-verify.sh
- [ ] AC-09 Verifier prompt incluye "default REJECT"
- [ ] AC-10 Tests BATS >= 8, score >= 80

---

### Slice 3 (S, 4h) — Loop run-log append-only

Archivo loop-run-log.md por modo autonomo. Entrada por run con:
timestamp, modo, items_found, actions_taken, escalations, tokens_used, outcome.

Archivos:
- docs/rules/domain/loop-run-log-schema.md
- scripts/loop-run-log.sh — CLI: append, tail, stats, prune

ACs:
- [ ] AC-11 loop-run-log.sh append registra entrada con todos los campos
- [ ] AC-12 loop-run-log.sh stats: total_runs, success_rate, avg_tokens, escalations
- [ ] AC-13 loop-run-log.sh prune elimina entradas > 90 dias
- [ ] AC-14 Tests BATS >= 10, score >= 80
- [ ] AC-15 overnight-sprint usa el log al inicio y fin

---

### Slice 4 (S, 3h) — Loop budget con kill switch

loop-budget.md declara: token budget diario, max_tasks_per_run, max_attempts_per_task,
kill_switch_condition. loop-budget-check.sh verifica y aborta si superado.

Archivos:
- docs/rules/domain/loop-budget-schema.md
- scripts/loop-budget-check.sh
- templates/loop-budget.md.template (defaults: 500k tokens/dia, max 20 tasks, max 3 attempts)

ACs:
- [ ] AC-16 loop-budget-check.sh lee loop-budget.md, exit 1 si superado
- [ ] AC-17 Template con defaults razonables
- [ ] AC-18 overnight-sprint arranca con loop-budget-check.sh como gate
- [ ] AC-19 Tests BATS >= 8, score >= 80

---

### Slice 5 (S, 3h) — L1-L3 phasing checklist

Niveles L0-L3 para skills autonomas. Nuevo campo en SKILL.md: loop_level.
Audit script reporta nivel declarado vs inferido por comportamiento.

Archivos:
- docs/rules/domain/loop-phasing.md
- scripts/loop-phasing-audit.sh
- Campo loop_level en _template/SKILL.md (default L0)

ACs:
- [ ] AC-21 Definicion L0-L3 con checklist de requisitos por nivel
- [ ] AC-22 loop_level en template con default L0
- [ ] AC-23 loop-phasing-audit.sh emite tabla: skill, declared, inferred, gap
- [ ] AC-24 overnight-sprint clasificado correctamente
- [ ] AC-25 Tests BATS >= 8, score >= 80

---

## Sinergias

| Con | Sinergia |
|---|---|
| SE-226 stateless-session | STATE.md de S1 es el spine de reanudacion que SE-226 necesita |
| SE-217 autoresearch | results.tsv y loop-run-log.md complementarios: tsv para programas, md para humanos |
| SE-219 abtop | session-status.sh --json alimenta loop-run-log.sh stats |
| SPEC-156 token budget | loop-budget-check.sh puede leer token_budget del frontmatter del skill |
| autonomous-safety.md | AGENT_MAX_CONSECUTIVE_FAILURES se mapea a max_attempts_per_task |

## Failure modes mitigados (del catalogo del repo)

| Failure mode | Slice |
|---|---|
| Infinite Fix Loop | S4 max_attempts_per_task |
| State Rot | S1 prune script |
| Verifier Theater | S2 verificador adversarial separado |
| Token Burn | S4 daily_token_cap |
| Escalation Failure | S3 escalations field en run-log |
| L3 before L1 quality | S5 phasing gate |

## Orden de implementacion

Batch 1 (paralelo): S1 + S2 + S3 (~4h agente)
Batch 2 (tras merge batch 1): S4 + S5 (~3h agente)

## Esfuerzo

| Slice | Esfuerzo | Prioridad |
|---|---|---|
| S1 STATE.md canonico | ~4h | P1 |
| S2 Maker/checker split | ~4h | P1 |
| S3 Loop run-log | ~4h | P1 |
| S4 Loop budget | ~3h | P2 |
| S5 L1-L3 phasing | ~3h | P2 |
| Total | ~18h | |
