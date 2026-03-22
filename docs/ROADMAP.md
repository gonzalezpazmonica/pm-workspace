# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-03-22 | **Version:** v3.33.0 | **496 commands · 46 agents · 82 skills · 23 hooks**

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

## Done — Eras 125-130: Memory Intelligence + i18n (v3.25.0 → v3.33.0)

- **Era 125** (v3.25): SPEC-012/015 complete, push-pr.sh, PR signing protocol
- **Era 126** (v3.27-28): Engram patterns (W/W/W/L, topic keys, session summary)
- **Era 127** (v3.29): SPEC-018 vector memory (Recall 40%→90%, hnswlib)
- **Era 128** (v3.30): Readiness check (50 points, auto post-update)
- **Era 129** (v3.31-32): SPEC-019/020/021 done. memory-store split (3 modules)
- **Era 130** (v3.33): 7 README translations (gl/eu/ca/fr/de/pt/it). 9 languages.

---

## In Progress

### SPEC-024: Doc Audit — Savia en primera persona

Reescribir docs publicos con voz de Savia. READMEs ya hechos.

### SaviaClaw Voice (paused — needs Jabra hardware test)

### Savia Web Phase 4 / Mobile v0.2 (paused)

---

## Planned — Q2 2026 (por score + implementabilidad)

### P1. SPEC-022: Power Features CLI (4.60) — SPEC READY

Budget Guard, Semantic Compact, PM Keybindings, PR Context Loader.

### P2. Web Git Manager (4.90) — SPEC EXISTS

3 sub-phases. `projects/savia-web/specs/roadmap-git-manager.md`

### P3. Web Test Coverage (4.70) — needs SPEC

E2E gaps, screenshots, coverage >= 80%.

### P4. SaviaClaw Sensors (4.95) — BLOCKED: needs BME280

### P5. Web Notifications RT (4.30) · P6. Web Approvals (4.10)

---

## Planned — Q3 2026

- **P7.** SaviaClaw Actuators + Autonomy (4.80) — needs hardware
- **P8.** Context Engineering Audit (4.50) — prune dormant rules
- **P9.** SaviaClaw Meeting Collaboration (4.15)
- **P10.** Supervisor Agent (3.80) · **P11.** Competence extend (3.75)
- **P12.** Mobile PWA (3.70)

---

## Proposed — Q4 2026+

- **SPEC-023: Savia LLM Trainer** (4.90) — local context brain. 4 phases: dataset → QLoRA → eval → integration. Zero vendor lock-in.
- Extended Time Horizon (multi-day autonomous) — 3.75
- **SPEC-025: Chinese (ZH)** (3.60) — CJK tokenization, cultural adaptation
- Plugin Marketplace — 3.55 · Multi-Claw — 3.50 · SSO/LDAP — 3.35
- ~~Semantic Memory~~ DONE v3.29 · ~~Multilingualism EU~~ DONE v3.33

---

## Rejected

Google Sheets (violates Git-truth) · ServiceNow/SAP (proprietary) · Tableau (CSV export) · Kafka (over-eng) · VS Code ext (Anthropic shipped) · Cloud voice (offline-first) · SQLite memory (text plain portable)

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow 10%

## Sources: Eras 1-130 · SaviaClaw · Web · Engram · Supermemory · Nomad
