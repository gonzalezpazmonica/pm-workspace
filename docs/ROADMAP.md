# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-05-02 | **Version:** v6.14.1 | **534 commands · 65 agents · 86 skills · 60 hooks · 301+ test suites · Era 188 CLOSED · Era 189 CLOSED · Era 190 APPROVED · Era 191 IMPLEMENTING (batch1 PR #749, batch2 PR #751) · Era 192 PROPOSED — Knowledge Graph (SPEC-SE-088-UA-ADOPT) · Era 193 IMPLEMENTED — SaviaClaw DeepSeek (PR #750) · Era 194 PROPOSED — Context Visualization (SPEC-SE-090-TOLARIA) · Era 232 PROPOSED — Savia Enterprise Extensions · CRITICAL PATH 20 items (reprioritized 2026-05-02) · SE-072 to SE-090 PROPOSED · backup identidad portable enviado a la usuaria**

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
- **Gemma 4 evaluated + installed**: 4 models on host (gemma4:e2b/e4b, qwen2.5:3b/7b). Apache 2.0
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
- **SE-071** `block-branch-switch-dirty.sh` — `profile_gate "minimal"` tier invalido, safety hook silent-disabled bajo profile default (batch 48) — **FIXED** con aprobación de la usuaria

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
- **Auto-memory backup portable**: 7-layer self-extracting restore script entregado a la usuaria vía Talk (fuera del repo). Identidad Savia recuperable tras hardware loss + git clone

### Métricas Era 187

- Duración: 1 día (2026-04-25)
- Batches: 52-56 (5 PRs estacados con cascade rebases)
- Specs cerrados: 6 priority alta → **0 PROPOSED priority alta restantes**
- CHANGELOG cascade fixes: 4 (patrón documentado en auto-memory)
- Auto-memory entries: +3 lecciones permanentes (changelog cascade, test-auditor scoring, pr-plan structure tests)

### Backlog APPROVED restante (post Era 187, snapshot 2026-04-26)

