# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-03-22 | **Version:** v3.30.0 | **496 commands · 46 agents · 82 skills · 23 hooks**

Status: **Done** · **In progress** · **Planned** · **Proposed**

---

## Done — Eras 1-118 (v0.1.0 → v3.3.0)

PM core, 16 language packs, context engineering, security (SAST/SBOM), Savia
persona, Company Savia (RSA-4096), Travel Mode, Savia Flow, Git Persistence,
Savia School, accessibility (N-CAPS), adversarial security, Visual QA, dev
sessions. Mobile v0.1 (157 tests). Web Phases 1-3 (228+150 tests). Digest Suite.

---

## Done — Eras 119-124: SaviaClaw (v3.19.0 → v3.24.0)

ESP32 + MicroPython + host daemon. Firmware v0.7 (LCD, serial I/O, 6 commands).
Brain bridge (`claude -p`), heartbeat, selftest, daemon (auto-reconnect,
systemd, guardrails), voice pipeline (TTS+STT, offline-first). 39 tests.

---

## Done — Eras 125-128: Memory Intelligence (v3.25.0 → v3.30.0)

### Era 125 — Context Intelligence Tier 1-2 (v3.25)

SPEC-012 complete (82/82 L1 skill summaries), SPEC-015 context gate,
push-pr.sh automation, PR signing protocol.

### Era 126 — Engram Patterns (v3.27-v3.28)

Inspired by Gentleman-Programming/engram: What/Why/Where/Learned structured
observations, topic key families (decision/*, bug/*, architecture/*),
session summaries, suggest-topic command. 16 BATS tests.

### Era 127 — Vector Memory Index (v3.29)

SPEC-018: semantic search over plain-text JSONL. sentence-transformers
(all-MiniLM-L6-v2, 22MB) + hnswlib. Recall@5: grep 40% → vector 90%.
Auto-rebuild on JSONL changes. Graceful degradation (3 levels).
Zero vendor lock-in, offline-compatible.

### Era 128 — Readiness Check (v3.30)

50-point deterministic capability checklist. Runs post-update automatically.
session-init detects stale stamp after git pull. Auto-adaptation for all
Savia instances.

---

## In Progress

### Memory Quality (SPEC-019, SPEC-020) — active

SPEC-019: Contradiction resolution on upsert (supersedes field).
SPEC-020: TTL/expiration for temporal memories.

### Hardware + Trust (SPEC-021) — active

Hardware checks in readiness-check.sh (RAM, disk, CPU).
Zero telemetry declaration in README.
Connectivity test in sovereignty-ops.sh.

### SaviaClaw — Fase 2: Voice (paused for memory sprint)

Voice module scaffolded. Pending: hardware test with mic + speaker,
wake word detection, voice-console protocol, LCD sync during voice.

### Savia Web — Phase 4: Git Manager (paused)

Visual Git Manager (3 sub-phases: viewer → staging → advanced).
Paused pending SaviaClaw stabilization.

### Savia Mobile v0.2 — Full PM (paused)

Auto-updater, project selector, dashboard widgets, command palette, kanban.

---

## Planned — Q2 2026

### P1. SaviaClaw Fase 3: Sensors (Score 4.95)

BME280 (temp/humidity/pressure), light sensor, autonomous alerts,
time-series logging, sensor dashboard. Requires: BME280 module.

### P2. Savia Web Git Manager (Score 4.90)

3 sub-phases in 3 weeks. Core differentiator.
Spec: `projects/savia-web/specs/roadmap-git-manager.md`

### P3. Web Test Regression + Coverage (Score 4.70)

Cover E2E gaps, mandatory screenshots, coverage >= 80%.

### P4. Power Features CLI (Score 4.60)

Autonomous Budget Guard, Semantic Compact Filter, PM Keybindings,
PR Context Loader.

### P5. Web Notifications RT + Dashboard Real (Score 4.30)

Generic SSE, notification store, real-data dashboard, role widgets.

### P6. Web Approvals + Code Review (Score 4.10)

PRs with diffs, approve/reject, bidirectional approval <> backlog.

---

## Planned — Q3 2026

- **P7.** SaviaClaw Actuators + Autonomy (4.80) — servo, e-stop, BT, OTA
- **P8.** Context Engineering Audit (4.50) — prune dormant rules
- **P9.** SaviaClaw Meeting Collaboration (4.15) — diarization, voice enrollment
- **P10.** Supervisor Agent (3.80) — monitor agents, detect stalls
- **P11.** Competence Model (3.75) — SPEC-014 Phase 2 done, extend
- **P12.** Mobile Responsive + PWA (3.70)

---

## Proposed — Q4 2026+

- **Savia LLM Trainer** (4.90) — Entrenar LLM especializado propio para gestion de contexto empresarial. Claude hace el trabajo bruto, LLM local gestiona memoria, perfiles, routing. Fases: (1) dataset generation desde pm-workspace, (2) fine-tune modelo pequeno (Mistral/Llama 7B), (3) eval framework, (4) integration como "context brain" local. Zero vendor lock-in. SPEC pendiente.
- Extended Time Horizon (multi-day autonomous) — 3.75
- ~~Semantic Memory~~ → DONE (SPEC-018, v3.29.0)
- Plugin Marketplace (community registry + sandbox) — 3.55
- Multi-Claw (mesh of ESP32 nodes) — 3.50
- ~~Multilingualism (FR/IT/PT/DE/GL/EU/CA)~~ → DONE (v3.33.0, 7 README translations)
- **Chinese (ZH) compatibility study** (3.60) — CJK tokenization, bidirectional text, font rendering, encoding. Requires: test corpus, native speaker review. SPEC pendiente.
- SSO/LDAP via OIDC (Keycloak FOSS) — 3.35

---

## Rejected

- Google Sheets/Drive as data store (violates Git-as-truth)
- ServiceNow/SAP/Salesforce connectors (proprietary SDKs)
- Tableau/Power BI integration (CSV export, user chooses tool)
- Kafka/EventBridge streaming (over-engineering)
- VS Code extension (Anthropic shipped official)
- Cloud-only voice (violates offline-first principle)

---

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow alignment 10%

## Sources: Eras 1-118 absorbed · SaviaClaw `zeroclaw/ROADMAP.md` · Web `projects/savia-web/ROADMAP.md` · Engram · Supermemory · Project Nomad · GitHub Issues
