# SE-387 — Coherence Closure Program (Enforcement, Constitutional Coverage, Harness Reliability, Generated Truth)

**Estado:** APPROVED + IMPLEMENTING (Mónica 2026-09-05: "Implementa y sube pr definitivo ya implantado") — Slices A/B/D/G en PR de implementación
**Fecha:** 2026-09-05 · **Prioridad:** P0 · **Developer Type:** agent-team · **Risk:** L3/L4 según slice
**Era:** Coherence Before Capability · **Tipo:** program/umbrella spec (espec hijas solo si el paralelismo lo justifica — §20)
**Principios:** CRIT-001, humano decide, no-fragmentar, reutilizar mecanismos

## 0. Reconciliación contra main (HEAD be21db3f, post #1090)

**Gap matrix por slice** (§23) — mapeado contra specs existentes para NO duplicar:

| Slice | Estado hoy | Spec/PR relacionada | Gap |
|---|---|---|---|
| A Coherence Gates Graduation | PARTIAL (advisory; WARN no bloquea) | coherence-gates.sh (SE-377/380/383/386 wiring) | graduación por gate+risk, sin --strict global |
| B Constitutional Coverage | PARTIAL (11 leyes + 4 descriptors; sin coverage por capability) | SE-386 F1+F2 | capa L4 capability→law→enforcement→test→receipt |
| C Harness F2-F5 | NOT_STARTED (chaos P1-P8 + fixtures existen) | SE-383 (chaos) | F2 trace fail-closed, F3 handoff, F4 checkpoint, F5 exactly-once |
| D Behavioral Eval Burn-down | PARTIAL (matriz report-only, 0% L4) | SE-381 (matrix) | ratchet por capability + gate progresivo |
| E Structural Debt Burn-down | NOT_STARTED (wave 0 freeze 133) | SE-376 (budget+inventario) | wave 1 133→95 real |
| F Generated Truth Everywhere | PARTIAL (registry/roadmap/laws derivados; README counters ya derivados en #1091) | SE-375/378/379 | planning IMPLEMENTED desde evidencia + drift |
| G Capability Entropy v1 | PARTIAL (v0=1623 provisional) | SE-380 (entropy v0) | calibración v1 (routing/unowned/untested) |
| H Self-Evolution Execution | PARTIAL (runner + 20 tareas, dry) | SE-384 | ejecución real aislada con métricas |

**IDs:** SE-387 verificado libre. **Supersede/fusiona:** nada (umbrella sobre SE-376/377/381/383/384/386). **PRs abiertas:** #1091 (activación) en curso.

## 1. Objetivo
Cerrar los bucles de gobierno ya instrumentados antes de nueva expansión. El problema ya no es ausencia de mecanismos sino estados advisory/report-only/pilot/freeze. Cadena a cerrar: norma → capability contract → deterministic enforcement → negative/behavioral tests → runtime evidence → receipt → canonical state.

## 2. Principio rector
No añadir capas de gobierno si las existentes no están cerradas de extremo a extremo.

## 3. Frentes
A gates advisory→blocking selectivo · B cobertura constitucional L4 luego L3 · C harness F2-F5 · D eval coverage exigible por riesgo · E debt burn-down real · F eliminar verdad derivada escrita a mano · G entropy v0→v1 calibrada · H benchmark ejecución reproducible.

## 4. Non-goals
Sin nuevas familias de agentes/routers/courts (salvo necesidad demostrada) · sin DB general · sin nueva taxonomía de riesgo · sin nuevos principios salvo hueco crítico · sin cientos de tasks de benchmark antes de ejecutar las actuales.

## 5. Slice A — Gates Graduation
coherence-gates.sh: estados OBSERVE/WARN/BLOCK por gate con metadata {id,status,risk_scope,calibration,owner,evidence}. A1: L4 bloqueantes cuando calibrados (negative-safety, enforcement, unsafe-action, bypass, contract validation). A2: L3 tras cobertura. A3: quality sigue advisory. **No --strict global como única política**; graduación por gate y risk.

## 6. Slice B — Constitutional Coverage Burn-down
Por capability L4: capability → applicable LAW → descriptor → enforcement → negative test → runtime receipt. Salida output/constitutional-coverage.{json,md}. Estados: COMPLETE/PARTIAL/MISSING_DESCRIPTOR/MISSING_ENFORCEMENT/MISSING_TEST/MISSING_RECEIPT/NOT_APPLICABLE. Orden: 100% L4 → 100% L3 → L2 si aporta. L4 completo+estable → blocking.

## 7. Slice C — Harness F2-F5
F2 Grounding fail-closed: veredicto con grounding exige eventos reales del trace; trace ausente → REJECT_UNGROUNDED (nunca accept-ungrounded). F3 Handoff integrity: handoff con source/target/artifact_refs/checksums/scope/timestamp; validate-handoff.sh detecta referencias desaparecidas/mutaciones/checksum inválido. F4 Durable checkpoint: run_id/spec_id/slice/steps/artifacts/receipts/budget/retry/last_safe — local, auditable. F5 Exactly-once: intent → effect reservation → human/gate → execute → receipt → close; retry de efecto consumido → ALREADY_EXECUTED (merge/deploy/publicación/delete/escritura externa).

## 8. Slice D — Eval Burn-down
L4 mínima: smoke/golden/edge/adversarial/regression/negative_safety/enforcement/unsafe_action/bypass. L3: sin los 4 últimos. Ratchet por capability (COMPLETE no degrada sin excepción owner+expiry). Gate progresivo: capability completa → esa capability blocking. No esperar al 100% global.

## 9. Slice E — Debt Burn-down
Wave 1 real: 133→≤95 (reconciliar). Orden: stubs→duplicados→mirrors→skills sin uso/owner/test→wrappers→absorbibles→docs deprecadas. Cada eliminación conserva intent coverage/replacement/migration + registry. **Admission control**: nueva capability declara why_existing/expected_usage/owner/risk/tests/complexity/retirement → REJECT/CONSOLIDATE si no justifica unicidad.

## 10. Slice F — Generated Truth
Dato derivable de fuente canónica (registry.json/planning-state/laws/contracts/release metadata) → se genera, no se copia. Vistas con "AUTO-GENERATED — DO NOT EDIT". Contadores (commands/agents/skills/hooks/languages/tests) desde la misma fuente en README/CLAUDE. Planning: IMPLEMENTING→IMPLEMENTED solo si criterios machine-checkable pasan; si no → NEEDS_HUMAN_REVIEW; nunca inferir cierre del texto del commit.

## 11. Slice G — Entropy v1
v0 se conserva como ratchet histórico. v1 añade (explicable, sin ML): routing_ambiguity, duplicate_intent_density, unowned_capabilities, untested_high_risk, manual_sync_surfaces, deprecated_not_removed. entropy_v0 y v1 en paralelo durante calibración; no reemplazar baseline sin aprobación humana.

## 12. Slice H — Benchmark Execution
baseline → worktree aislado → agent execution → gates → tests → artifact diff → evaluation → result. Métricas: task_success/spec_compliance/scope_compliance/tests_green/safety_violations/human_interventions/retries/tokens/duration/files_changed/entropy_delta/debt_delta. Nunca mergear/publicar/desplegar/main/credenciales reales/saltarse gates. Responder: ¿Savia de hoy mejora Savia mejor que la anterior?

## 13. Estado canónico
PROPOSED→APPROVED→IMPLEMENTING→FUNCTIONALLY_IMPLEMENTED→CALIBRATING→ENFORCED→CLOSED. Ej.: eval matrix=FUNCTIONALLY_IMPLEMENTED; coverage measured=CALIBRATING; gate blocking=ENFORCED; target+sin gaps=CLOSED.

## 14. Definition of Closed
Gates L4 críticos blocking · constitutional L4 100% · F2 fail-closed · F3 activa · F4 probado · F5 cubre L4 · eval L4 blocking · debt wave1 target · truth-derived sin drift · planning refleja evidencia · benchmark ejecuta real · entropy v1 calibrada o v0 marcada provisional.

## 15. Acceptance Criteria
(por dominio) Governance: policy machine-readable gate status; L4 no depende de --strict; excepciones owner+expiry. Constitution: 100% L4 descriptor; cada L4 enlaza leyes→enforcement→negative test→receipt; report determinista. Harness: trace ausente→fail-closed; handoff checksum; resume durable; exactly-once con retry/restart tests. Evals: L4 completa; ratchet; paired regression. Debt: wave1 ejecutada; replacements documentados. Generated: contadores canónicos; sin divergencia; generation check; release invariants cubren vistas. Benchmark: ≥20 ejecutables; resultados machine-readable; cero auto-merge.

## 16. Tests adversariales obligatorios
Gate bypass L4→block · LAW inexistente→BLOCK · enforcement ausente L4→block · trace ausente→REJECT_UNGROUNDED · retry tras efecto→ALREADY_EXECUTED · handoff mutado→HANDOFF_INVALID · planning drift→PLANNING_STATE_DRIFT · vista divergente→GENERATED_VIEW_DRIFT · eval regresión→EVAL_COVERAGE_REGRESSION.

## 17. Observabilidad
output/coherence-closure-status.{json,md} con secciones gates/constitutional_coverage/harness/evals/debt/generated_truth/benchmark/entropy. Sin dashboards extra si es derivable.

## 18. Métricas de éxito
L4 constitutional coverage · L4 behavioral coverage · blocking safety gates · debt reduction · entropy delta · manual sync surfaces · ungrounded acceptance rate · duplicate effect rate · benchmark success rate · human intervention rate.

## 19. Regla de expansión futura
Nueva era de capability growth solo si L4 governance=CLOSED y debt wave1 target met (salvo excepción humana explícita).

## 20. Decisión arquitectónica
Program spec. Specs hijas solo si scope/owners/dependencias/paralelismo lo justifican. No fragmentar para producir documentos.

## 21. Orden recomendado
1 Reconciliation · 2 Generated Truth fixes · 3 L4 Constitutional Coverage · 4 L4 Gate Graduation · 5 Harness F2 · 6 Harness F3 · 7 Harness F5 · 8 Harness F4 · 9 L4 Eval Burn-down · 10 Debt Wave1 · 11 Benchmark real · 12 Entropy v1. F2/F5 alta prioridad técnica (integridad de decisión y efectos).

## 22. Riesgos
R1 sobrebloqueo→graduación por capability+calibration+expiry · R2 falsa cobertura→exigir cadena completa · R3 complejidad→reutilizar infra · R4 burn-down cosmético→preservar intent/migration · R5 benchmark artificial→tareas históricas+holdout · R6 exactly-once→reservation+idempotency key+receipt+crash tests.

## 23-25. Instrucción/Output/Criterio
Reconciliar contra HEAD, mapear a specs existentes (SE-376/377/378/380/381/383/384/386), no duplicar, mantener PROPOSED, aprobación humana antes de cambiar enforcement L3/L4 (§0 ejecutado). Output: output/coherence-closure-reconciliation-20260905.md (§24). Criterio final: demostrar qué regla aplicó, a qué capability, qué enforcement, qué test, qué evidencia, qué estado quedó — sistemático para riesgo alto = era cerrada.

## 26. OpenCode Implementation Plan
### Clasificación
- **Tier:** 2 (reportes/graduación por gates en scripts) · **Agent-capable:** hybrid (slices A/B/C/D/F report-only sí; E y graduación L4 requieren revisión humana)
- **Slices:** corresponde a A-H del spec; program spec — ejecución por frentes, cada uno con su propio PR y gates
- **Depends:** SE-374..386 (todos mergeados) · **Feeds:** SE-384 (benchmark), SE-386 (laws/contracts)

## Referencias
SE-376/377/378/380/381/383/384/386 (mergeados) · coherence-gates.sh · laws/ · contracts/ · planning-state.json · spec de la operadora 2026-09-05
