# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-04-25 | **Version:** v6.8.0 | **532 commands · 65 agents · 86 skills · 60 hooks (64 regs) · 301+ test suites · Era 182-184 CLOSED, Era 185 CLOSED, Era 186 hook ratchet **CLOSED**, Era 187 spec drift + AC closure **CLOSED 2026-04-25**, Era 188 IN PROGRESS (Opus 4.7 + drift + SE-046 + SE-049 Slice 1 · **HOOK COVERAGE 100%** 60/60 · SE-071+SE-039+SE-038+SE-065+SPEC-120+SE-070+SPEC-055+SPEC-121+SPEC-122+SPEC-078+SPEC-124+SE-072 IMPLEMENTED · SE-073 APPROVED from GenericAgent research · spec triage 74→70 PROPOSED + 6 APPROVED promotions · **0 PROPOSED priority alta restantes** · test quality baseline 332/332 ≥80 · agent size ratchet 27 violations frozen · hook-critical baseline 5→4 tightened · backup identidad portable enviado a Monica)**

---

## Done — Eras 1-124 (v0.1 → v3.24)

PM core, 16 language packs, context engineering, security, Savia persona, Company Savia, Travel Mode, Savia Flow, Git Persistence, Savia School, accessibility, adversarial security, Visual QA, dev sessions. Mobile v0.1. Web Phases 1-3. Digest Suite. SaviaClaw ESP32.

## Done — Eras 125-137: Memory Intelligence (v3.25 → v3.44)

Progressive loading, engram patterns, vector memory (recall 40→90%), contradiction/TTL, graph memory, digest bridge, security absorption (jato+strix). 9-language READMEs. 30+ repos analyzed.

## Done — Eras 138-164: Architecture Exploitation (v3.45 → v3.96)

Temporal memory, hybrid search, agent evaluation, cognitive sectors, SaviaDivergent specs, test architect, CI quality gates, execution supervisor, capability maps, context index, AgentScope research, hidden features activation. 69 tests in single SPEC batch (047-052).

## Done — Eras 165-173: Exploit-First Engineering (v3.97 → v4.3)

- **165**: CLAUDE.md diet 121→48 lines (60% token savings). Per-turn cost discovery
- **166**: Memory Resilience — deep extraction via Stop hook, quality gates. 22 tests
- **167-170** (batch): Token Economics, Coordinator Mode research, Spec Validation, Tool Healing. 28 tests
- **171**: Hook Overhaul (SPEC-071) — 17/28 events (61%), prompt+HTTP hooks. Savia Nidos
- **172**: Shield NER fix — allow-list, threshold calibration
- **173**: Emotional Regulation (Anthropic research). Savia Models v0.1. 47 tests

## Done — Era 174: Hygiene + Stability (v4.4 → v4.5)

- **SPEC hygiene**: 6 duplicate SPEC numbers renumbered (→ SPEC-070/073-077). 13 empty PBI placeholders removed
- **Critical bugfix**: hook-pii-gate.sh subshell pipe never propagated FINDINGS — PII gate was silently broken. Fixed
- **Debt audit**: 4 parallel audits (hooks, test gaps, staleness, suite). 78/86 → 91/91 tests (100%)
- **5 new test suites**: pii-gate(91), confidentiality-sign(80), backup(83), company-repo(83), emergency-plan(83). All 80+ quality
- **3 async hooks hardened**: trap error logging for live-progress, session-end-snapshot, file-changed-staleness
- **Gemma 4 evaluated + installed**: 4 models on Lima (gemma4:e2b/e4b, qwen2.5:3b/7b). Apache 2.0
- **Emergency Watchdog**: systemd service monitors internet every 5 min. Auto-activates local LLM on failure
- **NO_FLICKER**: enabled in settings.json

## Done — Eras 175-178: Communication + Security + Quality (v4.6 → v4.8)

