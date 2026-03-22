# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-03-22 | **Version:** v3.38.0 | **496 commands · 46 agents · 82 skills · 25 hooks**

Status: **Done** · **In progress** · **Planned** · **Proposed**

---

## Done — Eras 1-118 (v0.1.0 → v3.3.0)

PM core, 16 language packs, context engineering, security, Savia persona,
Company Savia, Travel Mode, Savia Flow, Git Persistence, Savia School,
accessibility, adversarial security, Visual QA, dev sessions. Mobile v0.1.
Web Phases 1-3. Digest Suite.

## Done — Eras 119-124: SaviaClaw (v3.19.0 → v3.24.0)

ESP32 + MicroPython + host daemon. Voice pipeline (TTS+STT, offline). 39 tests.

## Done — Eras 125-133: Memory Intelligence + i18n + Community (v3.25→v3.38)

- **Era 125** (v3.25): SPEC-012/015 complete, push-pr.sh, PR signing
- **Era 126** (v3.27-28): Engram patterns (W/W/W/L, topic keys, session summary)
- **Era 127** (v3.29): SPEC-018 vector memory (Recall 40%→90%)
- **Era 128** (v3.30): Readiness check (50+ points, auto post-update)
- **Era 129** (v3.31-32): SPEC-019/020/021 (contradiction, TTL, hardware). Split memory-store
- **Era 130** (v3.33): 7 README translations. 9 languages total
- **Era 131** (v3.34): SPEC-022/023/024/025 specs. Roadmap sync. Galego fixed
- **Era 132** (v3.35-37): Budget Guard, PM Keybindings, CONTRIBUTING+SECURITY in Savia voice, training data generator (1542 pairs)
- **Era 133** (v3.38): SPEC-026/027/028 specs. PreCompact hook, PostToolUseFailure hook, reranker. 7 community repos analyzed

---

## In Progress

### SPEC-027: Graph Memory Layer — Fase 1 (active)

Entity-relation extraction over JSONL with regex+heuristics.
Dual retrieval: vector + graph. Inspired by LightRAG.

### SPEC-022 F2+F4 (remaining Power Features)

Semantic Compact Filter + PR Context Loader.

### SaviaClaw Voice (paused — needs Jabra hardware)

### Savia Web Phase 4 / Mobile v0.2 (paused)

---

## Planned — Q2 2026

- **P1.** Web Git Manager (4.90) — 3 sub-phases, spec exists
- **P2.** Web Test Coverage (4.70) — E2E gaps, screenshots, >=80%
- **P3.** SaviaClaw Sensors (4.95) — BLOCKED: needs BME280
- **P4.** Web Notifications RT (4.30) · **P5.** Web Approvals (4.10)

---

## Planned — Q3 2026

- **P6.** SaviaClaw Actuators + Autonomy (4.80) — needs hardware
- **P7.** Context Engineering Audit (4.50) — prune dormant rules
- **P8.** SaviaClaw Meeting Collaboration (4.15)
- **P9.** Supervisor Agent (3.80) · **P10.** Competence extend (3.75)
- **P11.** Mobile PWA (3.70)

---

## Proposed — Q4 2026+

- **SPEC-023 Fases 2-4: Savia LLM Trainer** (4.90) — QLoRA fine-tune → eval → integration. Fase 1 (dataset) DONE.
- Extended Time Horizon (multi-day autonomous) — 3.75
- **SPEC-025: Chinese (ZH)** (3.60) — CJK, cultural adaptation
- Plugin Marketplace — 3.55 · Multi-Claw — 3.50 · SSO/LDAP — 3.35

---

## Rejected

Google Sheets · ServiceNow/SAP · Tableau · Kafka · VS Code ext · Cloud voice · SQLite memory

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow 10%

## Sources: Eras 1-133 · SaviaClaw · Web · Engram · Supermemory · Nomad · LightRAG · Hooks Mastery · n8n-MCP
