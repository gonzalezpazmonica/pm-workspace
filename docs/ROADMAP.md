# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-04-03 | **Version:** v4.3.0 | **505 commands · 49 agents · 85 skills · 33 hooks · 47 test suites · 73 SPECs (45 done)**

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

---

## Pipeline — Q2 2026 (Eras 174+)

### P1. Communication & Adoption (Era 174) — HIGH

README beneficios-first, onboarding aha <5min, CHANGELOG engagement format. Reduce barrier to first successful session. No code — pure docs + UX.
- Effort: 6h | Impact: High (visibility, adoption, community)
- Source: marketingskills research (Era 176 plan)

### P2. SPEC Hygiene — MEDIUM

Clean up 7 duplicate SPEC numbers (029, 030, 031, 032, 033, 041). Archive superseded versions. Update cross-references. Rename to avoid collisions.
- Effort: 3h | Impact: Medium (reduces confusion, improves traceability)
- Source: this audit

### P3. Prompt Security (SPEC-072) — HIGH

Static analyzer for prompt injection/leakage in agent prompts. Integrate with pre-commit.
- Effort: 6h | Impact: High (security)
- Source: pCompiler research

### P4. Auto-Evals — MEDIUM

llm_judge for generated specs. Semantic similarity for code review consistency. Regression detection.
- Effort: 8h | Impact: Medium (quality assurance)
- Source: pCompiler research, DeepEval

### P5. Consolidation & Test Push — MEDIUM

Test coverage audit, dependency graph (SPEC-145), dormant rules cleanup.
- Effort: 4h | Impact: Medium (maintainability)

### P6. Granular Permissions — LOW

5-level permissions per agent. Integrate with agent-policies.yaml.
- Effort: 8h | Impact: Medium (but no blocking need today)
- Source: claw-code research

### Backlog (blocked or low priority)

| Item | Blocker | Priority |
|------|---------|----------|
| Gemma 4 evaluation | Research needed | HIGH — Apache 2.0, multiple sizes. Candidates: Mobile, Shield, Emergency Mode |
| SaviaClaw Sensors | BME280 hardware | High when unblocked |
| SaviaClaw Actuators | Hardware | High when unblocked |
| SaviaClaw Voice v3 | Jabra mic | Medium |
| SaviaClaw Meeting | Voice v3 | Low |
| Web Git Manager | Spec exists, paused | Medium |
| Web Test Coverage | Paused | Low |
| Web Notifications RT | Paused | Low |
| SaviaDivergent Phase 2 | User feedback needed | Medium |
| Emergency LLM SPEC-066 | 24GB+ VRAM — evaluate Gemma 4 | Low→Medium |
| SPEC-032 Security Benchmarks | — | Low |
| SPEC-042 Live Progress | — | Low |
| SPEC-046 Visual Diff QA | — | Low |

## Proposed — Q3-Q4 2026

### Tier 3: Interoperabilidad
- Savia LLM Trainer Phases 2-4 (SPEC-023) · A2A Protocol · Serena MCP · Extended Time Horizon

### Tier 4: Autonomia Calibrada
- Semantic guardrails · Security Sandbox · Self-improvement medible · Plugin Marketplace · Multi-Claw · SSO/LDAP

---

## SPECs — Status Summary (73 total)

| Status | Count | Key examples |
|--------|-------|-------------|
| Implemented | 45 | 012-016, 034-055, 063, 065, 067-069, 071 |
| Ready | 7 | 019, 020, 021, 022, 024, 026, 028 |
| Draft | 14 | 003-009, 017, 042, 046, 056-059 |
| Proposed | 5 | 060-062, 064, 066 |
| Research | 2 | 023, 027 |
| Obsolete | 10 | 025, 058, 064, 138-144 |

**Duplicate SPEC numbers to clean:** 029(2), 030(2), 031(2), 032(2), 033(2), 041(2)

## Rejected

Google Sheets · ServiceNow/SAP · Tableau · Kafka · VS Code ext · Cloud voice · SQLite memory · Multi-provider AI (jato) · Heavy infra RAG (RAGFlow) · Opaque memory DBs (sovereignty lost)

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow 10%