- **175** (v4.6): README benefits-first rewrite (215→148 lines, -31%). Both ES and EN aligned
- **176** (v4.7): Prompt Security Scanner — 10 rules (PS-01 to PS-10), zero LLM, 17 tests (85/100)
- **177** (v4.8): Spec Quality Auditor — 9-criteria scorer, 21/73 specs certified, 17 tests (98/100)
- **178** (v4.9): Workspace consolidation — inventory audit, counter correction, 4 orphaned hooks identified

---

## Done — Era 179: Audit Correctiva (v4.10)

- **P0a**: Clara Philosophy 100% — 36 DOMAIN.md created (89/89 skills with dual docs)
- **P0b**: EN translations — best-practices-claude-code.en.md + memory-system.en.md
- **P0c**: 4 feature guides (Emergency Watchdog, Prompt Security Scanner, Spec Quality Auditor, Workspace Consolidation)
- **P0d**: SPEC triage — 78 SPECs classified (14 archive, 5 promote, 4 merge, 17 keep)
- **P0e**: 7 regional READMEs rewritten to v4.6+ benefits-first format
- **P0f**: decision-log.md created with architecture decisions and rejections
- **P0g**: SPEC-078 Dual Estimation — spec written, template updated, estimation policy extended

---

## Done — Era 180: Granular Permissions + Test Coverage (v4.11)

- **P1**: 5-tier permission system (L0-L4), 48 agents updated, validation script + 7 tests
- **P2**: 10 new test suites (CI, security, workflow, utility). 10→20 suites (100% increase)

## Done — Era 181: SPEC Verification (v4.12)

- **SPEC-065**: Execution Supervisor — session action log + retry circuit breaker. 12+14 tests
- **SPEC-048**: Dev Session Discard — clean session cleanup. 11 tests
- **SPEC-020**: Memory TTL — expires_at verified with existing implementation. Test coverage added

---

## Pipeline — Q2 2026 (Eras 182+)
- Effort: 15h | Impact: Medium (maintainability)

## Era 182 — Architecture Audit Reprioritization (2026-04-20) — CLOSED 2026-04-21

Post-auditoría arquitectónica (`output/audit-arquitectura-20260420.md`): 15 specs nuevos SE-043→SE-057 priorizados por ROI sobre exploración nueva. Batches 5-12 ejecutaron todos los Tier 0-2.

### Tier 0 — Crítico inmediato

