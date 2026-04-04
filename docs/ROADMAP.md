# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-04-04 | **Version:** v4.10.0 | **508 commands · 48 agents · 89 skills · 48 hooks · 93 test suites · 73 SPECs (45 done)**

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

## Pipeline — Q2 2026 (Eras 180+)

### P1. Granular Permissions — MEDIUM

5-level permissions per agent. Integrate with agent-policies.yaml.
- Effort: 8h | Impact: Medium

### P2. Test Coverage Push — MEDIUM

Tests for 30 MEDIUM risk scripts. Target: 20% coverage (up from 11%).
- Effort: 15h | Impact: Medium (maintainability)

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
