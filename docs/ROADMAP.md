# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-04-04 | **Version:** v4.12.0 | **508 commands · 48 agents · 89 skills · 48 hooks · 106 test suites · 78 SPECs (48 done)**

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

## Era 182 — Architecture Audit Reprioritization (2026-04-20)

Post-auditoría arquitectónica (`output/audit-arquitectura-20260420.md`): 15 specs nuevos SE-043→SE-057 priorizados por ROI sobre exploración nueva.

### Tier 0 — Crítico inmediato

- **SE-051** SPEC-123 approval gate (2h) — Rule #8 erosion fix
- **SE-045** Session-init split fast-path (12h) — 468ms→<20ms SLA

### Tier 1 — Cerrar deuda detectada (audit)

- **SE-043** CLAUDE.md drift auto-check (4h)
- **SE-044** SPEC-110 ID collision + ADR (3h)
- **SE-046** Baseline re-levelling (3h)
- **SE-047** Agents catalog auto-sync (4h)
- **SE-048** Rule-orphan detector (6h)
- **SE-054** SE-036 frontmatter Slices 2-3 finish (10h)

### Tier 2 — Cierres pendientes

- **SE-050** SPEC-122 Slice 2+3 or SUPERSEDED (8h)
- **SE-052** Agent-size remediation plan (24h)
- **SE-053** CHANGELOG.d consolidation hook (2h)

### Tier 3 — Champions research (preservados del roadmap previo)

- SE-032 Reranker · SE-033 BERTopic · SE-035 Mutation testing · SE-028 Oumi · SE-041 Memvid

### Tier 7 — Backlog frío (DIFERIDOS post-audit)

- SPEC-102/103/104 PDF chain (Java deps sin caso)
- SPEC-107 cognitive debt (research-heavy sin probe)
- SPEC-100 GAIA (sin caso actual)
- SPEC-SE-003/004/009/010/014 enterprise (sin demanda)
- SE-042 voice training (sin GPU)

Effort total Tier 0-2: ~112h (~3 sprints al 30% dedicación). Ver `output/audit-roadmap-reprioritization-20260420.md` para ROI detallado.

## Era 183 — Scrapling Research Backend (2026-04-21)

Research `output/research/scrapling-20260421.md` identifica **SE-061 Scrapling** como champion Tier 3 con ROI inmediato: desbloquea research en sites Cloudflare-gated que hoy fallan silenciosamente para `tech-research-agent` + `web-research`.

### Tier 3 — Champions research (reordenado por ROI research-stack)

**Orden propuesto** (alto → bajo impacto en research agents existentes):

1. **SE-061** Scrapling — 21h total (4 slices). Bypass anti-bot + adaptive selectors + MCP nativo. **Nuevo champion #1**.
2. **SE-035** Mutation testing — probe ya merged (#645), pendiente integración CI.
3. **SE-032** Reranker — probe ya merged (#650), pendiente integración con memory-recall.
4. **SE-033** BERTopic — probe ya merged (#650), pendiente skill con corpus real.
5. **SE-028** Oumi — probe (#652 en vuelo), pendiente training pipeline integration.
6. **SE-041** Memvid — probe (#652 en vuelo), pendiente backup memory workflow.

**Justificación del orden**: SE-061 impacta agentes que la usuaria invoca activamente. Los demás son probes cuyos casos de uso reales aún no empujan (training pipeline sin GPU, clustering sin demanda concreta). Ver `output/research/scrapling-20260421.md` §Reprorización.

### Tier 7 refresh (sin cambios post-Era 182)

Sigue: SPEC-102/103/104 PDF · SPEC-107 · SPEC-100 GAIA · SPEC-SE-003/004/009/010/014 · SE-042.

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