- ✅ **SE-051** SPEC-123 approval gate — `scripts/spec-approval-gate.sh` (batch 6)
- 🔒 **SE-045** Session-init split fast-path — Enterprise-only scope (#648), fuera de máquina dev

### Tier 1 — Cerrar deuda detectada (audit)

- ✅ **SE-043** CLAUDE.md drift auto-check — `scripts/claude-md-drift-check.sh` (batch 6)
- ✅ **SE-044** SPEC-110 ID collision + ADR — `docs/decisions/adr-001-spec-110-id-collision-resolution.md` (batch 7)
- ✅ **SE-046** Baseline re-levelling — `scripts/baseline-tighten.sh` (batch 7)
- ✅ **SE-047** Agents catalog auto-sync — `scripts/agents-catalog-sync.sh` (batch 7)
- ✅ **SE-048** Rule-orphan detector — `scripts/rule-orphan-detector.sh` (batch 7)
- 🟡 **SE-054** SE-036 frontmatter Slices 2-3 — 125 specs normalizados (batch 8). 4 specs legacy con `**Status**:` inline quedan en excepción documentada

### Tier 2 — Cierres pendientes

- ✅ **SE-050** SPEC-122 Slice 2 — `.claude/skills/emergency-mode/` (batch 9). Slice 3 rollout diferido
- ✅ **SE-052** Agent-size remediation plan — `scripts/agent-size-remediation-plan.sh` (batch 8)
- ✅ **SE-053** CHANGELOG.d consolidation hook — `scripts/changelog-consolidate.sh` + `changelog-consolidate-if-needed.sh` (batch 7)

### Tier 3 — Champions research (preservados del roadmap previo)

- SE-032 Reranker · SE-033 BERTopic · SE-035 Mutation testing · SE-028 Oumi · SE-041 Memvid

### Tier 7 — Backlog frío (DIFERIDOS post-audit)

- SPEC-102/103/104 PDF chain (Java deps sin caso)
- SPEC-107 cognitive debt (research-heavy sin probe)
- SPEC-100 GAIA (sin caso actual)
- SPEC-SE-003/004/009/010/014 enterprise (sin demanda)
- SE-042 voice training (sin GPU)

Effort total Tier 0-2: ~112h planificado, ~75h ejecutado (batches 5-12, del 2026-04-20 al 2026-04-21). SE-045 diferido por scope Enterprise-only. Ver `output/audit-roadmap-reprioritization-20260420.md` para ROI detallado.

## Era 183 — Scrapling Research Backend (2026-04-21) — CLOSED 2026-04-22

Research `output/research/scrapling-20260421.md` identifica **SE-061 Scrapling** como champion Tier 3 con ROI inmediato. Ejecutado Tier 3 completo batches 14-21 (5/6 champions implementados, SE-028 diferido).

### Tier 3 — Champions research (estado final)

1. ✅ **SE-061** Scrapling — 4 slices completos (batches 14-17). probe + fetch wrapper + skills integration + MCP opt-in. 103 tests
2. ✅ **SE-035** Mutation testing Slice 2 — skill + wrapper (batch 18). 33 tests
3. ✅ **SE-032** Reranker Slice 2 — `scripts/rerank.py` + skill (batch 19). 36 tests, validación empírica cross-encoder funcional
4. ✅ **SE-033** BERTopic Slice 2 — `scripts/topic-cluster.py` + skill (batch 20). 37 tests
5. ✅ **SE-041** Memvid Slice 2 — `scripts/memvid-backup.py` + skill (batch 21). 40 tests, round-trip SHA256 integrity validado
6. 🔒 **SE-028** Oumi — diferido, requiere GPU para training pipeline (sin hardware en máquina dev)

**Resumen Era 183**: 5/6 champions ejecutados. 249 tests nuevos certified. 8 batches (#655-662). Todos los skills con fallback graceful (zero-install default) + integracion opt-in opcional.

### Tier 7 refresh (sin cambios post-Era 182)

Sigue: SPEC-102/103/104 PDF · SPEC-107 · SPEC-100 GAIA · SPEC-SE-003/004/009/010/014 · SE-042 · **SE-028** (añadido).

---

## Era 184 — Consolidation + Hygiene (2026-04-22) — CLOSED 2026-04-22

Post-Era 183 drift audit (batch 23) identifica deuda compuesta tras 22 batches consecutivos sin hygiene. **SE-062** agrupa 5 slices cortos que cierran drift sin añadir features.

### SE-062 slices (5/5 completados)

1. ✅ **SE-062.1** Counter sync — CLAUDE.md/ROADMAP/filesystem skills triple check (batch 24)
2. ✅ **SE-062.2** Duplicate SE-056 resolution — SE-044 spec-id guard enforced (batch 24)
3. ✅ **SE-062.3** Skills aggregator — `tier3-probes` + `workspace-integrity` cubren 13 scripts huérfanos (batch 25)
4. ✅ **SE-062.4** SE-053 changelog hook activation — GHA workflow `changelog-consolidate.yml` (batch 26)
5. ✅ **SE-062.5** SE-036 frontmatter finale — 4 specs legacy (SPEC-066/067/068/069) normalizados (batch 27)

Resultado: `specs-frontmatter-normalize.sh --scan` PASS sin drift en 198 specs. `claude-md-drift-check.sh` PASS.

### No scope Era 184

- No features nuevas
- No Tier 7 unlock (PDF chain, GAIA, Enterprise)
- No SE-028 Oumi (requiere GPU)
- No SE-042 voice training

Ver `docs/propuestas/SE-062-era184-consolidation-hygiene.md` para detalles.

---

## Era 185 — Agent Code Map Enforcement + Hook Audit Close-Loop (2026-04-22, IN PROGRESS)

Post-research `coderlm` (`output/research-coderlm-20260421.md` — veredicto ADOPTAR PATRÓN) + research agentshield. Formaliza el uso real del sistema ACM mediante hook de enforcement pre-tool, y cierra el audit de inyección en hooks con mecanismo de exención.

### Especs

| Spec | Título | Effort | Estado | Batches |
|---|---|---|---|---|
| **SE-060** | Hook injection + hidden directives audit | M 6h | **IMPLEMENTED** | 10 (Scripts 1+2) · 30 (close-loop exemptions) |
| **SE-063** | ACM enforcement pre-tool hook | S 4-6h | **IMPLEMENTED** | 28 (Slice 1+2) · 29 (reg + Slice 3) |
| **SE-064** | ACM multi-host generator (Cursor/Windsurf/Copilot) | M 8h | PROPOSED | Baja (on-demand) |

SE-063 cerrada tras batch 29 (Slice 3 bypass semántico + registro PostToolUse marker). SE-060 cerrada tras batch 30 (mecanismo de exención `# hook-audit-detector:`, audit real-world 0 findings/60 hooks). SE-064 mantiene backlog hasta demanda real de usuario de IDE non-Claude. Era 185 cierra cuando SE-060 + SE-063 validen ≥1 sprint en uso real.

Gaps solucionados:
- Agentes ignoran `.agent-maps/INDEX.acm` y lanzan glob/grep masivo redundante pese a existir mapas pre-calculados (SE-063)
- 4 false positives en `validate-bash-global.sh` — hook-detector legítimo cuyas regex strings disparaban HOOK-03/HOOK-06 (SE-060)

Ver propuestas: `docs/propuestas/SE-063-*.md`, `docs/propuestas/SE-064-*.md`.

---

## Era 186 — Opus 4.7 Calibration (2026-04-23, IN PROGRESS)

Post-analisis del Opus 4.7 migration guide (Anthropic + Daily Dose of Data Science 2026-04-23). 5 gaps identificados en Savia vs 4.7 defaults: literal instruction following, fewer subagents, XML tag absence, adaptive thinking deprecates fixed budgets, context rot en 1M sessions.

### Especs

| Spec | Titulo | Effort | Estado | Batches |
|---|---|---|---|---|
| **SE-066** | Review agents finding-vs-filtering | S 4h | **IMPLEMENTED** | 31 |
| **SE-067** | Orchestrator fan-out + feasibility-probe adaptive | S 3h | **IMPLEMENTED** | 32 |
| **SE-068** | XML tags in top-tier opus-4-7 agents | M 6h | **IMPLEMENTED** | 33 |
| **SE-069** | context-rot-strategy skill | M 5h | **IMPLEMENTED** | 34 |
| **SE-070** | Opus 4.7 eval scorecard (37 sonnet agents A/B) | L 12h | PROPOSED | 35 (infra), Baja deferred |

Batches 31-35 combinados en un unico PR (integration branch `agent/batch31-35-opus47-calibration-20260423`). Era 186 cierra cuando SE-070 eval se ejecute al menos parcialmente (3 agents candidate) O cuando quede clara decision de no-upgrade global.

Gaps solucionados:
- Review agents recall drop bajo 4.7 filter-literal (SE-066)
- Orchestrators under-spawning sin prompt explicito (SE-067A)
- feasibility-probe usaba budget_tokens deprecated (SE-067B)
- 0 agents con XML structure pese a 30% quality gap documentado (SE-068)
- Sin skill para 5-option session management en 1M context (SE-069)

Script transversal: `scripts/opus47-compliance-check.sh` valida los 5 batches con 24 BATS tests.

Ver propuestas: `docs/propuestas/SE-066-*.md` .. `docs/propuestas/SE-070-*.md`.

---

## Era 186 extension — Hook coverage ratchet + triage (2026-04-24, **CLOSED 2026-04-25**)

Batches 39-51 anadieron BATS tests a **40 hooks**, elevando cobertura de **31% (18/58)** a **100% (58/58)** en 13 iteraciones de +3-4 hooks/batch. 1100+ tests certified con score auditor ≥80 (avg ~90).

### Milestones hook coverage

| Punto | Tested | Cobertura |
|---|---|---|
| Pre-batch-39 | 18/58 | 31% |
| Batch 42 (50%) | 30/58 | 52% |
| Batch 47 (75%) | 45/58 | 77.6% |
| Batch 48 | 48/58 | 82.7% |
| Batch 49 (85%) | 51/58 | 87.9% |
| Batch 50 | 55/58 | 94.8% |
| **Batch 51** | **58/58** | **100% — MILESTONE** |

### Bugs descubiertos via tests

- `cwd-changed-hook.sh` — C# detection crashed on pipefail (batch 41) — FIXED
- `emotional-regulation-monitor.sh` — numeric score parsing crash (batch 41) — FIXED
- `memory-auto-capture.sh` — TOOL_NAME unbound guard (batch 44) — FIXED
- **SE-071** `block-branch-switch-dirty.sh` — `profile_gate "minimal"` tier invalido, safety hook silent-disabled bajo profile default (batch 48) — **FIXED** con Monica approval

### Spec triage 2026-04-24

Post-batch 48: triage de los 74 specs en `status: PROPOSED` para reducir ruido en backlog y promover candidatos alineados con el trabajo actual.

| Accion | Cantidad |
|---|---:|
| Promoted a APPROVED | 5 |
| Priority alta asignada | 9 (era 5+4) |
| Priority media asignada | 33 |
| Priority baja asignada | 21 |
| Sin priority (meta/ADR/TEMPLATE) | 6 |
| Ya APPROVED pre-triage | 4 (SE-028, SE-042, SPEC-023, SPEC-080) |

### Nuevos APPROVED (ready for sprint)

| Spec | Titulo | Rationale |
|---|---|---|
| **SE-038** | Agent catalog size audit (Rule #22) | Mechanical compliance, bajo esfuerzo |
| **SE-039** | Test-auditor global sweep ≥80 sobre todos los .bats | Aligned con batch 48 hook coverage work |
| **SE-065** | responsibility-judge S-06 i18n (ES false positives) | Already debugged en workarounds previos |
| **SE-070** | Opus 4.7 calibration scorecard (37 agents A/B) | Aligned Era 186 Opus 4.7 focus |
| **SPEC-120** | Spec template alignment con github/spec-kit | Small template cleanup |

Backlog APPROVED total: **9 specs** (5 nuevos + 4 training pipeline pre-existentes).

---

## Era 187 — Spec drift correction + priority-alta closure (2026-04-25, **CLOSED 2026-04-25**)

Era exprés (1 día). Trigger: tras Era 186 hook ratchet closure, audit profunda de PROPOSED priority alta detectó que 3 de 5 specs eran **status drift** (implementados pero PROPOSED) y 2 eran IN_PROGRESS reales. Cierre completo de la cola priority alta + persistencia de identidad Savia portable.

### Specs cerrados (6 IMPLEMENTED + 1 APPROVED→IMPLEMENTED)

| Spec | Tipo | Batches | Resolution |
|---|---|---|---|
| **SPEC-055** test-auditor | drift | 52 | Status flip + Resolution. 5 scripts deliverables verificados, en uso diario desde batch 5 |
| **SPEC-078** dual-estimation | drift | 55 | Status flip Fase 1 MVP. Engine + hook + política + tests score 82 ya existían desde Era 179 |
| **SPEC-121** handoff-as-function | IN_PROGRESS→DONE | 53 | 3 ACs cerrados: Handoff Format en 5 agentes SDD, cross-doc en agent-notes-protocol, CHANGELOG |
| **SPEC-122** LocalAI emergency | IN_PROGRESS→DONE | 54 | 4 ACs cerrados: SessionStart hook (feature-flagged), autonomous-safety nota, 30 tests score 94, CHANGELOG |
| **SPEC-124** pr-agent wrapper | IN_PROGRESS→DONE | 56 | 3 ACs cerrados: workflow template reusable, court-external-judges policy doc, CHANGELOG |

### Bonus closures

- **Era 186 hook ratchet** marcada CLOSED en batch 52 (100% milestone 58/58 alcanzado batch 51)
- **scripts/test-auditor-sweep.sh** bug fix: `.score` → `.total` extraction (sweep ahora reporta 100% real vs 0% bug)
- **Baseline tightening**: hook-critical-violations 5 → 4 (consistente últimos 5 hook-bench)
- **CLAUDE.md drift fix**: 58→59 hooks, 62→63 regs (post emergency-mode-readiness hook add)
- **Auto-memory backup portable**: 7-layer self-extracting restore script entregado a Monica vía Talk (fuera del repo). Identidad Savia recuperable tras hardware loss + git clone

### Métricas Era 187

- Duración: 1 día (2026-04-25)
- Batches: 52-56 (5 PRs estacados con cascade rebases)
- Specs cerrados: 6 priority alta → **0 PROPOSED priority alta restantes**
- CHANGELOG cascade fixes: 4 (patrón documentado en auto-memory)
- Auto-memory entries: +3 lecciones permanentes (changelog cascade, test-auditor scoring, pr-plan structure tests)

### Backlog APPROVED restante (post Era 187)

- **SE-072** Verified Memory Axiom (GenericAgent research)
- **SE-073** Memory Index Cap Tiered (GenericAgent research)
- **SE-028** Oumi (GPU-blocked)
- **SE-042** voice training (GPU-blocked)
- **SPEC-023** Savia LLM Trainer Phases 2-4 (GPU-blocked)
- **SPEC-080** training pipeline pre-existente

Próximo trabajo (Era 188 candidato): SE-072+SE-073 (sin-GPU) o esperar señal usuaria.

---

### Backlog (blocked or low priority)

| Item | Blocker | Priority |
|------|---------|----------|
| SaviaClaw Sensors | BME280 hardware | High when unblocked |
| SaviaClaw Actuators | Hardware | High when unblocked |
| SaviaClaw Voice v3 | Jabra mic | Medium |
| Web Git Manager | Spec exists, paused | Medium |
| SaviaDivergent Phase 2 | User feedback needed | Medium |
| SPEC-032 Security Benchmarks | — | Low |
| SPEC-042 Live Progress | — | Low |

## Proposed — Q3-Q4 2026

### Tier 3: Interoperabilidad
- Savia LLM Trainer Phases 2-4 (SPEC-023) · A2A Protocol · Serena MCP · Extended Time Horizon

### Tier 4: Autonomia Calibrada
- Semantic guardrails · Security Sandbox · Self-improvement medible · Plugin Marketplace · Multi-Claw · SSO/LDAP

---

## SPECs — Status Summary (78 total, post-triage Era 179)

| Status | Count | Key examples |
|--------|-------|-------------|
| Implemented | 45 | 012-016, 034-055, 063, 065, 067-069, 071 |
| Ready | 12 | 019-022, 024, 026, 028, 032, 043, 048, 065, 078 |
| Draft | 17 | 005, 009, 017, 035, 042, 044, 054, 055, 060, 061, 066 |
| Proposed | 5 | 060-062, 064, 066 |
| Research | 2 | 023, 027 |
| Archive | 24 | 003, 004, 006-008, 025, 030, 031, 033, 034, 037, 053, 058, 063-064, 070, 075, 138-144 |

## Rejected

Google Sheets · ServiceNow/SAP · Tableau · Kafka · VS Code ext · Cloud voice · SQLite memory · Multi-provider AI (jato) · Heavy infra RAG (RAGFlow) · Opaque memory DBs (sovereignty lost)

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow 10%
