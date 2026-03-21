# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-03-21 | **Version:** v3.24.0 | **400+ commands · 44 agents · 79 skills · 17 hooks**

Status: **Done** · **In progress** · **Planned** · **Proposed**

---

## Done — Eras 1-118 (v0.1.0 → v3.3.0)

### Foundation → Enterprise (Eras 1-52)

PM core, 16 language packs, context engineering (58% reduction), engram memory,
security (SAST/SBOM), Savia persona, profiles, vertical detection, role-specific
routines, Company Savia (RSA-4096), Travel Mode (AES-256), Savia Flow (17 cmds),
Git Persistence Engine, Savia School, DX metrics, accessibility (N-CAPS),
adversarial security (Red/Blue/Auditor), Visual QA, dev sessions (5-phase).

### Mobile + Web (Eras 53-87)

Savia Mobile v0.1 (Kotlin/Compose, 157 tests). Savia Web Phases 1-3: dashboard,
backlog (Spec>PBI>Task), file browser, i18n, pipelines, n8n, multi-user auth,
chat with SSE, session management. 228 unit + 150 E2E tests.

### Quality + Intelligence (Eras 88-118)

BATS (84 tests), weighted coverage (65%), security hardening, lazy loading,
sync adapters, autonomous pipeline engine, radical honesty (Rule #24),
digest traceability, visual-digest (4-pass OCR), meeting-digest Phase 4.
Document Digest Suite (PDF/Word/Excel/PPTX). Open-source research improvements.

---

## Done — Eras 119-123: SaviaClaw (v3.19.0 → v3.24.0)

Savia in the physical world. ESP32 + MicroPython + host daemon.

### Era 119-120 — Hardware Foundation (v3.19-v3.20)

ZeroClaw firmware v0.7: LCD 16x2 I2C, select.poll() serial I/O, 6 commands
(ping, info, led, lcd, sensors, gpio, help). Hardware-verified on real ESP32.
LCD overwrite bug fixed. First message: "Soy Savia | Vivo en ZeroClaw".

### Era 121 — Brain Bridge (v3.21)

`savia_brain.py`: ESP32 asks → `claude -p` (with pm-workspace context) → LCD.
CI signature fix for confidentiality gate.

### Era 122 — Autonomy Roadmap + Heartbeat (v3.22)

Heartbeat module (LCD status rotation: identity, uptime, WiFi, RAM).
BT audio research: HFP AG for bidirectional voice via BT headset.
6-level autonomy roadmap spec.

### Era 123 — Selftest + Daemon (v3.23)

Hardware selftest at boot (CPU, RAM, LED, LCD, WiFi, flash).
`saviaclaw_daemon.py`: background process, auto-reconnect, systemd service.
7 deterministic guardrails (size, rate, PII, storage, command, cleanup, audit).

### Era 124 — Stability + Voice + Roadmap (v3.24)

Daemon refactored: signal handling, status file, stuck detection (120s),
RotatingFileHandler, split into daemon + daemon_util (both under 150 lines).
Voice pipeline: TTS (espeak-ng/spd-say) + STT (whisper), offline-first.
39 tests without hardware. ROADMAP.md with 6 phases.

---

## In Progress

### SaviaClaw — Fase 2: Voice (active focus)

Voice module scaffolded. Pending: hardware test with mic + speaker,
wake word detection, voice-console protocol, LCD sync during voice.
See: `zeroclaw/ROADMAP.md`

### Savia Web — Phase 4: Git Manager (paused)

Visual Git Manager (3 sub-phases: viewer → staging → advanced).
SVG commit graph, diff viewer, staging area, branch CRUD, merge, blame.
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

### P7. SaviaClaw Fase 4-5: Actuators + Autonomy (Score 4.80)

Servo control with safety (ROB-01 to ROB-10), e-stop, Behavior Trees,
OTA firmware with signature, offline mode. Requires: servo + e-stop hardware.

### P8. Context Engineering Audit (Score 4.50)

Audit @ references, prune auto-generated skills, reduce dormant rules.

### P9. SaviaClaw Fase 6: Meeting Collaboration (Score 4.15)

Full meeting mode: transcription + diarization + digest. Voice enrollment
(RGPD-compliant). Proactive participation in silence windows.

### P10. Supervisor Agent (Score 3.80)

Monitor other agents, detect stalls >30min, reassign, generate summary.

### P11. Competence Model (Score 3.75)

Per-person skill tracking. Optimal assignment by competence + growth.

### P12. Mobile Responsive + PWA (Score 3.70)

Responsive breakpoints, PWA manifest, touch-friendly kanban/graph.

---

## Proposed — Q4 2026+

- Extended Time Horizon (multi-day autonomous) — 3.75
- Semantic Memory (sqlite-vec + sentence-transformers, FOSS) — 3.60
- Plugin Marketplace (community registry + sandbox) — 3.55
- Multi-Claw (mesh of ESP32 nodes) — 3.50
- Multilingualism (FR/IT/PT/DE/ZH) — 3.50
- SSO/LDAP via OIDC (Keycloak FOSS) — 3.35
- Rust Runtime for Hooks (only if >500ms bottleneck) — 3.25

---

## Rejected

- Google Sheets/Drive as data store (violates Git-as-truth)
- ServiceNow/SAP/Salesforce connectors (proprietary SDKs)
- Tableau/Power BI integration (CSV export, user chooses tool)
- Kafka/EventBridge streaming (over-engineering)
- VS Code extension (Anthropic shipped official)
- Cloud-only voice (violates offline-first principle)

---

## Scoring (5 dimensions, 1-5 each)

- **PM Impact** (30%) — improves real project management?
- **Anti lock-in** (25%) — works offline/standalone? No vendor dependency?
- **FOSS** (20%) — uses/generates free software?
- **Inverse complexity** (15%) — 5=trivial, 1=months
- **Savia Flow alignment** (10%) — fits 6 principles

---

## Sources consolidated

- Eras 1-118: previous roadmap entries absorbed
- SaviaClaw: `zeroclaw/ROADMAP.md` (hardware-specific phases)
- Savia Web: `projects/savia-web/ROADMAP.md` → P2 integrated here
- Community votes via GitHub Issues