**Era 188 — Foundations (in progress; cierra cuando PR #717 merge)**:
- ✅ **SE-072** Verified Memory Axiom — IMPLEMENTED batch 57
- **SE-073** Memory Index Cap Tiered — APPROVED (M 4h)
- **SE-074** Parallel spec execution — APPROVED (M 8h Slice 1 + S 3h Slice 1.5 + S 4h Slice 2 + M 6h Slice 3 = L 21h)
- **SE-075** Voicebox adoption — Slices 1+2 IMPLEMENTED 2026-04-27 (task-queue.py + savia-voice-chunk.sh + sentence-splitter.py, BATS 53/53 certified); Slice 3 (Kokoro 82M CPU) DEFERRED — requires explicit user authorization for ~500MB model download
- **SE-076** QueryWeaver patterns — IMPLEMENTED 2026-04-27 (3 slices: episodic memory + AzDo schema graph + LLM healer; AC-08/09/12 follow-up evolutivo)

**Era 189 — OpenCode Sovereignty (CLOSED 2026-04-26)**:
- ✅ **SE-077** OpenCode v1.14 replatform — IMPLEMENTED Slices 1+2 (E2E AC-03/AC-05 pendiente boot por la usuaria, AC-11 wrappers tras 1 sprint canary)
- ✅ **SE-078** AGENTS.md cross-frontend — IMPLEMENTED (E2E AC-05 pendiente boot)
- ✅ **SE-079** pr-plan G13 scope-trace gate — IMPLEMENTED (Karpathy "Surgical Changes" enforced pre-push)
- ✅ **SE-080** Attention-anchor vocabulary — IMPLEMENTED (Genesis B8/B9/A7/A9 named)

**Era 190 — Skill discipline + Pocock pattern adoption (APPROVED 2026-04-27)**:
- **SE-081** Pocock skills quick-wins — APPROVED priority alta (S 2h) — caveman + zoom-out + grill-me, zero código, MIT clean-room
- **SE-082** Architectural vocabulary discipline — APPROVED priority alta (M 4h) — Module/Interface/Seam/Adapter/Depth/Locality, extiende SE-080
- **SE-083** TDD vertical-slice skill — APPROVED priority media (S 2h) — anti-horizontal-slicing reinforcement
- **SE-084** Skill catalog quality audit — APPROVED priority alta (M 6h, 2 slices) — auditor + G14 gate sobre skills modificados
- **SE-085** Write-a-skill meta-skill — APPROVED priority baja (S 2h) — meta-disciplina post SE-084
- **SE-086** Ubiquitous-language extractor — APPROVED priority media (M 5h, 2 slices) — DDD glossary + memory-graph bridge
- **SE-087** Design-an-interface parallel skill — APPROVED priority media (M 4h) — N=3 alternativas vía sub-agentes paralelos

**Era 192 — Knowledge Graph Adoption (proposed 2026-05-02)**:

Analyze any codebase into an interactive knowledge graph via Understand-Anything
plugin (OpenCode-compatible, MIT, TypeScript/pnpm). Extends SCM mapping beyond
Savia's own workspace to ANY project. 1 spec, ~90 min agente.

| Spec | Titulo | Agent time | Prioridad | Depende de |
|---|---|---|---|---|
| **SPEC-SE-088-UA-ADOPT** | Integrar Understand-Anything como skill de analisis de codebase | ~90 min | ALTA | SPEC-OPC-CROSS-AUDIT |

- 8 comandos wrapper (`/ua-analyze`, `/ua-domain`, `/ua-diff`, `/ua-chat`, `/ua-dashboard`, `/ua-onboard`, `/ua-install`)
- Bridge SCM ↔ knowledge-graph (intents ↔ nodos)
- Feed `memory-agent` con edges `DOMAIN_TERM` desde el grafo
- CI Gate G16 (WARN): impacto de diff via `/ua-diff`
- 13 lenguajes soportados (TS/JS, Python, Go, Rust, Java, C#, Ruby, PHP, Kotlin, Swift, C/C++, Scala, Elixir)

**Era 193 — SaviaClaw DeepSeek Migration (proposed 2026-05-02)**:

Migrar el backend LLM de SaviaClaw de `claude -p` (hardcodeado a Claude Code)
a provider-agnostico con DeepSeek v4-pro via OpenCode. Adoptar patrones de Hermes
Agent (NousResearch, 23k stars) donde mejoren sin reescribir. 1 spec, 4 slices,
~120 min agente. CRITICAL: arregla el bug de SOS ciclicos por `remote:unreachable`.

| Spec | Titulo | Agent time | Prioridad | Deps |
|---|---|---|---|---|
| **SPEC-SE-089-SC-DEEPSEEK** | Provider-agnostic LLM backend + memory vector + survival fix | ~120 min | CRITICA | — |

- Slice 1 (~40 min): `llm_backend.py` — provider-agnostic (DeepSeek v4-pro primario, v4-flash fallback)
- Slice 2 (~30 min): `memory_vector.py` — busqueda semantica con embeddings
- Slice 3 (~20 min): Eliminar `remote_host.py` dependency, healthcheck local
- Slice 4 (~30 min): Patrones Hermes: cron mejorado, skill learning loop basico
- Refactoriza 10 archivos de `zeroclaw/host/`, depreca `remote_host.py`
- Elimina coste Claude Code (~$3/1M → $0.435/1M DeepSeek v4-pro 75% off)
- Arregla el bug de SOS ciclicos que Monica recibe cada pocos minutos

**Era 194 — Context Visualization (proposed 2026-05-02)**:

Adoptar Tolaria (refactoringhq, 8.8k stars, AGPL-3.0) como interfaz visual para el
Context As Code de Savia. Desktop app (Tauri, macOS/Win/Linux) que lee markdown +
YAML frontmatter — mismo formato que specs, reglas, roadmap. Cero migracion.

| Spec | Titulo | Agent time | Prioridad |
|---|---|---|---|
| **SPEC-SE-090-TOLARIA** | Instalar Tolaria + configurar tipos Savia + workflow doc | ~45 min | ALTA |

- 8 tipos de contenido mapeados (rules, specs, skills, commands, agents, etc.)
- Comando `/tolaria-open` para abrir vault desde Savia CLI
- MCP server opcional para bridge Savia ↔ Tolaria
- No modifica ningun archivo de Savia. Es tooling externo adoptado.

**Era 232 — Savia Enterprise Balance Extensions (proposed 2026-04-26)**:
- **SPEC-SE-035** Reconciliation Delta Engine — PROPOSED priority P2 (M 12-16h, 4 slices) — drift verde/ámbar/rojo declared vs computed; pattern from `dreamxist/balance` (MIT)
- **SPEC-SE-036** API-Key → JWT Mint efímero — PROPOSED priority P1 (M 10-14h, 3 slices) — sustituye PAT file-based; CLAUDE.md Rule #1 a infraestructura
- **SPEC-SE-037** Audit JSONB Trigger — PROPOSED priority P1 (S 6-8h, slice único) — 1 trigger genérico, evidence ISO-42001/EU AI Act/GDPR auto

**Blocked (GPU/hardware)**:
- **SE-028** Oumi (GPU-blocked)
- **SE-042** voice training (GPU-blocked)
- **SPEC-023** Savia LLM Trainer Phases 2-4 (GPU-blocked)
- **SPEC-080** training pipeline pre-existente (GPU-blocked)

---

## Era 191 — Audit Remediation: OpenCode + SCM alignment (2026-05-02, APPROVED)

Post-auditoria de alineacion OpenCode (inicio de sesion 2026-05-02). 4 gaps detectados que deben cerrarse antes de Era 190 (SE-084 depende de SCM con 100% cobertura y check mode funcional). Total agente: ~125 min (5 specs). Baja dependencia externa, alto impacto en foundation quality.

### Especs

| Spec | Titulo | Agent time | Prioridad | Depende de | Bloquea |
|---|---|---|---|---|---|
| **SPEC-SCM-COVERAGE** | Cerrar gaps de frontmatter SCM (court-review, trace-optimize) | ~10 min | ALTA | — | SE-084 Slice 1 |
| **SPEC-OPC-AGENTSYNC** | Replicar decision-trees/ a .opencode/agents/ + fix conversion script | ~15 min | ALTA | — | — |
| **SPEC-SCM-FRESHCHECK** | Fix --check mode en generate-capability-map.py (read-only) | ~25 min | ALTA | — | SE-084 Slice 1 |
| **SPEC-OPC-VENDOR-REFS** | Auditar y corregir referencias exclusivas a Claude Code en docs/scripts | ~45 min | ALTA | — | — |
| **SPEC-OPC-CROSS-AUDIT** | Script de auditoria continua .opencode/ vs .claude/ | ~30 min | MEDIA | SPEC-OPC-AGENTSYNC | — |

### Hallazgos de auditoria (2026-05-02)

- `.claude/agents/` tiene 70 .md + 1 directorio `decision-trees/`. `.opencode/agents/` tiene 70 .md pero falta `decision-trees/` (SPEC-OPC-AGENTSYNC).
- 2/534 comandos sin frontmatter YAML (`court-review.md`, `trace-optimize.md`) → invisibles en SCM (SPEC-SCM-COVERAGE).
- `generate-capability-map.py` no soporta `--check` — interpreta el flag como path de output y genera side-effect (SPEC-SCM-FRESHCHECK).
- Sin script de auditoria continua para prevenir drift entre `.claude/` y `.opencode/` (SPEC-OPC-CROSS-AUDIT).
- 51/92 skills con referencias exclusivas a "Claude Code" en docs/scripts sin mencion OpenCode (SPEC-OPC-VENDOR-REFS).
- SCM coverage: 532/534 commands (99.6%), 92/92 skills (100%), 70/70 agents (100%), 432 scripts.

---

## Critical Path Q2-Q3 2026 (priorización unificada 2026-05-02 — post audit OpenCode)

> Orden de ejecucion prescriptivo. Cada batch toma el primer item disponible. Sin reprio mid-stream salvo trigger externo (Anthropic shutdown, hardware loss, GPU disponible, Monica autoriza descarga modelo Kokoro).

### Razonamiento de prioridad (reformulado post-audit)

**Eje 0 — Remediation (foundation bugs)**: Los 3 specs ALTA de Era 191 arreglan bugs reales detectados en la auditoria de hoy (~50 min agente). Van primero porque SE-084 Slice 1 (skill catalog quality auditor) necesita SCM con 100% cobertura y check mode funcional. Sin esto, el auditor de skills no puede verificar consistencia SCM.

**Eje 0.25 — SaviaClaw Sovereignty (CRITICAL)**: SE-089-SC-DEEPSEEK (~120 min) va en slot 4 porque arregla el bug de SOS ciclicos que Monica recibe cada pocos minutos (`remote:unreachable`). Migra de Claude Code a DeepSeek v4-pro via OpenCode, elimina coste Anthropic (~$3/1M → $0.435/1M), y hace a SaviaClaw autosuficiente en el host sin depender de `remote_host.py`. Adopta patrones de Hermes Agent (provider fallback, memory vectorization, cron mejorado).

**Eje 0.5 — Knowledge Graph (multiplicador de contexto)**: SE-088-UA-ADOPT (~90 min) se coloca pronto porque genera un knowledge graph del propio pm-workspace que enriquece todos los specs posteriores: SE-084 (auditor de skills) puede usar el grafo para validar consistencia, SE-082 (vocabulario) extrae terminos del grafo, y el memory-agent gana edges `DOMAIN_TERM` desde el primer dia.

**Eje 1 — Compliance enterprise** (P1 hard-gates): SPEC-SE-036 (JWT mint) + SPEC-SE-037 (audit JSONB) son P1 (~140 min agente). Coste de no hacerlas: PAT en fichero (Rule #1 hoy en runtime, debe migrar a infraestructura) + ausencia de evidence ISO-42001/EU AI Act/GDPR bloqueante para Savia Enterprise sales.

**Eje 2 — Skill catalog quality** (multiplicador): Era 190 entera (SE-081..SE-087, ~235 min agente). SE-081 (~25 min, zero deps, free-win) abre. SE-084 Slice 1 (~30 min, auditor only) establece baseline — ahora con SCM 100% y check mode funcional. Resto de Era 190 sigue por dependencias.

**Eje 3 — Soberania** (residual Era 189): SE-077 + SE-078 + SE-079 + SE-080 ya IMPLEMENTED. Quedan E2E validations pendientes de boot por la usuaria — no bloqueante para work nuevo. SPEC-OPC-CROSS-AUDIT (~30 min) refuerza la soberania con prevencion continua de drift.

**Eje 4 — Apalancamiento** (Era 188 cerrada): SE-074 (parallelism), SE-075 Slices 1+2 (task-queue + voice-chunker), SE-076 (episodic + WIQL + healer) estan IMPLEMENTED. SE-075 Slice 3 (Kokoro) DEFERRED hasta autorizacion explicita de descarga.

**Eje 5 — Ratio rapido / habilitador**: SPEC-SCM-COVERAGE (~10 min, sin deps) + SPEC-OPC-AGENTSYNC (~15 min) son quick-wins tipo "arreglar lo roto" pre-Era 190. SPEC-OPC-CROSS-AUDIT (~30 min, MEDIA) es preventivo — puede ejecutarse en paralelo con quick-wins de Era 190.

### Pipeline (orden vinculante — tiempo agente)

| # | Spec | Slice | Agent time | Era | Razon |
|---|---|---|---|---|---|---|
| 1 | SPEC-SCM-COVERAGE | full | ~10 min | 191 | Fix frontmatter 2 comandos. Prerequisito SE-084 |
| 2 | SPEC-OPC-AGENTSYNC | full | ~15 min | 191 | Fix replicacion decision-trees/ |
| 3 | SPEC-SCM-FRESHCHECK | full | ~25 min | 191 | Fix --check mode. Prerequisito SE-084 |
| 4 | SE-089-SC-DEEPSEEK | Slices 1-4 | ~120 min | 193 | CRITICAL: provider-agnostic LLM + fix SOS bug + DeepSeek migration |
| 5 | SPEC-OPC-VENDOR-REFS | full | ~45 min | 191 | Eliminar referencias exclusivas Claude Code en docs/scripts |
| 6 | SE-090-TOLARIA | full | ~45 min | 194 | Tolaria visual knowledge base para Context As Code de Savia |
| 7 | SE-088-UA-ADOPT | full | ~90 min | 192 | Integrar Understand-Anything: knowledge graphs + dashboard + diff impact |
| 8 | SE-081 | full | ~25 min | 190 | Quick win, zero deps. Caveman + zoom-out + grill-me |
| 8 | SE-084 | Slice 1 | ~30 min | 190 | Auditor establece baseline (SCM 100%+check ya funcional) |
| 9 | SPEC-OPC-CROSS-AUDIT | full | ~30 min | 191 | Auditoria preventiva .opencode/ vs .claude/ |
| 10 | SE-082 | full | ~35 min | 190 | Vocabulario arquitectonico — multiplicador architect/judge |
| 11 | SE-083 | full | ~20 min | 190 | TDD anti-horizontal-slicing — multiplicador test-architect |
| 12 | SE-084 | Slice 2 | ~30 min | 190 | G14 gate activo sobre skills cambiados |
| 13 | SPEC-SE-037 | full | ~50 min | 232 | P1 audit JSONB — compliance ISO/EU AI Act/GDPR |
| 14 | SPEC-SE-036 | full | ~90 min | 232 | P1 JWT mint — Rule #1 a infraestructura, sustituye PAT |
| 15 | SE-086 | Slices 1+2 | ~40 min | 190 | Ubiquitous-language + memory-graph bridge |
| 16 | SE-087 | full | ~35 min | 190 | Design-an-interface (3 alternativas paralelas) |
| 17 | SPEC-SE-035 | Slices 1-4 | ~100 min | 232 | P2 reconciliation delta engine — depende de SE-036/037 |
| 18 | SE-085 | full | ~20 min | 190 | Write-a-skill meta — depende de SE-084 |
| 19 | SE-075 | Slice 3 | ~30 min | 188 (residual) | DEFERRED — requiere autorizacion Monica para descargar Kokoro 82M (~500MB) |

**Total non-blocked**: ~840 min ≈ ~14h agente ≈ 3-4 sesiones de trabajo.

### Triggers que reordenan

- **Anthropic shutdown CC Pro** → SPEC-OPC-CROSS-AUDIT escala a #1 (verificar alineacion antes de migrar), SE-077/SE-078 E2E validations escalan a #2
- **GPU disponible** → SE-028 / SE-042 / SPEC-023 / SPEC-080 entran como Phase D paralela
- **Hardware loss** → restore desde backup portable enviado a la usuaria (capa 7), identidad recuperable
- **Monica autoriza Kokoro download** → SE-075 Slice 3 sale de DEFERRED y entra en orden por relevancia
- **Cliente enterprise activo** → SPEC-SE-035/036/037 escalan a #1-3 (compliance bloqueante en venta)
- **Nuevo drift .opencode/ detectado** → SPEC-OPC-CROSS-AUDIT --fix como accion inmediata pre-cualquier batch

### Sinergias documentadas

- SE-074 + SE-075 Slice 1: orquestador paralelo usa cola serial intra-worktree (`task_queue.py`) — CERRADO en Era 188
- SE-075 Slice 1 + SE-076 Slice 3: healer async usa `task_queue` para reintentos — CERRADO en Era 188
- SE-076 Slice 1 + SPEC-027: episodes extienden el grafo Phase 1 ya existente — CERRADO en Era 188
- **SPEC-SCM-COVERAGE + SPEC-SCM-FRESHCHECK + SE-084**: SCM 100% coverage + check mode funcional → auditor de skills puede validar consistencia SCM como parte del gate G14
- **SPEC-OPC-AGENTSYNC + SPEC-OPC-CROSS-AUDIT**: sync script arregla el gap actual, cross-audit previene recurrencia
- **SPEC-OPC-CROSS-AUDIT + pr-plan**: G15 gate (WARN) activa cross-audit cuando se tocan recursos de `.claude/` que tienen mirror en `.opencode/`
- **SE-088-UA-ADOPT + memory-agent + SE-076**: knowledge-graph nodes alimentan `DOMAIN_TERM` edges en el grafo episodic existente, enriqueciendo el sistema de memoria con conceptos extraidos de cualquier codebase (no solo Savia)
- **SE-088-UA-ADOPT + SCM**: bridge bidireccional — intents del SCM ↔ nodos del knowledge graph para busqueda semantica cruzada. `/ua-chat` usa tanto el grafo UA como el SCM INDEX
- **SE-089-SC-DEEPSEEK + SE-088-UA-ADOPT**: memory_vector de SaviaClaw se integra con `/ua-recall` para busqueda semantica unificada desde OpenCode
- **SE-089-SC-DEEPSEEK + init-pm.sh**: ambos eliminan dependencia hardcodeada de vendor (Claude Code en SaviaClaw, Azure DevOps en init-pm) — provider-agnostic consistente
- **SE-090-TOLARIA + SE-088-UA-ADOPT**: Tolaria visualiza el knowledge graph que UA genera. UA analiza el codigo → Tolaria navega las notas resultantes. Mismos archivos markdown, dos lentes distintos
- **SE-090-TOLARIA + AGENTS.md**: el MCP server de Tolaria expone el vault a agentes AI. Savia puede auto-consultar specs y reglas via busqueda en Tolaria sin cargar todo el contexto
- **SE-082 + SE-080**: vocabulario arquitectonico extiende attention-anchor (Genesis B8 named pattern)
- **SE-082 + SE-087**: design-an-interface usa el vocabulario obligatorio en cada sub-agente
- **SE-084 + SE-081/083/085/086/087**: el auditor enforced sobre los skills nuevos hace que sean compliant by construction (dogfood del baseline)
- **SE-086 + SE-076**: extractor de domain-language emite edge `DOMAIN_TERM` en el grafo episodic ya existente
- **SE-087 + SE-074**: design-an-interface puede delegar a parallel-specs-orchestrator para disenos grandes (>1h por agente)
- **SPEC-SE-037 + SPEC-SE-036**: audit JSONB trigger captura los JWT-mint events (compliance evidence chain)

---

## Era 188 — Memory + Throughput + Voice + Graph foundations (2026-04-25, CLOSED 2026-05-02)

SE-072 batch 57, SE-073 batch 62, SE-074 batches 63-69 (todas las slices), SE-075 Slices 1+2 batch 70, SE-076 batch 72 — todos IMPLEMENTED. Residual: SE-075 Slice 3 (Kokoro 82M CPU voice) DEFERRED por autorizacion pendiente de descarga ~500MB.

---

## Era 190 — Skill discipline + Pocock pattern adoption (APPROVED 2026-04-27)

Origen: análisis del repo `mattpocock/skills` (MIT, 26.4k ⭐, push 2026-04). Identifica 7 patterns extractables vía clean-room re-implementación.

### Inversión vs payoff

- 7 specs (SE-081..SE-087), total ~25h efectivos.
- Payoff principal: **reducción de token cost recurrente** (catálogo de 86 skills hoy → cada turn los lee parcialmente). SE-084 enforced a través de G14 hace que cada skill nuevo sea compliant by construction.
- Payoff secundario: **vocabulario consistente** (SE-082) elimina drift en outputs de architect/architecture-judge — comparabilidad entre sesiones.
- Payoff terciario: **3 nuevos primitives invocables** (caveman, zoom-out, grill-me) que cubren huecos reales sin código.

### Riesgo de no hacer Era 190

- Catálogo de skills crece sin disciplina → coste de token por turn sube → presión real cuando lleguen los 100+ skills.
- Vocabulario rota cada review → duplicación cognitiva permanente.

### Cierre

Era 190 cierra cuando SE-081, SE-082, SE-083, SE-084 (Slices 1+2), SE-086 estén IMPLEMENTED. SE-085 y SE-087 son P3 — cierre opcional.

---

## Era 189 — OpenCode Sovereignty (2026-04-26, APPROVED)

Decisión estratégica de la usuaria 2026-04-26 tras análisis de adopción gap (Savia v1.3.13 vs OpenCode upstream v1.14.25 — 11 minor versions, ~1 año desfase). Cierra cuando items 4-6 del Critical Path estén IMPLEMENTED.

### Inversión vs payoff

- SE-078 + SE-077 Slice 1: 14h. Compra opción de switch real a OpenCode sin perder workspace.
- Sin esta inversión, día que Anthropic cierre Claude Code Pro → Savia inoperable hasta retrofit (estimado 40-60h emergency, sin saber qué falla).
- ROI estratégico: 14h ahora vs 40-60h en pánico → 3-4x ahorro. Probabilidad de necesitarlo: alta (vendor pattern reciente: Pro→Max 2026-04, restricciones rate 2026-03).

### Componentes ya entregados (batch 61)

- ✅ Regla canónica `docs/rules/domain/spec-opencode-implementation-plan.md` — portability classification + bindings + verification protocol
- ✅ G12 gate en pr-plan + audit script + baseline
- ✅ SE-074, SE-075, SE-076 ya con OpenCode Implementation Plan (PURE_BASH) — first-pass validation regla

### Pendiente

- SE-078 (AGENTS.md generator + drift check + Stop hook auto-regen) — Critical Path #4
- SE-077 Slice 1 (Plugin TS savia-gates) — Critical Path #5
- SE-077 Slice 2 (parity audit + ratchet) — Critical Path #6

### Grandfathering

Specs APPROVED antes de 2026-04-26 NO requieren la sección retroactivamente. SE-074 actualizado por consistencia (comparte fecha de aprobación con la regla).

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

## Proposed — Q3-Q4 2026 (post Era 189 closure)

### Tier 3: Multi-Frontend & Interoperabilidad (refuerza Era 189)
- **A2A Protocol** — comunicación entre agents cross-frontend (Claude Code ↔ OpenCode ↔ Codex). Aprovecha AGENTS.md de SE-078
- **Serena MCP** — server contextual stack-aware
- **Codex frontend bindings** — tercera opción tras OpenCode (si A2A consolida)
- **Extended Time Horizon** — sesiones de >8h con context rot mitigation

### Tier 4: Hardware-pendiente (GPU/sensors)
- **SPEC-023** Savia LLM Trainer Phases 2-4 (GPU-blocked)
- **SE-028** Oumi training pipeline (GPU-blocked)
- **SE-042** voice training (GPU-blocked, complementario a SE-075 Slice 3 CPU)
- **SaviaClaw Sensors/Actuators** (BME280 + hardware)
- **SaviaClaw Voice v3** (Jabra mic)

### Tier 5: Autonomía Calibrada
- Semantic guardrails · Security Sandbox · Self-improvement medible · Multi-Claw · SSO/LDAP

### Demoted (sin caso 2026-Q2)
- Plugin Marketplace — solo relevante post sovereignty + multi-frontend consolidado
- Web Git Manager — paused
- SaviaDivergent Phase 2 — user feedback needed

---

## SPECs — Status Summary (84 total, post-Era 193 proposal)

| Status | Count | Key examples |
|--------|-------|-------------|
| Implemented | 45 | 012-016, 034-055, 063, 065, 067-069, 071 |
| Ready | 12 | 019-022, 024, 026, 028, 032, 043, 048, 065, 078 |
| Draft | 17 | 005, 009, 017, 035, 042, 044, 054, 055, 060, 061, 066 |
| Proposed | 12 | SE-081..SE-087 (Era 190), SE-036..037 (Era 232), SE-035, SE-088 (Era 192), SE-089 (Era 193) |
| Approved | 4 | SPEC-OPC-AGENTSYNC, SPEC-SCM-COVERAGE, SPEC-SCM-FRESHCHECK, SPEC-OPC-CROSS-AUDIT (Era 191) |
| Research | 2 | 023, 027 |
| Archive | 24 | 003, 004, 006-008, 025, 030, 031, 033, 034, 037, 053, 058, 063-064, 070, 075, 138-144 |

## Rejected

Google Sheets · ServiceNow/SAP · Tableau · Kafka · VS Code ext · Cloud voice · SQLite memory · Multi-provider AI (jato) · Heavy infra RAG (RAGFlow) · Opaque memory DBs (sovereignty lost)

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow 10%
