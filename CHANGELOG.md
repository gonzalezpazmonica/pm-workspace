# Changelog — pm-workspace

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.18.0] — 2026-03-21

Savia as active meeting participant — etiquette protocol, context guardian, speaker role permissions.

### Added

- **Rule**: `meeting-participant-etiquette.md` — 4 simultaneous roles (transcriber, context guardian, query responder, proactive participant). 5-condition window for proactive speech. 3 configurable modes (silent, query, active). Post-meeting output: transcript, digest, action items, contradictions, risks, unanswered questions
- **Script**: `meeting_participant.py` — opportunity window detector (3s silence + no pending turn + critical info + not already said + PM allows). Max interventions limit, cooldown timer, mode switching, internal note buffer
- **Script**: `context_guardian.py` — cross-references live speech against decision log, business rules, sprint state. Detects: action items (commitment language), contradictions with prior decisions, risk mentions, unanswered questions
- **Script**: `speaker_roles.py` — deterministic role-based access control in CODE. 5 levels: external → observer → developer → tech_lead → pm. Topic filter gate: `filter_response()` strips unauthorized data BEFORE voice output. NEVER_VOICE set blocks biometric, salary, credentials, PII from voice output for ALL roles including PM
- **Tests**: `test_meeting_participant.py` (12 tests) + `test_speaker_roles.py` (10 tests)

### Security design

- Speaker permissions enforced by Python `filter_response()` function, not LLM instruction
- NEVER_VOICE topics (evaluations, salary, credentials, PII, voiceprints) blocked for ALL roles in voice output — PM accesses these via console only
- Unknown speakers default to "observer" (minimal access)
- Context integrity: Savia ANNOTATES contradictions but does NOT override or modify project data based on meeting requests

## [3.17.0] — 2026-03-21

ZeroClaw meeting digest — speaker diarization + voice fingerprinting.

### Added

- **Spec**: `SPEC-008-zeroclaw-meeting-digest.md` — live meeting pipeline: audio capture → VAD → pyannote diarization → SpeechBrain voice ID → whisper STT → JSONL transcript with speaker labels → meeting-digest agent
- **Script**: `voiceprint.py` — voice enrollment: extract ECAPA-TDNN embedding from 10-15s speech, store as numpy array in ~/.savia/zeroclaw/voiceprints/ (N4b biometric)
- **Script**: `voiceprint_ops.py` — identify speaker from embedding (cosine similarity), list/delete voiceprints (RGPD Art. 17 right to erasure)
- **Script**: `meeting_pipeline.py` — orchestrator: process audio buffer through diarization → speaker ID → STT, output JSONL transcript, graceful fallback for each missing dep
- **Rule**: `zeroclaw-meeting-protocol.md` — consent guardrails (audible warning mandatory), voice enrollment flow, confidence thresholds (75%/50%), RGPD compliance, degradation matrix
- **Command**: `/zeroclaw meeting` — start, stop, voice enroll/list/delete, status subcommands
- **Tests**: `test_voiceprint.py` — 9 tests: cosine similarity math, index operations, N4b storage location, threshold values, file sizes

## [3.16.0] — 2026-03-21

ZeroClaw network auto-config — Savia detects its WiFi and provisions ESP32 to join.

### Added

- **Script**: `network_setup.py` — cross-platform (Linux/macOS/Windows) detection of host WiFi SSID and IP address via nmcli/iwgetid/airport/netsh/ipconfig
- **Script**: `esp32_wifi.py` — ESP32 WiFi operations via mpremote: scan networks, verify connection, deploy config, reset device
- **Script**: `network_cli.py` — interactive wizard: detects host network → asks password → deploys config → resets ESP32 → verifies same-subnet connectivity
- **Script**: `connectivity_test.py` — end-to-end test: USB serial + WiFi ping + HTTP endpoint verification
- **Firmware**: `wifi_server.py` — minimal HTTP server on ESP32 (GET /ping, POST /cmd, GET /status) for wireless command execution
- **Firmware**: `main.py` upgraded to v0.2.0 — dual-mode: serial USB AND WiFi HTTP simultaneously, auto-starts HTTP if WiFi connected
- **Command**: `/zeroclaw network` — setup, check, scan subcommands
- **Tests**: `test_network.py` — 8 tests (SSID detection, IP detection, config structure, no secrets, dual-mode firmware)

## [3.15.0] — 2026-03-21

ZeroClaw sensory protocol + deterministic guardrails — no agent can bypass.

### Added

- **Rule**: `zeroclaw-sensory-protocol.md` — ingestion pipeline (classify → transcribe → filter → digest → persist → discard raw), confidentiality alignment with N1-N4b, RGPD compliance for biometric data, session storage structure, retention policies
- **Script**: `guardrails.py` — 7 deterministic security gates in Python code: size limits (5MB audio, 2MB image), rate limiting (5 audio/min), command allowlist, master validator `validate_incoming()` that ALL data must pass
- **Script**: `guardrails_pii.py` — PII detection (DNI, IBAN, phone, email, card), raw data auto-expiry (1h), storage quota (100MB), immutable audit log (append-only JSONL)
- **Tests**: `test_guardrails.py` — 14 tests proving gates block oversized data, flooding, unknown commands, PII, full storage. Tests pass without hardware

### Security design

- Gates are Python functions, not LLM instructions — deterministic, untrickable
- Command allowlist: only 12 known commands pass (ping, led, info, sensors, gpio, help, capture_image, capture_audio, speak, set_led, play_tone, status)
- Immutable audit log: every incoming datum logged before processing
- Raw data (audio/images) auto-deleted after 1 hour

## [3.14.0] — 2026-03-21

ZeroClaw Firmware v0.1 — ready to flash when ESP32 is connected.

### Added

- **Firmware**: `zeroclaw/firmware/` — MicroPython firmware for ESP32: boot.py (WiFi + CPU config), main.py (JSON command loop with watchdog), lib/commands.py (ping, led, info, sensors, gpio), lib/status.py (LED patterns for feedback)
- **Host**: `zeroclaw/host/bridge.py` — serial bridge PC↔ESP32: auto-detect port, JSON protocol, timeout handling
- **Host**: `zeroclaw/host/cli.py` — self-test (5 checks), interactive mode, CLI entry point
- **Setup**: `zeroclaw/setup.sh` — one-command setup: installs esptool+mpremote, detects ESP32, flashes MicroPython, deploys firmware, verifies with LED blink
- **Command**: `/zeroclaw` — setup, test, ping, led, flash, interactive subcommands
- **Tests**: `zeroclaw/tests/test_bridge.py` — 9 tests that run without hardware (imports, protocol, firmware structure, security, sizes)

## [3.13.0] — 2026-03-21

ZeroClaw voice pipeline + voice/console decision protocol.

### Added

- **Spec**: `SPEC-007-zeroclaw-voice-pipeline.md` — full bidirectional voice architecture: 3 processing levels (ESP32 wake word → Host STT/TTS → optional cloud), Wyoming-adapted protocol, latency target ~6s, 5-phase implementation plan
- **Rule**: `voice-console-protocol.md` — decision algorithm for what goes to voice (short instructions, safety warnings) vs console (code, tables, diagrams). 4 session modes: assembly, coding, monitoring, chat. LED indicator states for ZeroClaw
- **Script**: `voice_bridge.py` — host-side voice server: faster-whisper STT + pyttsx3/Piper TTS, dependency detection, setup guide. Graceful fallback when deps missing

### Research (incorporated in specs)

- ESP-SR WakeNet/MultiNet for on-device wake word on ESP32-S3
- whisper.cpp for edge STT (~273MB RAM for tiny model)
- Piper TTS for fast local Spanish voice synthesis
- Wyoming protocol (Rhasspy/Home Assistant) for audio streaming
- HuggingFace speech-to-speech pipeline architecture (VAD→STT→LLM→TTS)

## [3.12.0] — 2026-03-21

Physical assembly guidance + ZeroClaw spec — Savia guides hardware and gains physical senses.

### Added

- **Spec**: `SPEC-005-physical-assembly-guide.md` — 3 guidance modes (ASCII diagrams, step-by-step manuals, offline TTS voice), component knowledge base (9 components with safety warnings), schemdraw SVG generation
- **Spec**: `SPEC-006-zeroclaw.md` — ESP32-S3 as Savia's physical interface: microphone (INMP441), speaker (MAX98357A), camera (OV2640). Protocol design, security model, 5-phase implementation plan
- **Script**: `pinout.py` — ASCII pinout generator for ESP32/Arduino/RPi Pico with connection annotations and wire colors
- **Script**: `assembly_guide.py` — Step-by-step assembly guide generator with BOM, wiring steps, verification checklists, and per-component safety warnings
- **Script**: `voice_guide.py` — Offline TTS voice narrator (pyttsx3) with interactive controls (next/repeat/back/status), ES/EN support

## [3.11.0] — 2026-03-21

Robotics Vertical — architecture, security, and MicroPython for the physical AI era.

### Added

- **Spec**: `SPEC-004-robotics-vertical.md` — full 5-layer robotics stack (AI → ROS2 → Edge → MCU → Hardware), STRIDE threat model for robotics, language packs, agent proposals, ESP32 lab integration plan
- **Rule**: `robotics-safety.md` — 10 immutable safety principles + 5 REJECT rules (watchdog, actuator limits, auth, OTA signing, sensor redundancy)
- **Language Pack**: `micropython-conventions.md` — auto-loads on boot.py/main.py, patterns for sensor reading, actuator control, async with watchdog
- **Docs ES**: `docs/robotics-roadmap.md` — 5-phase roadmap from ESP32 to LeRobot
- **Docs EN**: `docs/robotics-roadmap.en.md` — English version

## [3.10.1] — 2026-03-21

Web Research: tests, documentation (ES/EN), and skill registration.

### Added

- **Tests**: `tests/test-web-research.bats` — 22 BATS tests covering cache, sanitizer, reranker, formatter, gap detector, suggestions, SearxNG, and CLI
- **Docs ES**: `docs/web-research.md` — full documentation in Spanish
- **Docs EN**: `docs/web-research.en.md` — full documentation in English
- **Skill**: `web-research` registered with SKILL.md + DOMAIN.md (Clara Philosophy)

## [3.10.0] — 2026-03-21

FAIR-Perplexica improvements: autonomous SearxNG, gap detection, global context, follow-up suggestions.

### Added

- **Script**: `searxng.py` — SearxNG Docker auto-start: detects Docker, starts container `savia-searxng` on demand, health check, graceful fallback to WebSearch
- **Script**: `docker-compose.searxng.yml` — SearxNG container definition (port 8888, localhost only, no tracking)
- **Script**: `search.py` — 3-layer search orchestrator: cache → SearxNG (auto-start) → Claude WebSearch
- **Script**: `gap_detector.py` — detects context gaps in user queries (versions, docs, CVEs, comparisons) vs internal PM questions
- **Script**: `suggestions.py` — post-command follow-up suggestions for 10 command families (inspired by Perplexica suggestion generator)
- **Rule**: `global-context.md` — compact company DNA (~100 tokens) injected into all agent prompts, saves ~360 tokens vs full profile
- **Script**: `generate-global-context.sh` — generates global context from company profile + config

### Changed

- **Command**: `/web-research` — now auto-starts SearxNG Docker, 3-layer search with engine presets by category

## [3.9.0] — 2026-03-21

Savia Web Research — web search to resolve context gaps. Inspired by FAIR-Perplexica (UB-Mannheim).

### Added

- **Skill**: `web-research` — search engine with local cache, query sanitization, heuristic reranking, and inline citations `[web:N]`
- **Command**: `/web-research <query>` — search the web for documentation, versions, CVEs, best practices. Subcommands: `--cache-stats`, `--cache-clear`, `--cache-only`
- **Rule**: `web-research-config.md` — configuration, privacy protocol, context-budget integration, degradation levels
- **Spec**: `SPEC-003-web-research-system.md` — full architecture proposal (3 layers: cache → Claude tools → SearxNG)
- **Script**: `scripts/web-research/` — Python package: cache (LRU, TTL by category), sanitizer (PII/project removal), reranker (heuristic scoring), formatter (citation generation)

## [3.8.1] — 2026-03-21

Native markdownlint — replaces npm markdownlint-cli dependency.

### Added

- **Script**: `scripts/markdownlint/` — Python3 native markdownlint (17 rules, zero npm dependency, `--fix` mode)
- **Script**: `scripts/markdownlint.sh` — CLI wrapper

### Changed

- **CI**: `ci.yml` lint-markdown job uses native linter instead of npm `markdownlint-cli`
- **CI**: `validate-ci-local.sh` — added markdown lint check for CHANGELOG.md

### Fixed

- **CHANGELOG.md**: Fixed 259 markdownlint errors (MD012, MD022, MD032, MD053) from v3.7.0 base rebuild

## [3.8.0] — 2026-03-21

Feasibility Probe and Model Upgrade Audit — inspired by Cat Wu's "Product management on the AI exponential" (Anthropic, March 2026).

### Added

- **Agent**: `feasibility-probe` — time-boxed prototype attempt on a spec, produces viability report with score 0-100, blocking sections, and decomposition suggestions
- **Agent**: `model-upgrade-auditor` — audits agents/skills/rules for prompt debt (emphatic repetitions, defensive parsing, coded retries) that newer models may not need
- **Skill**: `feasibility-probe` (SKILL.md + DOMAIN.md) — decision checklist, scoring formula, SDD integration as optional gate between spec-approve and dev-session
- **Skill**: `model-upgrade-audit` (SKILL.md + DOMAIN.md) — 6 workaround patterns, 3-tier risk classification (APPLY/REVIEW/SKIP), longitudinal tracking
- **Command**: `/feasibility-probe <spec_path>` — validate spec feasibility with budget-constrained prototype
- **Command**: `/model-upgrade-audit [--scope]` — detect prompt debt and propose simplifications

## [3.7.1] — 2026-03-20

Fix update system and auto-release pipeline.

### Fixed

- **update.sh**: compares against `origin/main` instead of GitHub releases — no longer requires `gh` CLI, reads version from CHANGELOG.md
- **update.sh**: uses `git pull origin main` instead of merging a tag that may not exist

### Added

- **auto-tag.yml**: GitHub Actions pipeline that creates git tag automatically when CHANGELOG.md is updated on main, triggering release.yml
- **sync-tags-from-changelog.sh**: one-time script to backfill missing tags from CHANGELOG.md history (138 versions synced)

## [3.7.0] — 2026-03-20

Context optimization, React quality, and decision-guided skills — inspired by rtk-ai/rtk and no-use-effect.

### Added

- **Hook**: `bash-output-compress.sh` — async PostToolUse hook that compresses verbose Bash output (blanks, repeats, ANSI, truncation). Specialized filters for git, dotnet, npm, az devops. Inspired by rtk-ai/rtk (60-90% token reduction)
- **Rule**: `react-use-effect-anti-patterns.md` — 6 rules + 8-question decision checklist for React useEffect. Auto-loads on .tsx/.jsx. Inspired by no-use-effect skill
- **Tracker**: `context-tracker.sh compression-report` — new subcommand for Bash compression metrics
- **Pattern**: Decision Checklists added to 6 core skills (sequential yes/no routing before execution)

### Changed

- **Skill**: `spec-driven-development` — added 5-question decision checklist + abort conditions for human vs agent routing
- **Skill**: `pbi-decomposition` — added 5-question decision checklist + abort conditions for decomposition gates
- **Skill**: `risk-scoring` — added 5-question decision checklist with score modifiers and abort conditions
- **Skill**: `consensus-validation` — added 5-question decision checklist for mandatory vs optional consensus
- **Skill**: `product-discovery` — added 5-question decision checklist for skip/start/delay discovery
- **Skill**: `verification-lattice` — added 5-question decision checklist for layer selection by risk
- **Rule**: `react-conventions.md` — added reference to new useEffect anti-patterns file
- **Config**: `settings.json` — registered bash-output-compress hook as async PostToolUse for Bash
- **Docs**: README.md and README.en.md — hooks count updated from 16 to 17

### Specs

- `SPEC-001`: Bash Output Compression Hook (rtk-inspired)
- `SPEC-002`: React useEffect Anti-Patterns (no-use-effect inspired)
- `SPEC-003`: Decision Checklists for Top 6 Skills

## [3.6.1] — 2026-03-20

PII purge from tracked files + full-repo scan mode.

### Fixed

- **PII**: Removed private project name from 7 tracked files (commands, rules, skills, specs, tests, docs) committed before the confidentiality system existed
- **Scanner**: `confidentiality-scan.sh` `--full-repo` mode scans ALL tracked file contents, not just PR diffs — closes the gap that allowed pre-existing PII to persist undetected
- **Blocklist**: `generate-blocklist.sh` auto-detects public projects from `.gitignore` whitelist to avoid false positives, handles empty arrays in CI
- **CI**: `confidentiality-gate.yml` adds weekly scheduled full-repo audit (Monday 06:00 UTC) + manual dispatch

## [3.6.0] — 2026-03-20

Pre-PR confidentiality audit system with cryptographic signature.

### Added

- **Agent**: `confidentiality-auditor` rewritten — dynamic context-aware audit that reads workspace context (project names, team members, org URLs) to discover sensitive data semantically, not with static patterns
- **Script**: `confidentiality-sign.sh` — HMAC-SHA256 signature generation/verification after clean audit. Signature must be committed with the PR; CI verifies diff hash matches
- **Script**: `generate-blocklist.sh` — dynamic blocklist generator from 6 workspace sources (projects, profiles, teams, local config, email domains, static list)
- **CI**: `confidentiality-gate.yml` — two parallel jobs: signature verification + deterministic scan (defense in depth)
- **Command**: `/confidentiality-check` updated to orchestrate full flow (agent audit + signature + scan)
- **Script**: `confidentiality-scan.sh` — 8-check deterministic scanner with dynamic blocklist support

### Fixed

- **Hook**: `validate-bash-global.sh` — detects target repo from `cd` in command instead of always checking `CLAUDE_PROJECT_DIR` branch. Fixes false "commit on main" blocks when working in sub-repos with their own `.git`

## [3.5.3] — 2026-03-19

Fix: multi-repo branch detection in global bash hook.

### Fixed

- **Hook**: `validate-bash-global.sh` — detects target repo from `cd` in command instead of always checking `CLAUDE_PROJECT_DIR` branch. Fixes false "commit on main" blocks when working in sub-repos with their own `.git`

## [3.5.2] — 2026-03-19

Criticality scoring engine — backing scripts for Era 120 criticality commands.

### Added

- **Script**: `scripts/criticality.sh` — dispatcher for assess/dashboard/rebalance
- **Script**: `scripts/criticality-scoring.sh` — pure scoring (WSJF, confidence decay, urgency boost, 5-dimension model, P0-P3 classification)
- **Script**: `scripts/criticality-engine.sh` — operations (assess single item, dashboard cross-project, rebalance analysis)

## [3.5.1] — 2026-03-19

Backing scripts for vault, confidentiality scanner, and travel sync.

### Added

- **Script**: `scripts/vault.sh` + `scripts/vault-ops.sh` — full implementation of 5 vault operations (init, sync, status, restore, export) with NTFS junction support
- **Script**: `scripts/confidentiality-check.sh` — project-level scanner for N4-SHARED compliance (PII, secrets, cross-level leaks, scoring 0-100)

### Fixed

- **Script**: `scripts/savia-travel.sh` — implemented `sync` command (was stub), includes vault in travel package

## [3.5.0] — 2026-03-19

Personal Vault (N3) + Confidentiality Auditor + 5-level confidentiality documentation.

### Added

- **Personal Vault**: 5 commands (`vault-init`, `vault-sync`, `vault-status`, `vault-restore`, `vault-export`) + skill + config rule for N3 user data in separate git repo
- **Confidentiality Auditor**: Opus agent for multi-repo confidentiality compliance auditing
- **Command**: `/confidentiality-check` — verify level compliance per project
- **Rule**: `personal-vault-config.md` — vault configuration constants
- **Docs**: `docs/confidentiality-levels.md` — full 5-level (N1-N4b) documentation

### Changed

- **Rule**: `context-placement-confirmation.md` — compressed to 150 lines, added N3 vault integration

## [3.4.1] — 2026-03-19

PII sanitization from security audit + Confidentiality Gate CI pipeline.

### Fixed

- **PII**: removed 7 real names, 3 real companies, HR data from tracked files (GDPR)
- **Untracked**: `active-user.md` and `settings.local.json` removed from git index
- **IPs**: replaced hardcoded `192.168.1.x` with `<YOUR_PC_IP>` in savia-mobile-android

### Added

- **Confidentiality Gate**: CI pipeline with 7-check scanner (blocklist, credentials, emails, proper nouns, forbidden files, merge markers, private IPs)
- **Files**: `scripts/confidentiality-scan.sh`, `confidentiality-blocklist.txt`, `confidentiality-allowlist.txt`

## [3.4.0] — 2026-03-19

Era 120 — Task Criticality System + Multi-Tenant Calendar Sync.

### Added

- **Task Criticality**: multi-level prioritization (WSJF, Cost of Delay, RICE, Eisenhower) with 5 scoring dimensions, auto-escalation, and confidence decay
- **Commands**: `/criticality-dashboard`, `/criticality-assess`, `/criticality-rebalance` (3 new)
- **Multi-Tenant Calendar Sync**: `/sync-calendars` — bidirectional free/busy sync between 2 Microsoft 365 tenants with AES-256 encrypted per-user credentials
- **Specs**: `spec-task-criticality.md`, `spec-criticality-frameworks.md` (9 frameworks researched), `spec-multi-tenant-sync.md`, `spec-multi-tenant-security.md`
- **Docs**: Smart Calendar (7 cmds) and Task Criticality (3 cmds) sections in ES+EN

### Changed

- **smart-calendar SKILL.md**: added criticality integration section + sync-calendars reference

## [3.3.0] — 2026-03-19

Era 118 — Five improvements from open-source research (GitNexus, NemoClaw, GSD, Context Hub, Everything Claude Code).

### Added

- **Skill: codebase-map** + **Command: /codebase-map**: Symbol indexing of pm-workspace itself. Scans commands→agents→rules→skills dependency graph. Detects orphaned rules, hub rules, routing chains. Inspired by GitNexus code intelligence engine.
- **Rule: agent-policies.md** + **Command: /policy-check**: Policy-driven agent isolation with per-project YAML policies (allowed/denied paths, approval requirements, timeouts, network restrictions). Audit trail for violations. Inspired by NVIDIA NemoClaw sandbox orchestration.
- **Rule: dev-session-locks.md** + **Command: /dev-session-resume**: Crash recovery for dev-sessions via lock files with PID detection. State machine (pending→implementing→validating→verified→completed). Auto-resume from last checkpoint. Inspired by GSD 2 disk state machine.
- **Skill: doc-quality-feedback** + **Command: /docs-quality-audit**: Agent feedback loop for documentation quality. Agents rate docs after use (clear/confusing/incomplete/outdated). Monthly aggregation flags low-quality docs for rewrite. Inspired by Context Hub agent annotations.
- **Command: /skill-propose** + **Rule: skill-lifecycle.md**: Auto-generate skill scaffolds from repeated workflows (3+ observations). Consensus validation, adoption tracking, archival of unused skills. Inspired by Everything Claude Code continuous learning.

### Changed

- **README.md + README.en.md**: Updated with new commands and skills.
- **12-comandos-agentes.md + 12-commands-agents.md**: Added new command categories.

## [3.2.0] — 2026-03-19

Era 117 — Document Digest Suite: 4 new agents for PDF, Word, Excel, PowerPoint digestion with context-aware 4-phase pipeline.

### Added

- **Agent: pdf-digest** (Opus 4.6): 4-phase pipeline for PDF documents using PyMuPDF for text extraction + Claude Vision for embedded images. Phases: raw extraction → project context loading → analysis/synthesis with cross-referencing → context document update. Supports protocols, manuals, proposals, reports, specs.
- **Agent: word-digest** (Opus 4.6): 4-phase pipeline for DOCX using python-docx. Extracts text with styles, tables, embedded images, metadata. Same 4-phase context-aware architecture.
- **Agent: excel-digest** (Opus 4.6): 4-phase pipeline for XLSX using openpyxl. Extracts structure, formulas (translated to natural language), validations, conditional formatting, macro names. Detects business rules embedded in formulas and anti-patterns.
- **Agent: pptx-digest** (Opus 4.6): 4-phase pipeline for PPTX using python-pptx. Prioritizes presenter notes over slide text. Extracts chart data, images via Vision.

- **Skill: prompt-optimizer** + **Command: /skill-optimize**: AutoResearch Loop for self-optimizing skill and agent prompts. Inspired by Karpathy/Eric Risco pattern. Executes skill with test fixture, scores output against weighted checklist (G-Eval 0-10), modifies prompt, re-executes, compares scores. Keeps changes that improve, reverts those that don't. Stop criterion: score >= 8.0 for 3 consecutive iterations. Output saved as `.optimized.md` — original never modified.

- **Prompt optimizer auto-trigger** (`prompt-optimizer/auto-trigger.md`): Protocol for Savia to automatically suggest `/skill-optimize` when agents accumulate 3+ corrections in last 10 executions. Detects explicit signals (PM corrections, re-executions) and implicit signals (low coherence scores, outputs exceeding limits). Auto-generates test fixtures from real usage patterns.

### Changed

- **agents-catalog.md**: Updated from 39 to 43 agents. Added Document Digest Suite flow.
- **CLAUDE.md**: Agent count updated from 39 to 43.
- **meeting-digest.md**: Phase 4 context update now references README.md as project index (generic, not hardcoded document names).
- **visual-digest.md**: Added Phase 5 (context update + _digest-log.md registration) + memory path.
- **visual-qa-agent.md**: Added YAML frontmatter (was missing entirely).
- **dev-orchestrator.md**: Added missing tools, permissionMode, maxTurns, color.
- **drift-auditor.md**: Fixed non-standard `role:` → `description:`, added tools/permissionMode/maxTurns/color.
- **frontend-test-runner.md**: Added tools, maxTurns, color. Changed bypassPermissions → acceptEdits.
- **5 agents** (architect, business-analyst, sdd-spec-writer, meeting-risk-analyst, diagram-architect): Updated `reglas-negocio.md` references to generic `RULES.md (o reglas-negocio.md)`.
- **coherence-validator.md** + **reflection-validator.md**: Fixed bare MEMORY.md → full 3-level path.
- **.gitignore**: Added `git/` to exclude local infrastructure.

### Fixed

- **Agent audit**: Scanned all 43 agents across 7 dimensions. Fixed 15 agents with structural issues (incomplete frontmatter, outdated references, missing memory paths, missing Phase 4/5 in digest agents). Report: `output/agent-audit-20260319.md`.

## [3.1.0] — 2026-03-17

Era 116 — Universal digest traceability + visual-digest agent with 4-pass contextual OCR pipeline.

### Added

- **Rule: digest-traceability.md**: Universal traceability for all data sources processed by Savia (documents, transcriptions, audio, web, repos, diagrams). Idempotency protocol ensures no source is processed twice. Centralized `_digest-log.md` per project with change detection and archival strategy. Privacy-first: log lives inside `projects/` (gitignored).
- **Agent: visual-digest** (Opus 4.6): 4-pass contextual OCR for whiteboard photos, handwritten notes, paper diagrams, screenshots, and slides. Pipeline: raw extraction → project context loading (reads team/members, business rules, prior digests) → resolution with homonym disambiguation protocol (3 Sergios, 2 Javiers, 2 Alvaros) → cross-verification against verbal digests. Tested: resolved 10 more items than naive OCR, corrected 3 misidentifications.

### Changed

- **Digest workflow**: All digest agents (meeting-digest, document-digest, visual-digest) must now consult `_digest-log.md` before processing and update it after completion.
- **agents-catalog.md**: Updated from 37 to 39 agents (+visual-digest, +web-e2e-tester). Added Visual Digest flow.
- **README.md + README.en.md**: Agent count updated from 34 to 39 (aligned with actual .claude/agents/ directory).
- **CLAUDE.md**: Agent count updated from 34 to 39.

## [3.0.0] — 2026-03-16

Era 115 — Agent memory 3-level architecture (public/private/project). Meeting digest pipeline with confidentiality judge.

### Added

- **Agent memory 3 levels**: `public-agent-memory/` (git-tracked best practices), `private-agent-memory/` (gitignored personal context), `projects/{p}/agent-memory/` (gitignored client data)
- **Agent: meeting-digest** (Sonnet 4.6): extracts team profiles, business context and action items from meeting transcriptions (VTT, DOCX, TXT)
- **Agent: meeting-risk-analyst** (Opus 4.6): cross-references meeting decisions against business rules, detects interpersonal conflicts, duplicities, dependencies and risky decisions
- **Agent: meeting-confidentiality-judge** (Opus 4.6): validates that confidential data marked during extraction does not leak to project files
- **Command: /meeting-digest**: 3-phase pipeline — extraction, confidentiality filter, risk analysis
- **Rule: agent-memory-isolation.md**: immutable rule enforcing 3-level separation with RGPD compliance

### Changed

- **agent-memory-protocol.md**: rewritten for 3-level architecture (public/private/project)
- **agent-self-memory.md**: rewritten for 3-level architecture with classification criteria
- **agents-catalog.md**: updated from 34 to 37 agents, added Meeting Digest flow
- **memory-system.md**: added Agent Memory section documenting 3 levels
- **.gitignore**: `private-agent-memory/` added, `public-agent-memory/` explicitly tracked

### Removed

- **`.claude/agent-memory/`**: legacy single-level agent memory (migrated to 3 levels)

## [2.99.0] — 2026-03-16

Era 114b — Windows installer zero-touch: auto-install deps, PATH config, parse fixes.

### Fixed

- **install.ps1**: ASCII art reading "Saxia" instead of "Savia"
- **install.ps1**: PowerShell parse errors from em dashes and subexpressions in double-quoted strings
- **install.ps1**: Windows `python3.exe` Store stub causing NativeCommandError
- **install.ps1**: Clone failure when running from inside the repo
- **install.ps1**: Unicode box-drawing chars rendering as mojibake in PowerShell terminal

### Changed

- **install.ps1**: Auto-install missing dependencies (Git, Node.js, Python, jq) via winget/choco instead of just detecting and aborting
- **install.ps1**: Add Claude Code `~/.local/bin` to user PATH permanently after install
- **install.ps1**: Fallback to `~/pm-workspace` when `~/claude` exists but is not a git repo

## [2.98.0] — 2026-03-15

Era 114 — Git Manager roadmap, E2E screenshot validation rule, settings privacy guard.

### Added

- **Git Manager roadmap** (`specs/roadmap-git-manager.md`): full open-source research (10 projects analyzed: Ungit, isomorphic-git, Gitea, lazygit...), technical design (17 Bridge endpoints, TypeScript interfaces, SVG graph algorithm, security patterns), and 3-week implementation plan
- **Rule: E2E screenshot validation** (`e2e-screenshot-validation.md`): cross-project rule — all web E2E tests must include screenshots for visual confirmation
- **Script: validate-settings-local.sh**: detects private data (localhost URLs, hardcoded paths, session-specific commands) in `settings.local.json` before commit
- **Domain rules**: added `globs` frontmatter for path-specific auto-loading (41 rules)

### Fixed

- **settings.local.json**: cleaned session-specific permissions (hardcoded URLs, piped commands), kept only generic tool wildcards

## [2.97.0] — 2026-03-15

Era 113 — Savia Web: chat multi-thread, tool feedback, markdown quality, session fixes.

### Added

- **Chat tool activity feed**: Live progress inside assistant bubble while Savia uses tools (📄 Reading, 🔍 Searching, 🤖 Delegating...) with pulsing indicator
- **Chat multi-thread**: Session-scoped streaming — responses don't leak between sessions. Stream cancelled on session switch
- **Chat session titles**: "Mar 15, 18:30 — message digest" format with date+time
- **Chat delete persistence**: Deleted sessions tracked in localStorage, won't reappear from Bridge on reload
- **Markdown rendering**: Headings (H1-H3), 10px paragraph spacing, tables with borders, blockquotes, code blocks, lists with indentation, horizontal rules
- **Session active indicator**: Left border accent (violet) + icon color for active session
- **Spec**: chat-multithread, chat-tool-feedback (2 new specs)
- **Rule**: pre-commit-bats — always run `tests/run-all.sh` before commit

### Fixed

- **Session panel width**: Was 0px (missing CSS width), now 260px
- **Delete button hover**: Bigger click area, visible on hover for non-active sessions
- **SSE streaming**: One-shot mode, `Connection: close`, client-side stream break
- **Chat identity**: User context injected in every message (works with --resume)
- **Dashboard**: Greeting field flattened from nested user.greeting
- **BATS**: CHANGELOG Era references, hook set flags, duplicate version entries

## [2.96.0] — 2026-03-15

Era 112 — Savia Web Phase 3: per-user auth, user management, chat sessions, bug fixes.

### Added

- **Per-user tokens**: Individual tokens per user in `~/.savia/bridge/users/{slug}/token`, profile.json with roles
- **User management**: Admin panel `/admin/users` — create/edit/delete users, role dropdown, token rotation/revocation, last-admin protection
- **Chat session management**: Session list sidebar (260px), New Chat, switch sessions, delete, titles with "date — message digest", localStorage persistence
- **Chat markdown**: Bubbles render markdown (bold, code, lists, links) via `marked`
- **Chat identity**: Bridge injects `[Contexto: usuario=Name, rol=role]` in every message — Savia knows who you are
- **Bridge `/auth/me`**: Returns authenticated user slug + role
- **Bridge user CRUD**: GET/POST `/users`, PUT/DELETE `/users/{slug}`, rotate-token, revoke
- **File access control spec**: Role-based file browser access (admin=root, user=projects only)
- **Create project modal**: Teleport to body, responsive, z-index 9999

### Fixed

- **SSE chat hanging**: Switched from interactive stdin/stdout to one-shot streaming (`claude -p`)
- **Chat input disabled after response**: `Connection: close` header + client-side stream break on `done`
- **Session conflict**: Corrupted sessions detected and invalidated, user gets friendly message
- **Dashboard not loading**: Bridge `user.greeting` flattened to match `DashboardData.greeting`
- **Chat blank on navigation**: `initSession` skips re-init if messages in memory
- **Session delete not reactive**: Changed `filter` to `splice` for in-place mutation
- **Session panel width 0**: Added `width: 260px` + `min-width`

### Stats

- Unit tests: 228 (42 files)
- E2E tests: 148 (18 files) — with screenshots for visual validation
- Bridge tests: 29
- Specs: 22 (21 implemented, 1 planned)

## [2.95.0] — 2026-03-15

Era 112 — Savia Web Phase 2: i18n fully wired, project context switch, all gaps fixed.

### Added

- **i18n fully wired**: All 12 pages + AppSidebar use `useI18n()` / `$t()`. Zero hardcoded strings
- **Project context switch**: Dashboard, reports, pipelines, integrations stores watch `projectStore.selectedId` and reload on change
- **Vitest i18n setup**: Global test setup registers i18n plugin for all component tests
- **Phase 2.5 spec**: Create project from web (modal + scaffolding via Bridge)

### Fixed

- E2E `clearSession` sets English locale to match test assertions
- `useReportData` now uses `projectStore` instead of `dashboardStore` for project context
- All 217 unit tests + 109 E2E tests pass with i18n

## [2.94.0] — 2026-03-15

Era 111 — Radical Honesty Principles (Rule #24).

### Added

- **Rule #24 — Radical Honesty**: new domain rule (`radical-honesty.md`) with 6 prohibitions (no filler, no sugar-coating, no unearned praise, no hedging, no self-announcement, no comfort-seeking language) and 6 obligations (challenge assumptions, expose blind spots, mirror self-deception, show where they play small, objective depth, ground in personal truth)
- **tone.md**: new `honesty` field (`radical` | `standard`) in user tone template

### Changed

- **Savia persona** (`savia.md`): personality rewritten from "warm, bonachona" to "direct, strategic, radically honest". Linguistic register, banned phrases and example phrases updated
- **Adaptive output** (`adaptive-output.md`): all 3 modes (coaching, executive, technical) rewritten to follow radical honesty — no false encouragement, no hedging, quantified costs
- **CLAUDE.md**: Rule #24 added to Critical Rules. Savia description updated

## [2.93.0] — 2026-03-14

Era 110 — Autonomous Pipeline Engine: local CI/CD without Jenkins.

### Added

- **scripts/pipeline-engine.sh**: Orchestrate pipeline execution from YAML definition — parses stages, respects dependencies, parallel support, dry-run mode
- **scripts/pipeline-stage-runner.sh**: Execute individual pipeline stages (bash command or agent), log results as JSON
- **.claude/templates/pipeline/ci-template.yaml**: Sample CI pipeline with build, test, security, lint, review stages
- **.claude/commands/pipeline-local-run.md**: `/pipeline-local-run` command for local pipeline execution
- **tests/structure/test-pipeline-engine.bats**: 7 BATS tests for engine and stage runner

## [2.92.0] — 2026-03-14

Era 103 — LSP-Powered Code Intelligence: best-practices-check command.

### Added

- **.claude/commands/best-practices-check.md**: `/best-practices-check` evaluates workspace against 5 categories (structure, hooks, context, testing, docs) with score 0-100

## [2.91.0] — 2026-03-14

Era 107.3 — Backlog resolver: local-first data source for commands.

### Added

- **scripts/backlog-resolver.sh**: Sourceable helper for commands — resolves backlog path, sprint ID, PBI counts by state, board summary, sprint items. Local-first with API fallback
- **tests/structure/test-backlog-resolver.bats**: 8 BATS tests for resolver functions

## [2.90.0] — 2026-03-14

Era 102 — Real-Time Observatory: statusline, notifications, activity log.

### Added

- **scripts/statusline-provider.sh**: HUD data provider for Claude Code statusline — outputs JSON with tier, context window, project, branch, PBI counts
- **scripts/notify.sh**: Cross-platform desktop notifications (Linux notify-send, macOS osascript, fallback echo)
- **.claude/commands/agent-activity.md**: `/agent-activity` command showing structured log of recent agent executions
- **tests/structure/test-observatory.bats**: 6 BATS tests for observatory components

## [2.89.0] — 2026-03-14

Era 107.2 — Sync Adapters: Azure DevOps, Jira, and GitHub Issues bidirectional sync.

### Added

- **scripts/sync-adapters/adapter-interface.sh**: Common functions for sync — logging, field extraction, state mapping, conflict detection
- **scripts/sync-adapters/azure-devops-adapter.sh**: Pull/push/diff with Azure DevOps work items via REST API
- **scripts/sync-adapters/jira-adapter.sh**: Pull/push/diff with Jira Cloud via REST API v3
- **scripts/sync-adapters/github-issues-adapter.sh**: Pull/push/diff with GitHub Issues via gh CLI
- **.claude/commands/backlog-sync.md**: `/backlog-sync` command for pull/push/diff operations
- **tests/structure/test-sync-adapters.bats**: 11 BATS tests for adapter interface and state mapping

## [2.88.0] — 2026-03-14

Era 107.1 — Backlog Sovereignty: markdown-based backlog as source of truth.

### Added

- **scripts/backlog-init.sh**: Initialize backlog structure for any project (config, sprint folder, PBI directory)
- **scripts/backlog-pbi-crud.sh**: Create, read, update, list, archive PBIs as markdown files with YAML frontmatter
- **scripts/backlog-query.sh**: Query PBIs by state, sprint, assigned, priority, type. Outputs table, JSON, or count
- **.claude/templates/backlog/**: PBI template, sprint-meta template, config template
- **tests/structure/test-backlog-structure.bats**: 11 BATS tests for backlog init, CRUD, and query

## [2.87.0] — 2026-03-14

Era 100.3 — Context metrics command and session snapshot integration.

### Added

- **.claude/commands/context-status.md**: Lightweight command (Haiku) showing model, context window, tier, compact threshold, strategy, and recommendations

## [2.86.0] — 2026-03-14

Era 100.2 — Context Sync Persistente. Session snapshot save/load between sessions.

### Added

- **scripts/context-snapshot.sh**: Save/load session context (project, branch, sprint, last activity) as JSON. 24h TTL, auto-expired
- **.claude/hooks/session-end-snapshot.sh**: Stop hook that auto-saves snapshot at session end (async, 5s timeout)
- **tests/structure/test-context-snapshot.bats**: 7 BATS tests for snapshot save/load/status

### Changed

- **session-init.sh**: Loads fresh snapshot at startup, shows recovered project in init output
- **.claude/settings.json**: Added session-end-snapshot hook to Stop event
- **.gitignore**: Added `.claude/context-cache/`

## [2.85.0] — 2026-03-14

Era 100.1 — Lazy Loading of Rules Domain. Tier-based rule classification and manifest.

### Added

- **scripts/rule-usage-analyzer.sh**: Analyzes domain rule usage across workspace — classifies 110 rules into tier1 (startup), tier2 (on-demand), dormant (unreferenced). Outputs JSON manifest
- **.claude/rules/domain/rule-manifest.json**: Pre-computed map of 110 rules with tier + consumers. 13 tier1, 35 tier2, 62 dormant
- **tests/structure/test-rule-lazy-loading.bats**: 8 BATS tests for analyzer and manifest integrity

## [2.84.0] — 2026-03-14

Era 100.0 — Context Window Adaptive per Model. Provider-agnostic dynamic context detection.

### Added

- **config/model-capabilities.yaml**: LLM capability registry — maps models to context window, tier, and strategy. Supports Claude, GPT, Gemini, Llama, Mistral (provider-agnostic)
- **scripts/model-capability-resolver.sh**: Detects active model, parses YAML registry, exports `SAVIA_CONTEXT_WINDOW`, `SAVIA_MODEL_TIER`, `SAVIA_COMPACT_THRESHOLD` env vars. Falls back to 128K/fast for unknown models
- **scripts/adaptive-strategy-selector.sh**: Given a tier (max/high/fast), outputs JSON with lazy loading, agent budget, autocompact, and sprint loading strategy
- **tests/structure/test-model-capabilities.bats**: 13 BATS tests covering registry, resolver, and strategy selector

### Changed

- **session-init.sh**: Model capability detection runs as first step — sets SAVIA_* vars for downstream scripts
- **CLAUDE.md**: Updated to reflect Era 100.0 context intelligence

## [2.83.0] — 2026-03-14

Era 63 — Multi-user session architecture with per-user isolation in savia-bridge.

### Added

- **Per-user session isolation**: savia-bridge supports multiple concurrent users without lock contention with terminal
- **Two-tier auth**: master token + per-user tokens via `POST /auth/register`
- **Username field**: added to mobile `BridgeSetupDialog` and web `LoginPage`
- **Eye toggle on token field**: visibility toggle for token input in web and mobile
- **HTTPS cert-hint**: visual indicator when connecting over HTTPS
- **Session persistence**: per-user sessions survive bridge restarts
- **Token toggle E2E tests**: new Playwright test file for token visibility (`e2e/token-toggle.spec.ts`)
- **Multi-user sessions spec**: formal specification for the feature (`specs/multi-user-sessions.spec.md`)

### Changed

- **savia-bridge.py**: refactored session management for per-user isolation
- **SecurityRepository (mobile)**: updated interface for username-based auth
- **auth store (web)**: session management adapted for multi-user flow
- **chat store (web)**: threading adapted for per-user context

### Fixed

- Bridge lock contention between web/mobile users and terminal session

## [2.82.0] — 2026-03-14

Era 62b — Savia Web production-ready: login system, E2E testing, modern UI, and bridge threading fix.

### Added

- **Login system**: Server URL + @username + token authentication with cookie persistence, team profile loading, and registration wizard for new users (`LoginPage.vue`, `RegisterWizard.vue`)
- **E2E test suite**: 8 Playwright test files covering login, navigation, dashboard, theme, reports, chat, pages, and UI quality — with regression plan (`specs/regression-plan.md`)
- **web-e2e-tester agent**: autonomous browser testing agent equivalent to android-autonomous-debugger (`.claude/agents/web-e2e-tester.md`)
- **Dark/light mode toggle**: sidebar footer switch with localStorage persistence and full CSS variable adaptation
- **Chat typing indicator**: animated dots spinner while waiting for bridge response
- **Version auto-increment**: `prebuild` script bumps patch version on every `npm run build`
- **Lucide icons**: replaced all emoji icons with tree-shakeable SVG icons (ISC license)
- **Savia logo**: owl PNG from savia-mobile with transparent background for dark mode

### Changed

- **savia-bridge.py**: `HTTPServer` → `ThreadingHTTPServer` — fixes concurrent request blocking (chat no longer freezes health/dashboard/team endpoints)
- **LoginPage.vue**: 8-second fetch timeout with `AbortController` — shows error instead of hanging on "Connecting..."
- **MainLayout.vue**: auto-connect with timeout; shows login form on failure
- **AppSidebar.vue**: Lucide icons, logo image, theme toggle, dynamic version from `package.json`
- **AppTopBar.vue**: profile name + logout button with Lucide icons
- **Design system**: glassmorphism surfaces, Inter font, layered shadows, focus rings, spacing tokens

### Fixed

- Bridge single-thread blocking: `/chat` no longer prevents other endpoints from responding
- Login "Connecting..." infinite hang when bridge is unreachable

## [2.81.0] — 2026-03-14

Era 62a — Savia Web: Vue.js web client for PM-Workspace dashboards with reporting endpoints.

### Added

- **savia-web**: Vue 3 + TypeScript + Vite web client with 10 dashboard pages (sprints, burndown, DORA, capacity, workload, quality, debt, cycle-time, portfolio, team health) and 10 reusable ECharts components (line, bar, gauge, pie, heatmap, sankey, scatter, radar, tree, timeline)
- **savia_bridge_reports.py**: 8 HTTP JSON endpoints for reporting (velocity, burndown, DORA, workload, quality, debt, cycle-time, portfolio) that feed the web client
- **setup-savia-web.sh**: Production build and serve script for Savia Web with health checks and graceful shutdown
- **projects/savia-web/CLAUDE.md**: Project configuration and development guide

## [2.80.0] — 2026-03-13

Era 62 — Agent and skill enrichment: handoff templates, assignment matrix, enhanced verification, skill metadata, and agent identity profiles.

### Added

- **handoff-templates rule**: 7 standardized templates for agent-to-agent transitions (Standard, QA Pass/Fail, Escalation, Phase Gate, Sprint Review, Status Report)
- **assignment-matrix rule**: Task Type → Agent routing table (39 task types, 12 language packs, selection rules)
- **decision-trees/**: externalized decision trees for agents exceeding 150-line limit

### Changed

- **verification-before-done rule**: enhanced with evidence-based quality gates, retry policy (haiku→sonnet→opus→human), escalation handoff format
- **skill-auto-activation rule**: refined scoring (40% base + 30% context + 30% history), 7 category taxonomy, priority-based thresholds
- **75 skills**: added `category`, `tags`, `priority` metadata to YAML frontmatter for intelligent routing and auto-activation
- **10 agents** (architect, business-analyst, code-reviewer, commit-guardian, dotnet-developer, frontend-developer, sdd-spec-writer, security-guardian, test-runner, typescript-developer): enriched with Identity, Core Mission, Decision Trees, Success Metrics
- **README.md / README.en.md**: updated skill count (45→75), agent count alignment (34)

## [2.79.0] — 2026-03-13

Autonomous modes — overnight sprint, code improvement loop, tech research agent, and dev onboarding with AI buddy.

### Added

- **`/overnight-sprint` command**: autonomous overnight sprint — executes low-risk tasks, creates Draft PRs for human review
- **`/code-improve` command**: autonomous code improvement loop — detects coverage, lint, debt opportunities and generates PRs
- **`/tech-research` command**: autonomous technical research — investigates topics, generates reports, notifies designated reviewer
- **`/onboarding-dev` command**: technical onboarding with AI Buddy — auto-generates 12 project docs, personalized 30/60/90 plan, 3-layer buddy agent
- **overnight-sprint skill** (SKILL.md + DOMAIN.md): task selection, risk scoring, fail-safe with model escalation
- **code-improvement-loop skill** (SKILL.md + DOMAIN.md): detect/improve/verify cycle with auto-categorization
- **tech-research-agent skill** (SKILL.md + DOMAIN.md): 5-phase research pipeline (scope, search, analyze, synthesize, report)
- **onboarding-dev skill** (SKILL.md + DOMAIN.md): buddy-ia agent with 3 layers (navigator, mentor, pair)
- **autonomous-safety rule**: immutable safety guardrails for all autonomous modes (agent/* branches, Draft PRs, human reviewer gate, fail-safes)
- **docs/AUTORESEARCH.md**: autonomous research methodology documentation
- **docs/autoresearch-cases.md**: example research cases and templates

### Changed

- **CLAUDE.md**: added rule 8b (Autonomy) and 4 new skills in catalog
- **pm-config.md**: added Autonomous Modes and Onboarding configuration sections
- **README.md / README.en.md**: updated counters (400+ commands, 45 skills) and added autonomous modes section

## [2.78.0] — 2026-03-11

Reverse orgchart import — parse diagrams (Mermaid, Draw.io, Miro) to generate teams/ structure.

### Added

- **`/orgchart-import` command**: imports orgchart diagrams and generates department, team and member files in `teams/`
- **orgchart-import skill**: 7-phase pipeline (detect format, parse, normalize, validate, detect conflicts, write, summary) with 3 conflict modes (create, merge, overwrite)
- **Mermaid parser**: recognizes DEPT nodes, subgraphs with capacity, member nodes with lead markers (★), supervisor links
- **Draw.io parser**: identifies entities by shape styles (swimlane=dept, rounded rect=team, person shape=member, green fill=lead)
- **Miro parser**: heuristic-based detection by color/shape/position with user confirmation fallback
- **Org model schema**: normalized JSON contract bridging all parsers to the write phase
- **DOMAIN.md**: Clara Philosophy documentation for the skill

### Changed

- **diagram-config.md**: added `ORGCHART_IMPORT_MODES` and `ORGCHART_IMPORT_DEFAULT_MODE` constants
- **README.md / README.en.md**: documented orgchart import capability in code intelligence section

## [2.77.0] — 2026-03-10

Orgchart diagram generation from teams data — new diagram type for `/diagram-generate`.

### Added

- **Orgchart diagram type**: `/diagram-generate {dept} --type orgchart` generates hierarchical team diagrams from `teams/` data, exportable to Draw.io, Miro or local Mermaid
- **Orgchart shapes reference**: Draw.io XML snippets for department containers, team nodes, person shapes (lead vs member), hierarchy and supervisor links (`orgchart-shapes.md`)
- **Orgchart Mermaid template**: `graph TB` template with subgraphs per team, lead markers (★), @handle-based naming, PII-Free compliant (`orgchart-mermaid-template.md`)
- **Test suite**: `scripts/test-orgchart-diagrams.sh` — 45 tests covering config, structure, shapes, template, command integration, skill integration and Mermaid output generation

### Changed

- **diagram-config.md**: `DIAGRAM_TYPES` now includes `orgchart`, added `ORGCHART_DATA_DIR` and `ORGCHART_OUTPUT_DIR`
- **diagram-generation SKILL.md**: Added Orgchart to supported types, teams data source note, two new reference files
- **diagram-generate command**: Added `--type orgchart` with 6-step orgchart-specific flow (dept validation, hierarchy read, Mermaid generation, export, metadata, presentation)
- **README.md / README.en.md**: Documented diagram generation capabilities including orgchart

## [2.76.5] — 2026-03-10

### Fixed — Savia Mobile v0.3.46: one-shot mode + command pre-fill

- **Savia Mobile chat fix (CRITICAL)**: Switched from interactive bidirectional stream-json to one-shot mode (`-p --output-format stream-json`) — Claude CLI interactive mode does not work as subprocess. Each message now launches a fresh process with `--resume` for session continuity
- **Command pre-fill from palette**: Commands screen now passes selected command text to Chat via navigation query parameter (`?command=encoded`). ChatInput uses `remember(key)` to reinitialize state on new command
- **Unified chat navigation**: Merged duplicate `composable()` routes into single `chat?conversationId={}&command={}` with both optional params
- **Bridge interactive session manager**: Added `InteractiveSession` class with full bidirectional protocol, permission request/response flow, and `/chat/permission` endpoint (infrastructure for future interactive mode)
- **Permission request model**: New `StreamDelta.PermissionRequest` and `sendPermissionResponse()` in `SaviaBridgeService` for tool approval UI
- **Regression test**: 10/10 pass on OUKITEL C36 (Android 14), zero permission popups across 55 operations

## [2.76.4] — 2026-03-10

### Fixed — Era 104: Auditoría — stdin timeout en 4 hooks + documentación

- **Hook stdin timeout (CRÍTICO)**: Aplicado `timeout 3 cat` a `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `tdd-gate.sh` y `validate-bash-global.sh`. Usaban `INPUT=$(cat)` sin timeout, causando "PreToolUse:Bash hook error" al bloquear stdin indefinidamente
- **hooks/README.md**: Documentados 7 hooks faltantes (android-adb-validate, block-project-whitelist, compliance-gate, agent-dispatch-validate, memory-auto-capture). Total: 19 hooks documentados
- **PCRE fallback**: Reemplazado `grep -oP '\K'` por alternativa POSIX en `block-infra-destructive.sh` y `tdd-gate.sh`

## [2.76.3] — 2026-03-10

### Fixed — Era 104: Compound command patterns + APK test robustness

- **APK integration tests**: Added `dismiss_system_dialogs()` to handle Android 13+ notification permission dialog that blocked all test UI interactions. Tests now re-launch app if it goes to background after Bridge connection. All 23/23 APK tests pass

- **Compound `&&`/`||` patterns**: Added `Bash(cd * && *)`, `Bash(cd * || *)`, `Bash(source * && *)`, `Bash(. * && *)` to default permission whitelist. Claude Code's `*` wildcard is shell-aware and does not cross `&&`/`||` operators — a simple `Bash(cd *)` never matched `cd dir && cmd`
- **Hook robustness**: Improved `validate-bash-global.sh` stdin parsing with `printf '%s'` and `IFS= read` for reliable JSON handling
- **setup-claude-permissions.sh**: Updated default generated patterns to include compound command entries and network utilities (`ip`, `ifconfig`, `hostname`)

## [2.76.2] — 2026-03-10

### Fixed — Era 104: adb-run.sh wrapper + hook error fix

- **adb-run.sh**: New single-command runner that replaces `source wrapper.sh && cmd1 && cmd2` chains. Claude Code's shell-aware `*` doesn't cross `&&`/`||` operators, making compound command patterns impossible to whitelist. `adb-run.sh` encapsulates source + functions in one simple command
- **Hook stdin fix**: `validate-bash-global.sh` now uses `read -t 2` with timeout instead of `cat` (which could hang indefinitely waiting for stdin)
- **SKILL.md rewrite**: All examples now use `./scripts/adb-run.sh` pattern exclusively

## [2.76.1] — 2026-03-10

### Fixed — Era 104: CHANGELOG link enforcement + Claude Code permission cleanup

- **CI Gate 6: CHANGELOG Version Links**: Added validation to `ci-extended-checks.sh` that fails CI if any `## [X.Y.Z]` header lacks its reference link at the end of the file. Prevents the recurring issue of missing comparison links
- **Claude Code permission setup**: New `scripts/setup-claude-permissions.sh` generates `settings.local.json` with glob-based permission patterns (auto-detects Android SDK, JAVA_HOME, ADB). Eliminates the ~50 exact-match ADB commands that caused constant permission popups
- **Installer integration**: Added Step 6 to `install.sh` — runs permission setup automatically during workspace installation
- **Shell-aware permission patterns**: Fixed compound `&&` command patterns — Claude Code is shell-aware and won't auto-approve chained commands with prefix-only patterns. Added explicit `Bash(source wrapper.sh && *)` patterns
- Fixed missing `[2.76.0]` comparison link in CHANGELOG.md

## [2.76.0] — 2026-03-10

### Added — Android Debug Agent: autonomous device testing

- **ADB wrapper library** (`scripts/lib/adb-wrapper.sh`): 40+ functions for device management, APK lifecycle, screenshots, UI hierarchy, interaction (tap/swipe/type/scroll), logcat analysis, crash detection, and element finding. Auto-detects ADB binary and device, includes retry logic and structured JSON output
- **Security hook** (`.claude/hooks/android-adb-validate.sh`): PreToolUse hook classifying ADB operations into safe (auto-approved), risky (logged), and blocked (rejected). Prevents destructive commands while allowing autonomous debugging without permission prompts
- **Debugger skill** (`.claude/skills/android-autonomous-debugger/SKILL.md`): Complete workflow for autonomous debug cycles — install, launch, interact, detect crashes, capture evidence, report results
- **Integration test suite** (`scripts/tests/test-adb-wrapper.sh`): 44 tests covering core functions, security classification, device management, visual capture, logcat, Savia Mobile integration, and hook validation. All tested against physical OUKITEL C36 device
- **Documentation** (`docs/android-debug-agent.md`): Full API reference, architecture diagram, use cases for PM/QA smoke testing, developer debugging, and CI verification. Includes security model and environment variable reference

### Fixed

- **Bridge duplicate text**: Response text no longer appears twice in chat bubbles (result event suppressed when streaming already delivered the content)
- **Bridge session persistence**: Known sessions saved to `~/.savia/bridge/known-sessions.json` — multi-turn conversations survive bridge restarts
- **Bridge "already in use" recovery**: If session conflict detected, session marked as known for automatic retry

### Added

- **Chat timestamps**: Message bubbles display HH:mm time for traceability (SimpleDateFormat with `remember` for performance)

## [2.75.0] — 2026-03-10

### Added — OpenCode Integration: PM-Workspace compatibility layer

- **OpenCode compatibility layer**: Created `/home/monica/savia/.opencode/` with symlinks to original directories (`.claude/`, `docs/`, `projects/`, `scripts/`) for OpenCode tool usage while preserving Claude Code functionality
- **Cross-platform installers**: `install.sh` (Linux/macos) and `install.ps1` (Windows) similar to Claude Code's installers but adapted for OpenCode
- **Hooks integration solution**: Git hooks automation (`scripts/install-git-hooks.sh`) installs pre-commit, pre-push, and commit-msg hooks that automatically validate security/quality gates missing in OpenCode
- **OpenCode wrappers**: `scripts/opencode-hooks/wrappers/safe-*.sh` validate commands before executing with OpenCode tools, bridging the security/quality gap from missing automatic hook execution
- **Documentation**: Updated `.opencode/README.md` with comprehensive OpenCode usage guide and hooks strategy explaining why integration doesn't affect Claude Code's ongoing Savia Mobile work
- **Branch isolation**: Created `feat/opencode-hooks-integration` branch with all OpenCode changes, ready for PR creation without interfering with Claude Code's work on main branch
- **CHANGELOG audit and fix**: Consolidated scattered version links to end of file, added missing links for versions 2.73.0–2.74.2, ensuring compliance with changelog-enforcement rule

## [2.74.2] — 2026-03-09

### Fixed — Era 103: Chat runtime crash + crash handler

- Fixed Savia Mobile chat crash: replaced `LocalLifecycleOwner`/`DisposableEffect` with `ProcessLifecycleOwner` in `SaviaNotificationManager`
- Added global crash handler (`SaviaApp.installCrashHandler()`) logging to logcat + `last_crash.log`
- Simplified `ChatViewModel` — removed `isAppInForeground` field

## [2.74.1] — 2026-03-09

### Fixed — Era 103: ChatViewModel crash + build gate

- Fixed ChatViewModel crash: added missing `SaviaNotificationManager` mock in unit and integration tests (5 call sites)
- New `buildAndPublish` Gradle task: tests → build → publish chain. If tests fail, no APK gets published. Replaced unsafe `finalizedBy` pattern
- Added Savia Mobile build rule to `CLAUDE.md`: always `./gradlew buildAndPublish`, never `assembleDebug`

## [2.74.0] — 2026-03-09

### Changed — Era 103: All gaps implemented — code review 4-judge panel, file browser, notifications, output persistence

- **Code Review gaps (all 4 done)**: performance-auditor as 4th consensus judge (weights 0.3/0.3/0.2/0.2), parallel dispatch via dag-scheduling, enforced risk-based routing, per-finding confidence curves
- **Bridge file browser**: new `GET /files` and `GET /files/content` endpoints with path traversal prevention and 500KB limit
- **Savia Mobile file browser**: `FileBrowserScreen` with directory listing, code viewer (monospace + line numbers), markdown renderer (Markwon), breadcrumb navigation. New `Screen.Files` route + HomeScreen quick action
- **Android notification permission**: `POST_NOTIFICATIONS` for Android 13+, runtime permission request on launch, `SaviaNotificationManager` singleton with "response complete" notification when app is backgrounded
- **Output persistence**: `SavedOutputEntity` Room table (v2 migration) for persisting Claude-generated outputs (code, reports, snippets) with favorites, type filtering, and conversation linkage. `SavedOutputDao` with CRUD + favorites
- Updated `docs/roadmap-code-review-improvements.md`: all 4 gaps marked as implemented

## [2.73.0] — 2026-03-09

### Changed — Era 102: Pentester integration, Savia Mobile non-blocking chat, code review roadmap

- Integrated `pentester` agent into documentation: agents-catalog (34 agents), adversarial-security rules, README security section
- **Savia Mobile non-blocking chat**: message queue (`Channel<String>`) allows sending multiple messages without waiting for response. Spinner moved from input box to streaming bubble. Pending message count badge on send button
- Fixed SQLCipher dependency visibility: `implementation` → `api` in data module so DatabaseModule (app module) can resolve `SupportOpenHelperFactory`
- Added code review improvements roadmap: confidence scoring, performance analyzer agent, parallel judge dispatch, adaptive review depth
- New doc: `docs/roadmap-code-review-improvements.md`

## [2.72.0] — 2026-03-09

### Changed — Era 101: Pentester v2: Shannon-inspired pipeline architecture

- Rewrote `pentester` agent with autonomous 5-phase pipeline: pre-recon → recon → vulnerability analysis (5 parallel classes) → exploitation (proof-based) → reporting
- **"No exploit, no report"** policy: only Level 3 (impact demonstrated) findings appear in final report. L1 (theoretical) and L2 (partial) go to "Failed Attempts" section for transparency
- Queue-driven architecture: Phase 3 produces JSON vulnerability queues (`03-vuln-{class}.json`) consumed by Phase 4 exploitation — prevents hallucinated findings
- Added JSON schema (`queue-schema.json`) for formal queue validation with per-class ID patterns (INJ-xxx, XSS-xxx, AUTH-xxx, SSRF-xxx, AUTHZ-xxx)
- Phase prompts with Shannon-style framing: "sole responsibility", "mathematical rigor", cascading intelligence between phases
- Proof templates for L3 evidence: data_extraction, rce, auth_bypass, info_leak
- New queue validator script (`validate-queue.py`) for Phase 3→4 handoff validation
- Test suite expanded from 65 to 73 tests: new CAT-11 (Pipeline Architecture, 8 tests) with mandatory 100% on proof enforcement (S-04, S-05)
- Inspired by [KeygraphHQ/Shannon](https://github.com/KeygraphHQ/shannon) (96.15% on XBOW benchmark)

## [2.71.0] — 2026-03-09

### Added — Era 100: Pentester lab infrastructure

- Docker Compose lab (`tests/pentest-lab/`) with 6 intentionally vulnerable services: vuln-api (Flask), metadata-mock (AWS IMDSv1), tls-bad (weak TLS), MongoDB (no-auth), MinIO (default creds), Redis (no-auth)
- Vulnerable API with 15+ isolated endpoints mapped to test suite IDs (W-01..W-08, A-01..A-02, Z-01..Z-05, P-05..P-06, N-02..N-03)
- Lab orchestrator script (`run-lab.sh`) with up/down/status/test commands and 21 smoke tests
- Finding validator (`validate-findings.py`) for automated PT-NNN format checking
- All Python files syntax-validated, all shell scripts bash -n validated

## [2.70.0] — 2026-03-09

### Added — Era 99: Pentester agent for dynamic security testing

- New `pentester` agent (95L): elite ethical hacker for dynamic penetration testing across dev/pre/production environments. References `pentesting` skill for detailed arsenal
- New `pentesting` skill (98L): OWASP Top 10, PTES methodology, MITRE ATT&CK mapping, CVSS v3.1 scoring, detailed checklists
- Expertise areas: web app attacks, API security, authentication/authorization, network/infrastructure, container/cloud, cryptography, post-exploitation
- Environment-aware rules: aggressive in dev, moderate in pre, restrictive in production
- Integration with existing security pipeline (security-defender → security-auditor → pentester retest)
- Test suite with 65 tests across 10 categories (mandatory 100% on reporting quality and environment awareness)

## [2.69.0] — 2026-03-09

### Security — Era 98: Full audit and remediation (55 findings)

Comprehensive security audit across all of pm-workspace with full same-day remediation.

- **Audit** — 55 findings identified (18 critical, 22 high, 15 medium) across 6 areas: Android app, Bridge, dotnet-microservices, shell scripts, CI/CD, installers. Full report in `SECURITY-AUDIT-2026-03-09.md`.
- **Android** — SQLCipher enabled for Room Database (C2), logging restricted to DEBUG builds (C6), passphrase encoding fix (A11), cleartext traffic documentation (M4).
- **Bridge v1.6.0** — Input validation regex (C3), PAT encrypted with Fernet (C4), auth required on sensitive endpoints (C5), path traversal prevention (A1), SSE connection limit (A2), rate limiting on auth (A3), security headers (A4), CORS restricted (A5), body size limit 1MB (A6), log sanitization (A7), YAML injection prevention (M1), session ID validation (M2), minimum TLS cipher suite v1.2 (M3).
- **Kubernetes** — NetworkPolicy default-deny (A14), RBAC with dedicated ServiceAccounts (A15), Pod Security Context (A16), mTLS TODO (A17), image pinning (A18), worker health checks (M9), secrets TODO (M10).
- **dotnet-microservices** — Docker .env for credentials (C7), K8s secrets template (C11), CORS restricted (C12), JWT secret placeholder (C13), Dockerfile `npm ci --omit=dev` (M11), JWT logging (M12), Production templates (M14).
- **Shell scripts** — `bash -c` → `eval` in 44 test scripts (C10), trap quoting (C15), `curl | sh` safety (C14/C17), `irm | iex` warning (C18), atomic mv (A8), `mktemp -d` (A19), sudo validation (A20), tar safety (A21), temp cleanup (M5).
- **CI/CD** — SHA pinning in Actions (C9), npm version pinning (C8), jq mandatory in hooks (C16), expanded secret patterns (A13), tag validation (A9), explicit permissions (A22), BATS SHA pinning (M6), improved secret regex (M7).
- **Infrastructure** — Systemd hardening (A10), .gitignore binaries (A12), `SECRETS-ROTATION.md` (M13), plan-gate.sh 30s timeout (M15).
- **PR Guardian** — New Gate 8: CHANGELOG required for code PRs. Exempts `docs`, `chore`, `ci`, `style` types unless they touch domain rules (`.claude/rules/`). Previous Gate 8 (PR Digest) renumbered to Gate 9.
- **Language rule** — Mandatory English for all versioned content (CHANGELOGs, commits, PR titles, READMEs). Added to `github-flow.md`. Both CHANGELOGs translated from Spanish to English.
- **PRs:** [#280](https://github.com/gonzalezpazmonica/pm-workspace/pull/280), [#281](https://github.com/gonzalezpazmonica/pm-workspace/pull/281), [#282](https://github.com/gonzalezpazmonica/pm-workspace/pull/282), [#283](https://github.com/gonzalezpazmonica/pm-workspace/pull/283), [#285](https://github.com/gonzalezpazmonica/pm-workspace/pull/285), [#286](https://github.com/gonzalezpazmonica/pm-workspace/pull/286)

## [2.68.0] — 2026-03-09

### Added — Era 97: Savia Mobile v0.3.34: Full Dashboard + Bridge REST (Sprint 2026-04)

Second major release of Savia Mobile with functional dashboard, chat fixes, robust auto-update, and integrated test pipeline.

- **Dashboard (Home)** — Project selector with filtered search, sprint selector, sprint progress bar with story points, blocked items + hours metrics, My Tasks section, Recent Activity feed, Quick Actions (See Board, Approvals), FAB for quick capture. Project selection persists across reloads (local storage).
- **Secondary screens (REST)** — Kanban board, Time log, Approvals, Capture, Git Config, Team Management, Company Profile — all via Bridge REST endpoints.
- **Chat fixes** — Eliminated duplicate messages (Room as single source of truth), fixed CLAUDECODE nested session error (Bridge strips env var from subprocess), slash command autocomplete (8 commands).
- **Auto-update** — APK download progress bar (LinearProgressIndicator + %), "Check updates" button in both Profile and Settings, reset state on re-check.
- **Build pipeline** — Version auto-increment at Gradle configuration phase (fixes version lag), unit tests as mandatory gate before APK publish, `assembleDebug` runs `testDebugUnitTest` automatically, `publishToBridge` + `publishToDist` only if tests pass.
- **Tests** — 48 unit tests passing (HomeViewModelTest added: 5 tests for dashboard load, project selection, persistence, errors). Spec coverage: Chat, Home, Settings, Profile, Navigation.
- **Bridge v1.5.0** — `POST /timelog` endpoint, CLAUDECODE env var stripped from Claude CLI subprocess, all REST endpoints verified (`/kanban`, `/timelog`, `/approvals`, `/capture`, `/profile`, `/dashboard`).
- **Path:** `projects/savia-mobile-android/`, `scripts/savia-bridge.py`

## [2.67.0] — 2026-03-08

### Added — Era 96: Savia Mobile: Android App + Bridge Server

Native Android companion app for pm-workspace with Python Bridge server.

- **Savia Mobile Android** — Native Kotlin/Jetpack Compose app with Clean Architecture (`:app`, `:domain`, `:data`). Chat with Claude via SSE streaming, session persistence (Room + Tink AES-256-GCM), Material 3 violet theme, dual-backend (Bridge primary, API fallback). 39 Kotlin files, 157 tests.
- **Savia Bridge** — Python HTTPS server (port 8922) wrapping Claude Code CLI. SSE streaming, session management, Bearer token auth, auto-TLS. HTTP install server (port 8080) for APK distribution. 1,191 lines, v1.2.0.
- **Updated installers** — `install.sh` and `install.ps1` now include Step 6: automatic Bridge setup (systemd/launchd/Windows service, token generation, health check).
- **Documentation** — KDoc on all 39 source files, 8 specs rewritten, 3 new guides (ARCHITECTURE, SETUP, BRIDGE-GUIDE), API reference, CHANGELOG.
- **Path:** `projects/savia-mobile-android/`, `scripts/savia-bridge.py`, `scripts/savia-bridge.service`

## [2.66.0] — 2026-03-08

### Added — Era 95: Rules Topology & Consolidation

Rules dependency analysis and workspace governance tooling.

- **Rules topology analyzer** (`scripts/rules-topology.sh`) — cross-reference map, orphan detection, duplicate detection with --summary, --json, --graph modes
- **105 domain rules** analyzed, 25 orphans identified (23%), 0 duplicates
- **CI integration** — --ci mode with 20% orphan threshold gate

## [2.65.0] — 2026-03-08

### Added — Era 94: CI Pipeline Complete

Extended CI validation covering all workspace components.

- **CI extended checks** (`scripts/ci-extended-checks.sh`) — 5 validation categories: skills frontmatter, rule dependencies, hook safety flags, agent file size, docs link validation
- **Added to CI workflow** — runs automatically on PR and push to main
- **All 5 checks passing** — 67 skills, 105 rules, 17 hooks, 33 agents, 44 docs validated

## [2.64.0] — 2026-03-08

### Added — Era 93: Agent Accountability

Agent activity tracking and accountability dashboard.

- **Agent activity dashboard** (`scripts/agent-activity.sh`) — reads JSONL traces from agent-trace-log hook, modes: --summary, --json, --recent N
- **6 BATS tests** for agent activity dashboard (`tests/structure/test-agent-activity.bats`)
- **22 test suites, 199 tests** — all passing

## [2.63.0] — 2026-03-08

### Added — Era 92: MCP Server Specification

Model Context Protocol server specification for pm-workspace.

- **MCP server spec** (`mcp/pm-workspace-server.json`) — 8 tools (sprint-status, pbi-decompose, security-scan, coverage-report, workspace-health, component-index, risk-score, capacity-check), 3 resources, 2 prompts
- **Follows MCP 1.0** specification standard

## [2.62.0] — 2026-03-08

### Added — Era 91: Alpha Skills Maturation

Systematic upgrade of alpha-maturity skills to beta.

- **13 skills upgraded** alpha → beta (banking-architecture, context-optimized-dev, evaluations-framework, google-sheets-tracker, headroom-optimization, non-engineer-templates, postmortem-training, resource-references, sdlc-state-machine, semantic-memory, session-recording, skills-marketplace, visual-quality)
- **Distribution**: 51 stable, 15 beta, 1 alpha

## [2.61.0] — 2026-03-08

### Added — Era 90: Technical Documentation

Comprehensive technical documentation for workspace internals.

- **HOOKS.md** — all 17 hooks documented with exit codes, types, test coverage
- **AGENTS.md** — all 33 agents with decision tree and category grouping
- **ARCHITECTURE.md** — component hierarchy, data flow, directory structure
- **TROUBLESHOOTING.md** — common issues, debugging commands, hook inspection

## [2.60.0] — 2026-03-08

### Added — Era 89: Hook Coverage 100%

Complete test coverage for all 17 hooks.

- **11 new BATS test suites** — 69 new tests covering all previously untested hooks
- **Fixed hook safety flags** — `set -uo pipefail` (not `-euo`) for all hooks
- **Fixed pipefail edge cases** — `|| true` guards for grep pipelines on empty input
- **21 suites, 193 tests** — 100% hook coverage

## [2.59.0] — 2026-03-08

### Added — Era 88: Script Hardening

Security hardening across all hooks and test scripts.

- **`set -uo pipefail`** added to 14 hooks that were missing safety flags
- **Replaced `eval`** with `bash -c` in 44 test scripts
- **Fixed hardcoded paths** — `/home/monica/savia` → `$ROOT` in 5 scripts
- **5 BATS tests** for script safety validation

## [2.58.0] — 2026-03-07

### Added — Era 87: Strategic Vision & Health Dashboard

Workspace health metrics and strategic roadmap consolidation.

- **Workspace health dashboard** (`scripts/workspace-health.sh`) — 6-dimension health scoring: skill completeness, command completeness, maturity distribution, test coverage, security posture, documentation
- **Current health**: 84% (Grade B)
- **Roadmap update** — Eras 79-87 stability roadmap added to docs/ROADMAP.md
- **JSON/CI modes** — machine-readable output, 60% threshold gate

## [2.57.0] — 2026-03-07

### Added — Era 86: Vulnerability Scanner

Deep security analysis for workspace scripts.

- **Vulnerability scanner** (`scripts/vuln-scan.sh`) — 8-section analysis: eval usage, unquoted vars, temp files, HTTP security, hardcoded paths, permissions, strict mode, input validation
- **Severity separation** — vulnerabilities block CI, warnings are informational
- **CI integration** — added to bats-tests workflow

## [2.56.0] — 2026-03-07

### Added — Era 85: Mock Mode

Reusable mock environment for offline testing.

- **Mock library** (`scripts/lib/mock-env.sh`) — mock functions for Azure DevOps, MCP servers, sprint data, team data
- **Auto-detection** — `--mock` flag or `PM_MOCK` environment variable
- **8 BATS tests** validating all mock functions

## [2.55.0] — 2026-03-07

### Added — Era 84: Discoverability

Component index and onboarding documentation.

- **Index generator** (`scripts/generate-index.sh`) — `--summary`, `--json`, `--markdown` modes for all 454 commands, 67 skills, 33 agents, 17 hooks
- **Quick-start guide** (`docs/QUICK-START.md`) — 5-minute onboarding

## [2.54.0] — 2026-03-07

### Added — Era 83: Maturity Levels

Maturity classification for all workspace skills.

- **Maturity levels** — `alpha|beta|stable` field added to all 67 skill SKILL.md files
- **Results**: 51 stable, 2 beta, 14 alpha
- **Frontmatter standardization** — 14 skills without frontmatter now have proper `---` blocks
- **Classification script** (`scripts/add-maturity-levels.sh`)

## [2.53.0] — 2026-03-07

### Added — Era 82: Security Hardening

Security audit tooling and credential protection.

- **Security scan** (`scripts/security-scan.sh`) — 5-section audit: credential patterns, hardcoded URLs, security infrastructure, hook test coverage, .gitignore completeness
- **CI integration** — `--ci` mode gates on findings (warnings informational)
- **Hardened .gitignore** — added `.env.*`, `*.p12`, `*.pfx`, credential/secret wildcard patterns
- **Verbose/summary modes** — `--verbose` for full pass/fail detail, default summary for quick checks

## [2.52.0] — 2026-03-07

### Added — Era 81: Coverage Metrics

Comprehensive coverage reporting across all workspace components.

- **Coverage report** (`scripts/coverage-report.sh`) — weighted scoring across hooks, commands, skills, test quality
- **Multiple output modes** — `--summary`, `--json`, `--markdown`, `--ci` (60% threshold gate)
- **CI integration** — coverage report runs in bats-tests workflow
- **Current metrics**: hooks 35%, commands 100%, skills 98%, overall 65%

## [2.51.0] — 2026-03-07

### Added — Era 80: Test Quality Upgrade

Test quality audit tooling and structural integrity tests.

- **2 new BATS suites** — workspace-structure (20 tests: settings.json, frontmatter, hooks, skills, OSS files) + changelog-integrity (7 tests: semver, ordering, Era refs)
- **BATS in CI** — GitHub Actions workflow now runs all BATS tests on every push/PR
- **Test quality audit** (`scripts/audit-test-quality.sh`) — classifies 104 test files by level (L0-L3), reports 62% real tests
- **Total test count**: 8 suites, 111 tests, all passing

## [2.50.0] — 2026-03-07

### Added — Era 79: BATS Testing Framework

Comprehensive unit testing infrastructure for all Claude Code hooks using BATS (Bash Automated Testing System).

- **6 test suites, 84 tests** covering all 6 PreToolUse hooks:
  - `test-block-credential-leak.bats` (19 tests) — 11 credential patterns + safe commands
  - `test-validate-bash-global.bats` (17 tests) — 7 dangerous command gates
  - `test-agent-dispatch-validate.bats` (10 tests) — 5 dispatch context validations
  - `test-block-force-push.bats` (9 tests) — force push, main/master push, amend, reset
  - `test-block-infra-destructive.bats` (11 tests) — terraform, az, aws, kubectl destructive ops
  - `test-tdd-gate.bats` (18 tests) — TDD enforcement for production code
- **Test runner** (`tests/run-all.sh`) with TAP output, filtering, and suite-level reporting
- **Test fixtures** — reusable JSON inputs for hook testing
- Phase 1 of 9-phase stability roadmap

## [2.49.0] — 2026-03-07

### Added — Era 78: Agent Dispatch Validation

Pre-dispatch hook system that validates subagent prompts contain required project context before execution.

- **`agent-dispatch-validate.sh` hook** — PreToolUse hook (matcher: Task) that inspects prompts sent to subagents.
- **`agent-dispatch-checklist.md` rule** — Reference checklist per task type (commands, CHANGELOG, skills, rules, git ops).
- **Blocking validation** — Missing critical context (frontmatter for commands, ordering for CHANGELOG) blocks dispatch (exit 2).
- **Warning validation** — Missing recommended context (example references, CI mention) warns but allows (exit 0).
- **settings.json updated** — Registered new PreToolUse hook for Task matcher with 5s timeout.

### Changed

- Prevents recurrence of Era 77 frontmatter issue where agents created commands without required fields.

## [2.48.0] — 2026-03-07

### Added — Era 77: Postmortem Training Template

Postmortem process focused on reasoning heuristics rather than root cause.

- **`/postmortem-create {incident}`** — Guided postmortem with 7-section template.
- **`/postmortem-review [incident-id]`** — Analyze patterns and recurring gaps.
- **`/postmortem-heuristics [module]`** — Compile debugging playbook from postmortems.
- **`postmortem-training` skill** — Full integration with comprehension reports.
- **`postmortem-policy` rule** — Mandatory for MTTR > 30 minutes.

### Changed

- Énfasis en Diagnosis Journey (paso a paso del razonamiento) en lugar de resumen ejecutivo.

## [2.47.0] — 2026-03-07

### Added — Era 76: Templates for Non-Engineers

Guided interfaces for POs, stakeholders, and QA. Simplified wizards, plain language, no technical jargon required.

- **`/po-wizard {action}`** — PO interface: plan-sprint, prioritize, acceptance-criteria, review.
- **`/stakeholder-view {view}`** — Executive dashboard: summary, milestones, risks, budget.
- **`/qa-wizard {action}`** — QA interface: test-plan, bug-report, validate, regression.
- **`non-engineer-templates` skill** — 3 personas, 6 templates, step-by-step guided flows.

## [2.46.0] — 2026-03-07

### Added — Era 75: Semantic Memory Layer

Vector-based similarity search over project memory. Three memory layers: session (ephemeral), project (JSONL), semantic (vector index).

- **`/memory-search {query}`** — Natural language search over indexed memories. Top-5 results with relevance scores.
- **`/memory-index {project}`** — Build/rebuild semantic vector index from agent-notes, lessons, decisions, postmortems.
- **`/memory-stats {project}`** — Index statistics: entry count, last updated, coverage per source.
- **`semantic-memory` skill** — Lightweight JSON vector store, embedding-based search, incremental updates.

## [2.45.0] — 2026-03-07

### Added — Era 74: Session Recording

Record, replay, and export agent sessions for auditing, documentation, and training.

- **`/record-start`** — Begin recording all session actions. Creates unique session ID, stores events in JSONL format.
- **`/record-stop`** — Stop recording. Summary: duration, events count, files modified.
- **`/record-replay {session-id}`** — Replay recorded session with timeline.
- **`/record-export {session-id}`** — Export as markdown report to output/recordings/.
- **`session-recording` skill** — Records commands, files modified, API calls, decisions, agent-notes with timestamps.

## [2.44.0] — 2026-03-07

### Added — Era 73: PM-Workspace as MCP Server

Expose project state as MCP server. External tools can query projects, tasks, metrics and trigger PM operations.

- **`/mcp-server-start {mode}`** — Start MCP server: local (stdio) or remote (SSE). Optional `--read-only`.
- **`/mcp-server-status`** — Server status: connections, requests, uptime.
- **`/mcp-server-config`** — Configure exposed resources, tools, and prompts.
- **`pm-mcp-server` skill** — 6 resources, 4 tools, 3 prompts. Token auth for remote, read-only mode.

## [2.43.0] — 2026-03-07

### Added — Era 72: Agent Skills Marketplace

Integration with claude-code-templates marketplace (5,788+ components). Browse, install, and manage Claude Code extensions.

- **`/marketplace-search {query}`** — Search marketplace by keyword, type, or category.
- **`/marketplace-install {component}`** — Install component from marketplace. Validates compatibility.
- **`/marketplace-publish`** — Publish pm-workspace components to marketplace.
- **`skills-marketplace` skill** — Marketplace integration, compatibility checks, version management.
- **`component-marketplace` rule** — 6 component types: agents, commands, hooks, MCPs, settings, skills.

## [2.42.0] — 2026-03-07

### Added — Era 71: Evaluations Framework

Systematic evaluation of agent outputs with 5 built-in evaluation types, scoring rubrics, trend analysis, and automated regression detection.

- **`/eval-run {eval-name}`** — Execute evaluation: pbi-quality, spec-quality, estimation-accuracy, review-quality, assignment-quality.
- **`/eval-report {eval-name}`** — Display results and trends. Filter by `--sprint`, analyze with `--trend`.
- **`/eval-create`** — Define custom evaluations with personalized rubrics.
- **`evaluations-framework` skill** — 5 eval types with scoring rubrics, automated scheduling, trend analysis, regression detection.
- **`eval-policy` rule** — Post-sprint evaluation, monthly evals, 10% regression alert threshold.

## [2.41.0] — 2026-03-07

### Added — Era 70: Knowledge Graph for PM Entities

Graph-based representation of PM entities (projects, PBIs, specs, teams, decisions) with relationship queries and impact analysis.

- **`/graph-build {project}`** — Build knowledge graph from project artifacts.
- **`/graph-query {query}`** — Query entity relationships and dependencies.
- **`/graph-impact {entity}`** — Analyze impact of changes to an entity across the graph.
- **`knowledge-graph` skill** — Entity extraction, relationship mapping, traversal queries.

## [2.40.0] — 2026-03-07

### Added — Era 69: SDLC State Machine

Formal state machine for development lifecycle with 8 states, configurable gates, and audit trail.

- **`/sdlc-status {task-id}`** — Current state, available transitions, gate requirements.
- **`/sdlc-advance {task-id}`** — Evaluate gates and advance to next state.
- **`/sdlc-policy {project}`** — View and configure gate policies per project.
- **`sdlc-state-machine` skill** — 8 states: BACKLOG→DISCOVERY→DECOMPOSED→SPEC_READY→IN_PROGRESS→VERIFICATION→REVIEW→DONE.
- **`sdlc-gates` rule** — Default gate configuration with per-project overrides. Full audit trail.

## [2.39.0] — 2026-03-07

### Added — Era 68: Google Sheets Tracker

Google Sheets as lightweight task database for POs and stakeholders. Bidirectional sync with Azure DevOps.

- **`/sheets-setup {project}`** — Create tracking spreadsheet with Tasks, Metrics, and Risks sheets.
- **`/sheets-sync {project} push|pull|both`** — Bidirectional sync between Azure DevOps and Sheets.
- **`/sheets-report {project}`** — Generate sprint metrics from task data.
- **`google-sheets-tracker` skill** — 3-sheet structure, bidirectional sync, MCP integration.

## [2.38.0] — 2026-03-07

### Added — Era 67: Resource References (@)

Referenciable resources with @ notation for automatic context inclusion. Lazy resolution, session caching, 6 resource types.

- **`/ref-list {project}`** — List available resource references with patterns and examples.
- **`/ref-resolve {reference}`** — Manually resolve and preview a resource reference.
- **`resource-references` skill** — 6 resource types: @azure:workitem, @project, @spec, @team, @rules, @memory.
- **`resource-resolution` rule** — Lazy resolution, session cache, max 5 simultaneous, approved sources only.

## [2.37.0] — 2026-03-07

### Added — Era 66: Headroom Context Optimization

Token compression framework achieving 47-92% reduction. Context budgets per operation.

- **`/headroom-analyze {project}`** — Analyze token usage per context block with compression opportunities.
- **`/headroom-apply {project}`** — Apply compressions. Preview default, `--apply` to persist changes.
- **`headroom-optimization` skill** — 5-phase compression: analyze → identify → compress → measure → report.
- **`context-budget` rule** — Max token budgets per operation type. Auto-alert if exceeded.

## [2.36.0] — 2026-03-07

### Added — Era 65: Managed Content Markers

Safe regeneration pattern for auto-generated content. Managed markers protect manual content while allowing automatic updates.

- **`/managed-sync [file]`** — Regenerate managed sections. Preview mode by default, `--apply` to write changes.
- **`/managed-scan`** — Scan workspace for all managed markers with freshness status.
- **`managed-content` skill** — Marker-based content management: scan → regenerate → validate.
- **`managed-content` rule** — All auto-generated content must use markers.

## [2.35.0] — 2026-03-07

### Added — Era 64: Verification Lattice

5-layer verification pipeline: deterministic → semantic → security → agentic → human.

- **`/verify-full {task-id}`** — Run all 5 verification layers. Progressive results, stop on critical failure.
- **`/verify-layer {N} {task-id}`** — Run specific layer for debugging.
- **`verification-lattice` skill** — 5 layers with dedicated agents.
- **`verification-policy` rule** — Layers 1-3 mandatory, L4 for risk>50, L5 always except risk<25.

## [2.34.0] — 2026-03-07

### Added — Era 63: Risk Scoring & Intelligent Escalation

Risk-based review routing with automatic score calculation (0-100) and 4 review levels.

- **`/risk-assess {task-id}`** — Calculate risk score with factor breakdown.
- **`/risk-policy`** — View and update risk scoring thresholds per project.
- **`risk-scoring` skill** — 4-phase pipeline: collect signals → calculate score → route review → generate report.
- **`risk-escalation` rule** — Configurable thresholds, PM override, audit trail.

## [2.33.0] — 2026-03-07

### Added — Era 62: DAG Scheduling (Parallel Agent Orchestration)

Dependency-graph-based execution for SDD pipeline. Parallelizes independent phases, reducing execution time by 30-40%.

- **`/dag-plan {task-id}`** — Visualize execution DAG, critical path, and estimated time savings.
- **`/dag-execute {task-id}`** — Execute SDD pipeline with parallel agents.
- **`dag-scheduling` skill** — 6-phase pipeline: parse DAG → critical path → scheduling → execution → sync → reporting.
- **`parallel-execution` rule** — Max 5 concurrent agents, worktree isolation, conflict prevention.

## [2.32.0] — 2026-03-07

### Added — Era 61: Google Chat Notifier

Rich notifications for PM events via Google Chat webhooks.

- **`/chat-setup`** — Guide webhook configuration and send test message.
- **`/chat-notify {type} {project}`** — Send formatted notification: sprint-status, deployment, escalation, standup, custom.
- **`google-chat-notifier` skill** — 5 message types with Google Chat card format.

## [2.31.0] — 2026-03-07

### Added — Era 60: Google Drive Memory

Bidirectional sync for non-technical users. Google Drive as persistence alternative to Git.

- **`/drive-setup`** — Create Drive folder structure with role-based permissions.
- **`/drive-sync {action}`** — Push/pull/status operations for local↔Drive sync.
- **`google-drive-memory` skill** — 4-phase pipeline: setup → sync → permissions → MCP. Timestamp-based conflict resolution.

## [2.30.0] — 2026-03-07

### Added — Era 59: MCP Tool Search & Smart Routing

Intelligent tool discovery for 400+ commands. Auto-categorization, keyword routing, and usage-based prioritization.

- **`tool-search-config` rule** — 8 command categories with routing heuristics. Auto-activates when tools exceed 128 in context.
- **`/tool-search {query}`** — Search commands, skills, and agents by keyword. Discovers tools across 400+ commands.
- **`/tool-catalog [category]`** — Categorized tool catalog with counts. Navigate the full command library.
- **`smart-routing` skill** — Intent classification, frequency tracking, Top-20 algorithm for always-available commands.

---

## [2.29.0] — 2026-03-07

### Added — Era 58: DOMAIN.md per Skill (Clara Philosophy)

Multi-level documentation layer: SKILL.md defines the "how", DOMAIN.md defines the "why" and domain context.

- **DOMAIN.md** files added to: pbi-decomposition, product-discovery, rules-traceability, spec-driven-development, capacity-planning, sprint-management, azure-devops-queries, scheduled-messaging, context-caching, code-comprehension-report.
- **`clara-philosophy` rule** — Documentation standard: every skill requires SKILL.md (how) + DOMAIN.md (why). Max 60 lines.
- **`/plugin-validate` enhancement** — Checks for DOMAIN.md presence, max line count, required sections.

## [2.28.0] — 2026-03-07

### Added — Era 57: Code Comprehension Report

Automatic mental model generation after SDD implementation. Addresses AI-generated code opacity by documenting decisions, failure heuristics, and 3AM debugging guides.

- **`/comprehension-report {task-id}`** — Generate mental model report: architecture decisions, flow diagram (mermaid), failure heuristics, implicit dependencies, 3AM debugging guide. Output saved to `output/comprehension/YYYYMMDD-{task-id}-mental-model.md`.
- **`/comprehension-audit {project}`** — Scan recent implementations, identify missing mental models, report coverage (X of Y tasks have reports). Prioritize by risk level.
- **`code-comprehension-report` skill** — 7-phase pipeline: Phase 1 collect data → Phase 2 architecture decisions → Phase 3 flow diagram → Phase 4 failure heuristics → Phase 5 implicit dependencies → Phase 6 3AM debugging guide → Phase 7 generate report.
- **`code-comprehension` rule** — Every dev-session completion SHOULD trigger comprehension report. Code Review E1 includes "debuggeable at 3AM?" criterion. Integration with postmortem process: link comprehension reports to incident analysis, update on failures.

---

## [2.27.0] — 2026-03-07

### Added — Era 56: Scheduled Messaging Integration

Wizard-guided setup for Claude Code Scheduled Tasks with automatic result delivery to messaging platforms.

- **`/scheduled-setup {platform}`** — Interactive wizard: platform selection → credential config → module generation → test → task creation. Supports: Telegram, Slack, Teams, WhatsApp (Twilio), NextCloud Talk.
- **`/scheduled-test {platform}`** — Send test message to verify integration.
- **`/scheduled-create`** — Create scheduled task with `--notify {platform}` and `--cron "schedule"`.
- **`/scheduled-list`** — List tasks with notification config and status.
- **`scheduled-messaging` skill** — 5-phase pipeline, 5 platform adapters, 5 pre-built templates (standup, blocker, burndown, deploy, security).
- **`scripts/notify-{platform}.sh`** — Auto-generated notification modules per platform.

---

## [2.26.0] — 2026-03-07

### Added — Era 55: Prompt Caching Strategy

Context loading optimization for prompt caching. Reduces input token costs by ordering stable content first with cache breakpoints.

- **`prompt-caching` rule** — 4-level caching hierarchy: PM globals → project context → skill content → dynamic request. Ordering rules and TTL guidance.
- **`/cache-optimize {project}`** — Analyze context loading order and suggest reordering for optimal cache hit rates. Shows estimated token savings.
- **`context-caching` skill** — Caching templates for common operations (PBI decomposition, spec generation, dev session). Token measurement patterns.

## [2.25.0] — 2026-03-07

### Added — Era 54: Plugin Bundle Packaging

Package PM-Workspace as distributable Claude Code plugin with validation and export commands.

- **`.claude-plugin/plugin.json`** — Plugin manifest with capabilities declaration, dependencies, and install paths.
- **`/plugin-export`** — Package current workspace as distributable plugin. Supports `--components` for partial export.
- **`/plugin-validate`** — Validate plugin structure: skills, agents, commands integrity, PII check, line limits.
- **`plugin-packaging` skill** — Packaging logic, validation rules, version management.

---

## [2.24.0] — 2026-03-07

### Added — Era 53: Business Rules to PBI Mapping

Bridges the gap between business rules documentation and PBI creation. Automatic traceability matrix RN↔PBI with coverage analysis.

- **`/pbi-from-rules {project}`** — Parse reglas-negocio.md, cross-reference with Azure DevOps PBIs, identify coverage gaps, propose new PBIs.
- **`/pbi-from-rules-report {project}`** — Generate traceability matrix report without creating PBIs.
- **`rules-traceability` skill** — 7-phase pipeline: parse rules → query PBIs → build matrix → gap analysis → propose PBIs → create (with confirmation) → report.
- Integrates with `product-discovery` for complex features: auto-triggers JTBD + PRD when rule requires feature analysis.

---

---

## [2.23.1] — 2026-03-06

### Added — Guide: Project from Scratch

Step-by-step guide for PMs to start a project from scratch: client profile, team, architecture, business rules, specs, test requirements, and implementation with Dev Session Protocol. Works across Azure DevOps, Jira, and Savia Flow.

- **`docs/guides/guide-project-from-scratch.md`** (ES) — 8-step workflow with concrete examples: client profile, CLAUDE.md, equipo.md, reglas-negocio.md, PBI decomposition, spec generation, test strategy, dev session orchestration.
- **`docs/guides_en/guide-project-from-scratch.md`** (EN) — English translation.
- Updated guides index (ES + EN) with new entry highlighted.

---

## [2.23.0] — 2026-03-06

### Added — Era 52: Dev Session Protocol (Context-Optimized Development)

5-phase development protocol for producing high-quality code within ~40% free context window. Disk-based state persistence between phases.

- **`/dev-session`** — Orchestrate spec implementation: start → next (per slice) → status → review → abort. Session state in `output/dev-sessions/`.
- **`/spec-slice`** — Break specs into context-optimized slices (≤3 files, ≤15K tokens, ≤1 business rule group). Dependency detection, critical path, YAML output.
- **`dev-orchestrator` agent** — Sonnet-based planner for slice analysis, token budgets, risk assessment.
- **`context-optimized-dev` skill** — Subagent delegation patterns, context priming templates, anti-patterns, token estimation formulas.
- **`dev-session-protocol` rule** — 5-phase protocol definition with per-phase token budgets.

---

## [2.22.0] — 2026-03-06

### Changed — Era 51: Context Window Optimization

Systematic reduction of auto-loaded context (~20,000 tokens recovered per conversation, ~10% of context window).

- **Language rule dedup** — Merged 4 duplicated pairs (Python, Java, Go, TypeScript conventions into rules files). 4 files deleted.
- **Vertical rules → skills** — Moved 8 vertical-specific rules from `rules/domain/` to `skills/references/` for on-demand loading.
- **csharp-rules.md** — Compressed from 1,323 to 206 lines (84% reduction). All 65 SonarQube IDs + 12 ARCH patterns preserved in tabular format.
- **Conditional loading** — Added `paths:` frontmatter to 17 domain rules (messaging, frontend, AI/HR, IaC, hub, etc.).
- **Worktree cleanup** — Removed abandoned `keen-chebyshev` worktree (2.3 MB).

---

## [2.21.0] — 2026-03-06

### Added — Era 50: Multimodal Quality Gates

Visual regression testing and wireframe validation using Claude's native vision capabilities (JPEG/PNG/WebP, up to 8000×8000px).

- **`/visual-qa`** — Screenshot capture, compare against reference, regression detection, QA report. Visual match score 0-100.
- **`/wireframe-check`** — Register wireframes, validate implementation, detect gaps, extract UI specs from mockups.
- **`/visual-regression`** — Baseline management, regression testing, pixel-level diffing, approval workflow. 5% default tolerance.
- **`visual-qa-agent`** — Sonnet-based vision agent (5-phase: input→analysis→scoring→classification→report).
- **`visual-quality` skill** — Defect taxonomy, WCAG contrast checks, screenshot best practices, comparison methodology.
- **`visual-quality-gates` rule** — Gate levels: auto-pass (≥90), informational (≥80), blocking (<60). Privacy-first.

---

## [2.20.3] — 2026-03-06

### Added — Era 49: Connectors vs MCP Integration Architecture Decision

ADR confirming Claude Connectors = MCP servers with managed OAuth. Connector-first strategy for end users, MCP-first for developers/CI. No code changes — documentation-only.

- **ADR** — `docs/propuestas/adr-connectors-vs-mcp.md`: Full technical comparison, 11/12 tools have official Connectors, Azure DevOps remains MCP-only.
- **Connectors quickstart** — `docs/guides/guide-connectors-quickstart.md` (ES+EN): 1-click setup guide, verification, per-project configuration.
- **Integration catalog** — `docs/recommended-mcps.md`: Reorganized with Connectors-first + MCP community. Added coverage table mapping Connectors → pm-workspace commands.
- **connectors-config.md** — Added `ENABLE_CLAUDEAI_MCP_SERVERS` auto-sync documentation and fallback message for tools without Connector.
- **ROADMAP.md** — Added Era 49, moved Connectors evaluation from backlog to completed.

---

## [2.20.2] — 2026-03-06

### Fixed — Colon-to-Kebab Command Reference Migration

Replaced all legacy colon-style command references (`/bias:check`, `/score:diff`, `/sprint:review`, etc.) with kebab-case (`/bias-check`, `/score-diff`, `/sprint-review`) across 12 files. Claude Code does not support colons in command names.

- **bias-check.md, score-diff.md** — Added missing YAML frontmatter and fixed internal `/command:name` references.
- **agents-catalog.md, equality-shield.md, scoring-curves.md, severity-classification.md** — Updated all command references from colon to kebab-case.
- **ROADMAP.md, CHANGELOG.md** — Migrated historical references.
- **guides/guide-enterprise-gap-analysis.md** (ES+EN) — Updated command tables.
- **docs/estudio-equality-shield.md, docs/politica-igualdad.md** — Updated references.

---

## [2.20.1] — 2026-03-06

### Fixed — Documentation Consistency Audit

Full documentation audit to align all stats and features with current state after Eras 43-48.

- **README.md / README.en.md** — Updated stats: 396+ commands (was 360+), 31 agents (was 27), 41 skills (was 38), 16 hooks (was 14), 14 guides (was 13). Added new feature sections: universal accessibility, industry verticals, adversarial security, adaptive intelligence.
- **CLAUDE.md** — Synchronized all resource counts: commands (396+), agents (31), skills (41), hooks (16).
- **agents-catalog.md** — Added 4 missing agents: `frontend-test-runner`, `security-attacker`, `security-defender`, `security-auditor`. Updated count: 31. Added adversarial security flow.
- **ROADMAP.md** — Corrected agent/skill counts in Era 46 (41 skills), Era 47 (31 agents, 41 skills), Era 48 (31 agents, 41 skills, 16 hooks).

---

## [2.20.0] — 2026-03-06

### Added — More Industry Verticals: Insurance, Retail, Telco (Era 48)

12 domain-specific commands for 3 additional industries.

- **Insurance (4 commands):** `/insurance-policy` (POL-NNN, lifecycle: create/renew/cancel, endorsement tracking), `/insurance-claim` (CLM-NNN, investigation→resolution, loss ratio analytics), `/solvency-report` (Solvency II: SCR/MCR/own funds, RAG indicator), `/underwriting-rule` (criteria definition, accept/refer/decline evaluation, audit trail).
- **Retail/eCommerce (4 commands):** `/product-catalog` (SKU-NNNN, pricing, stock, CSV/JSON export), `/order-track` (ORD-NNNN, status lifecycle, returns, revenue analytics), `/inventory-manage` (multi-warehouse, reorder points, dead stock alerts), `/promotion-engine` (PROMO-NNN, discount/BOGO/bundle/coupon, ROI analysis).
- **Telco (4 commands):** `/service-catalog-telco` (SVC-NNN, voz/datos/fibra/tv, SLA, bundling), `/network-incident` (NI-NNNN, eTOM classification, SLA compliance), `/subscriber-lifecycle` (SUB-NNNN, churn-risk scoring, ARPU/LTV), `/capacity-forecast-telco` (utilization, trend-based forecasting, expansion planning).

### Changed

- **ROADMAP.md** — Added Era 48 entry. Removed "More industry verticals" from backlog (implemented). Updated stats: 396+ commands.

---

## [2.19.0] — 2026-03-06

### Added — Adversarial Security Pipeline (Era 47)

Red Team / Blue Team / Auditor pattern for systematic security testing.

- **3 security agents**: `security-attacker` (Red Team: OWASP Top 10, CWE Top 25, dependency audit, VULN-NNN structured findings), `security-defender` (Blue Team: patches, hardening, NIST/CIS, FIX-NNN structured corrections), `security-auditor` (independent evaluation, security score 0-100, gap analysis, executive summary).
- **`/security-pipeline`** command — 3-phase sequential orchestration: Attack → Defend → Audit. Scopes: full, api, deps, config, secrets. Outputs per-project: vulns, fixes, and audit report.
- **`/threat-model`** command — STRIDE/PASTA threat modeling with asset inventory, threat analysis (probability × impact), control mapping, gap identification, prioritized recommendations.
- **`adversarial-security.md`** rule — Severity classification (critical/high/medium/low/info), scoring formula, agent independence, compliance integration (critical/high block main merge).
- **`adversarial-security/SKILL.md`** skill — CVSS scoring, STRIDE mapping table, OWASP Top 10 checklist, dependency audit commands (npm/pip/dotnet).

### Changed

- **ROADMAP.md** — Added Era 47 entry. Moved adversarial security from backlog to implemented. Updated stats: 384+ commands, 30 agents, 40 skills.

---

## [2.18.0] — 2026-03-06

### Added — Skill Evaluation Engine & Instincts System (Era 46)

Self-learning intelligence layer for automatic skill recommendation and adaptive behavior patterns.

- **`/skill-eval`** command — Analyzes prompts against available skills with composite scoring (keywords 40% + project context 30% + history 30%). Subcommands: analyze, recommend, activate, history, tune. Auto-detects 7 project types (software, research, hardware, legal, healthcare, nonprofit, education).
- **`/instinct-manage`** command — Manages Savia's learned behavior patterns with confidence scoring. Subcommands: list, add, disable, stats, decay, export. Confidence: initial 50%, +3% success, -5% failure, floor 20%, ceiling 95%. Decay: -5% per 30 days without use.
- **`skill-auto-activation.md`** rule — Suggests skills above 70% relevance threshold. Max 2 suggestions per interaction. Respects focus-mode. Learns from rejections (3 consecutive → stops suggesting).
- **`instincts-protocol.md`** rule — Lifecycle: detect ≥3 repetitions → propose → create → reinforce/penalize → decay → review. 5 categories: workflow, preference, shortcut, context, timing.
- **`skill-evaluation/SKILL.md`** skill — Prompt tokenization, 7 project-type detection, project→skills mapping, instinct integration (+20 boost for high-confidence instincts).
- **Registries**: `eval-registry.json` (skill activations), `instincts/registry.json` (instinct entries).

### Changed

- **ROADMAP.md** — Added Era 46 entry. Moved instincts + skill evaluation from backlog to implemented. Updated stats: 382+ commands, 39 skills.

---

## [2.17.0] — 2026-03-06

### Added — Vertical-Specific Commands: 5 Industry Domains (Era 45)

20 domain-specific commands implementing all gap proposals from Era 23 guide writing. Every command follows pm-workspace conventions (≤150 lines, YAML frontmatter, project-scoped storage).

- **Research Lab (5 commands):** `/experiment-log` (hypothesis→run→result→compare with EXP-NNN IDs), `/biblio-search` (DOI/BibTeX import, APA/IEEE/Vancouver citation export), `/dataset-version` (SHA256 integrity, DVC/Git LFS support), `/grant-track` (lifecycle: draft→submitted→review→approved/rejected, deadline alerts), `/ethics-protocol` (IRB tracking with experiment cross-references, renewal lineage).
- **Hardware Lab (3 commands):** `/hw-bom` (component registry, cost breakdown by category, CSV import/export), `/hw-revision` (REV-A/B/C lifecycle, BOM snapshots, tags: prototype/pilot/production), `/compliance-matrix` (CE/FCC/UL/RoHS/ISO, evidence linking, gap analysis reports).
- **Legal Firm (5 commands):** `/legal-deadline` (procesal/contractual/regulatorio, auto-alerts <48h/<7d/<14d), `/court-calendar` (ICS import/export, scheduling conflict detection), `/conflict-check` (client/matter screening, privacy-preserving reports), `/legal-template` (demanda/contestación/recurso/contrato/poder, variable substitution), `/billing-rate` (hourly/fixed/contingency/mixed, invoice generation).
- **Healthcare (5 commands):** `/pdca-cycle` (plan→do→check→act quality improvement cycles), `/incident-register` (severity classification, 5-why root cause analysis, GDPR-compliant), `/accreditation-track` (JCI/EFQM/ISO 9001/15189, evidence→requirement linking), `/training-compliance` (mandatory training, expiry alerts <30d), `/health-kpi` (define/measure/trend/dashboard, RAG status alerts).
- **Nonprofit (2 commands):** `/impact-metric` (SDG-aligned, output/outcome/impact tiers, donor reports), `/volunteer-manage` (register/availability/hours, retention tracking, GDPR/LOPD).

### Changed

- **ROADMAP.md** — Era 23 gap table marked as ✅ implemented. Added Era 45 entry. Updated stats: 380+ commands.

---

## [2.16.1] — 2026-03-06

### Changed — Repository Cleanup & Link Fixes

- **Removed** 5 obsolete files: `docs/roadmap-v1.7.0.md` (subsumed by ROADMAP.md Era 22), `docs/guia-adopcion-pm-workspace.docx` (replaced by ADOPTION_GUIDE.md), `docs/guia-incorporacion-lenguajes.docx` (replaced by .md equivalent), `docs/context-optimization-completed.md` and `docs/context-optimization-roadmap.md` (work already integrated).
- **Fixed** 8 broken links in English quick-starts (`quick-starts_en/`) — referenced Spanish filenames (`02-estructura`, `04-uso-sprint-informes`, `06-configuracion-avanzada`, `10-kpis-reglas`) instead of English (`02-structure`, `04-usage-sprint-reports`, `06-advanced-config`, `10-kpis-rules`).
- **Fixed** 2 broken links in enterprise consultancy guides pointing to non-existent `quick-start.md`.
- **Added** `docs/guides_en/guide-accessibility.md` — English translation of the accessibility step-by-step guide (was missing from bilingual pair).
- **Updated** references in `ROADMAP.md` and `CHANGELOG.md` to reflect removed files.

---

## [2.16.0] — 2026-03-06

### Added — Automated Rule Compliance Verification (Era 44)

Pre-commit gate that blocks commits violating domain rules, independent of LLM context.

- **compliance-gate.sh**: PreToolUse hook that runs compliance checks before every `git commit`. Blocks (exit 2) on violations instead of warning. Registered in `.claude/settings.json`.
- **runner.sh**: Orchestrator in `.claude/compliance/` running 4 check scripts on staged files. Supports `--all` mode for full repo scan.
- **check-changelog-links.sh**: Verifies every `## [X.Y.Z]` heading has a matching `[X.Y.Z]: URL` comparison link at the end of CHANGELOG.md.
- **check-file-size.sh**: Enforces ≤150 lines for commands, rules, and skills. Excludes languages/, references/, CHANGELOG.
- **check-command-frontmatter.sh**: Validates YAML frontmatter on newly staged commands.
- **check-readme-sync.sh**: Verifies README.md/README.en.md ≤150 lines and bilingual sync warning.
- **compliance-check.md**: `/compliance-check` command for manual verification.
- **RULES-COVERED.md**: Coverage manifest — 4 rules automated, extensible framework for adding more.

Fix: added missing `[2.15.0]` comparison link in CHANGELOG.md.

Tests: `bash .claude/compliance/runner.sh --all` — 4/4 checks passed. CI: 14/14 green.

---

## [2.15.0] — 2026-03-06

### Added — Universal Accessibility: Guided Work & Inclusive Design (Era 43)

Comprehensive accessibility system so people with disabilities can work in tech companies using pm-workspace. Central piece: Savia as digital job coach.

- **guided-work.md**: `/guided-work --task`, `--continue`, `--status`, `--pause`. Savia decomposes any task into micro-steps (3-5 min), presents ONE at a time with a question, waits, adapts. Three guidance levels: alto (closed questions, 3 lines max), medio (2-3 steps, open questions), bajo (full checklist). Block detection: reformulates on "no sé", checks in on silence, redirects on topic change. Based on N-CAPS (Nonlinear Context-Aware Prompting System) and ADHD-aware productivity framework (arxiv 2507.06864).
- **focus-mode.md**: `/focus-mode on`, `off`, `status`. Single-task mode — loads ONE PBI, hides sprint board and backlog. Complements guided-work (focus = clean environment, guided = active guidance).
- **accessibility-setup.md**: `/accessibility-setup`. 5-minute conversational wizard in 4 phases (Vision → Motor → Cognitive → Wellbeing). Creates/updates `accessibility.md` profile fragment.
- **accessibility-mode.md**: `/accessibility-mode on`, `off`, `status`, `configure`. Quick toggle for all adaptations with current config summary.
- **accessibility-output.md**: Domain rule adapting ALL Savia outputs based on profile: screen_reader → text descriptions, high_contrast → no color dependency, cognitive_load:low → 5 lines max, motor → command aliases. Priority chain: screen_reader > cognitive_load > high_contrast > rest.
- **guided-work-protocol.md**: Interaction protocol rule — task decomposition, question patterns per level, block detection table, calibrated celebrations ("Hecho. Paso X/N." — never condescending), context recovery, N-CAPS non-linear adaptation. Core principle: "The goal is not speed. It's that the person CAN complete it, at their pace, with dignity and autonomy."
- **inclusive-review.md**: Strengths-first code reviews when review_sensitivity=true. Vocabulary mapping: "Bug"→"Caso no cubierto", "Error"→"Oportunidad de mejora". Structure: strengths → opportunities → constructive close.
- **accessibility.md** (profile fragment template): 7th opt-in profile fragment. Fields: screen_reader, high_contrast, reduced_motion, cognitive_load (low/medium/high), focus_mode, guided_work, guided_work_level (alto/medio/bajo), motor_accommodation, voice_control, review_sensitivity, dyslexia_friendly, break_strategy, break_interval_min.
- **guide-accessibility.md**: Step-by-step guide per disability profile — visual, motor/RSI, ADHD, autism, dyslexia, hearing. Each with recommended config, workflow example, and tips.
- **accessibility-es.md / accessibility-en.md**: Bilingual quick-reference docs with feature list, common configurations table, and FAQ.
- **ACKNOWLEDGMENTS.md**: Credits to all inspiring projects (claude-code-templates, kimun, Engram, BullshitBench, claude-mem), studies (LLYC, Fundación ONCE, N-CAPS, DX Core 4, NIST/ISO/EU AI Act), and people (Daniel Avila, Eduardo Díaz, Miguel Luengo-Oroz).
- READMEs updated to link ACKNOWLEDGMENTS.md instead of inline credits.

Research sources: Fundación ONCE "Por Talento Digital" (30K+ trained), N-CAPS, arxiv 2411.13950 (ADHD/Autism in Software Development), arxiv 2507.06864 (ADHD-Aware Productivity Framework), DX Core 4.

Tests: `test-accessibility.sh` — 56 structural tests. CI: 14/14 green.

---

## [2.14.0] — 2026-03-06

### Added — Enterprise Readiness: Eras 36-42 (Score 5.6 → 8.1)

Seven Eras to make pm-workspace viable for large consultancies (500-5000 employees, 50+ projects):

- **v2.11.0 — Multi-Team Coordination (Era 36)**: `/team-orchestrator` with create, assign, deps, sync, status. Team Topologies (Skelton & Pais), RACI, cross-team dependency detection, circular alerts. Rule: `team-structure.md`. Skill: `team-coordination/`.
- **v2.12.0 — RBAC File-Based (Era 37)**: `/rbac-manager` with grant, revoke, audit, check. 4-tier roles (Admin/PM/Contributor/Viewer), pre-command enforcement, append-only audit trail. Rule: `rbac-model.md`. Skill: `rbac-management/`.
- **v2.12.1 — Cost & Billing (Era 38)**: `/cost-center` with log, report, budget, forecast, invoice. Timesheet JSONL, EVM (EAC/CPI/SPI), rate tables, client invoicing. Rules: `billing-model.md`, `cost-tracking.md`. Skill: `cost-management/`.
- **v2.12.2 — Onboarding at Scale (Era 39)**: `/onboard-enterprise` with import, checklist, progress, knowledge-transfer. CSV batch import, 4-phase onboarding, per-role checklists. Rule: `onboarding-enterprise.md`. Skill: `enterprise-onboarding/`.
- **v2.13.0 — Governance & Audit (Era 40)**: `/governance-enterprise` with audit-trail, compliance-check, decision-registry, certify. JSONL audit log, governance matrix (GDPR/AEPD/ISO27001/EU AI Act). Rules: `audit-trail-schema.md`, `governance-enterprise.md`. Skill: `governance-enterprise/`.
- **v2.13.1 — Enterprise Reporting (Era 41)**: `/enterprise-dashboard` with portfolio, team-health, risk-matrix, forecast. SPACE framework, Monte Carlo forecasting, cross-project risk aggregation. Rule: `enterprise-metrics.md`. Skill: `enterprise-analytics/`.
- **v2.14.0 — Scale & Integration (Era 42)**: `/scale-optimizer` with analyze, benchmark, recommend, knowledge-search. 3-tier scaling model, vendor sync, full-text search, CI/CD standardization. Rule: `scaling-patterns.md`. Skill: `scaling-operations/`.

Tests: 295 structural tests across 7 test scripts.

---

## [2.10.0] — 2026-03-06

### Added — Cognitive Sovereignty: AI Vendor Lock-in Audit (Era 35)

- **sovereignty-audit.md**: `/sovereignty-audit scan`, `report`, `exit-plan`, `recommend`. Diagnoses and quantifies organizational independence from AI providers. 5-dimension Sovereignty Score (0-100): data portability, LLM independence, organizational graph protection, consumption governance, exit optionality. Based on "La Trampa Cognitiva" (De Nicolás, 2026) — cognitive lock-in as the new enterprise dependency.
- **cognitive-sovereignty.md**: Domain rule with lock-in evolution framework (technical→contractual→process→cognitive), 5 dimensions with weighted scoring, vendor risk matrix, alarm signals, integration with governance-audit.
- **sovereignty-auditor/SKILL.md**: Scan orchestration (workspace analysis, score calculation), executive report generation, concrete exit plan with migration timeline, actionable recommendations mapped to pm-workspace commands.
- Tests: `test-sovereignty-audit.sh` — 50 structural tests across command, rule, skill, and cross-references.

---

## [2.9.0] — 2026-03-05

### Added — Wellbeing Guardian: Proactive Individual Wellbeing (Era 34)

- **wellbeing-guardian.md**: `/wellbeing-guardian status`, `configure`, `breaks`, `report`, `pause`. Proactive nudge system for individual work-life balance — break reminders, after-hours alerts, weekend disconnection suggestions. 5 break strategies (Pomodoro, 52-17, 5-50, custom, 20-20-20 eye rule). Non-blocking philosophy: suggestions, never interruptions.
- **wellbeing-config.md**: Domain rule with break science reference (HBR Feb 2026 research on AI-intensified work), strategy definitions, 5 nudge template categories, work schedule schema for user profiles, integration points with burnout-radar and sustainable-pace.
- **wellbeing-guardian/SKILL.md**: Orchestration — session start (load schedule, detect after-hours), periodic check (time-based nudges), configure (interactive setup), status, pause, breaks history, weekly report with break_compliance_score.
- **session-init-priority.md**: Added Wellbeing context entry (Media priority, ~25 tokens) for ambient work schedule awareness.
- Tests: `test-wellbeing-guardian.sh` — 50 structural tests across command, rule, skill, and cross-references.

---

## [2.8.2] — 2026-03-05

Emergency plan hardened for offline reliability.

### Changed

- **emergency-plan.sh/.ps1**: Added connectivity check (Step 0) — fails fast with clear message if no internet. Added idempotency to cached binary path — checks `ollama list` before pulling. Added verification step (Step 5) — confirms what is cached and ready for offline. Updated step numbering from [1/4]...[4/4] to [1/5]...[5/5]. Extracted `_extract_ollama()` and `_pull_small()` helpers to reduce duplication.

---

## [2.8.1] — 2026-03-05

Emergency mode model alias overrides — subagents now resolve in offline mode.

### Changed

- **emergency-setup.sh/.ps1**: Map `opus`/`sonnet`/`haiku` aliases to local Ollama models via official Claude Code variables (`ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`). Auto-tiered by RAM: 8GB→3b, 16GB→7b/7b/3b, 32GB+→14b/7b/3b.
- **emergency-plan.sh/.ps1**: Pre-download `qwen2.5:3b` alongside main model for haiku alias differentiation.
- **EMERGENCY.md / EMERGENCY.en.md**: New "Model Mapping" section. Updated unset commands. Claude Code Router documented as community option.
- **emergency-mode.md**: Document model alias variables in activate subcommand.

> Community contribution: Cristián Rojas identified the subagent resolution gap.

---

## [2.8.0] — 2026-03-05

### Added — Context Analysis Assistant (Era 33)

- **context-interview.md**: `/context-interview start`, `resume`, `summary`, `gaps`. 8-phase structured interview for client/project onboarding: Domain, Stakeholders, Stack, Constraints, Business Rules, Compliance (sector-adaptive), Timeline, Summary. Proactive gap detection.
- **context-interview-config.md**: Domain rule defining 8 interview phases, session format, sector-adaptive compliance questions (fintech, healthcare, legal, education), one-question-at-a-time rule, gap detection schema, persistence targets per phase.
- **context-interview-conductor/SKILL.md**: Interview orchestration — start, conduct phases, resume, summary, gaps. Adaptive questions per sector. Immediate persistence. Phase 8 generates consolidated summary with gap analysis.
- Tests: `test-context-interview.sh` — 49 structural tests across command, rule, skill, and cross-references.

---

## [2.7.0] — 2026-03-05

### Added — BacklogGit: Backlog Version Control (Era 32)

- **backlog-git.md**: `/backlog-git snapshot`, `diff`, `rollback`, `deviation-report`. Captures periodic markdown snapshots of backlogs from any PM tool (Azure DevOps, Jira, GitLab, Savia Flow, manual). Diff algorithm detects added/removed/modified items with scope creep and re-estimation metrics.
- **backlog-git-config.md**: Domain rule defining snapshot format (YAML frontmatter + items table), 5 source types with auto-detection, diff algorithm, deviation metrics, immutability rules, frequency guidance.
- **backlog-git-tracker/SKILL.md**: Snapshot capture (9 steps), diff with flexible references, rollback (info-only, NEVER auto-execute), deviation report with temporal metrics and ASCII charts.
- Tests: `test-backlog-git.sh` — 41 structural tests across command, rule, skill, and cross-references.

---

## [2.6.0] — 2026-03-05

### Added — Client Profiles (Era 31)

- **client-profile.md**: `/client-create {name}`, `/client-show {slug}`, `/client-edit {slug} [section]`, `/client-list`. First-class client entities in SaviaHub with identity, contacts, business rules, and projects.
- **client-profile-config.md**: Domain rule defining client directory structure (`profile.md`, `contacts.md`, `rules.md`, `projects/`), frontmatter schema, slug generation, status/SLA validation, security rules.
- **client-profile-manager/SKILL.md**: CRUD orchestration skill — create (10 steps), show (7 steps), edit, list with index regeneration, add-project. Error handling with fuzzy match.
- Tests: `test-client-profiles.sh` — 41 structural tests across command, rule, skill, cross-references, and SaviaHub integration.

---

## [2.5.0] — 2026-03-05

### Added — SaviaHub: Shared Knowledge Repository (Era 30)

- **savia-hub.md**: `/savia-hub` command with 5 subcommands — `init` (local or remote clone), `status`, `push`, `pull`, `flight-mode on|off`. Centralizes company identity, org chart, clients, users, and projects in a single Git repository.
- **savia-hub-config.md**: Domain rule defining repository structure (`company/`, `clients/`, `users/`), path configuration (`SAVIA_HUB_PATH`, `SAVIA_HUB_REMOTE`), local config format (`.savia-hub-config.md`), naming conventions, and security rules.
- **savia-hub-offline.md**: Domain rule for flight mode — activation/deactivation, sync queue (`.sync-queue.jsonl`), divergence detection, auto-sync config. Safety: NUNCA auto-resolver conflictos.
- **savia-hub-sync/SKILL.md**: Sync orchestration skill — init flow (delegates to `savia-hub-init.sh`), push (10-step with PM confirmation), pull (7-step with conflict handling), flight mode management.
- **savia-hub-init.sh**: Bash init script with `--remote URL`, `--path PATH`, `--help` flags. Creates directory structure, company templates, clients index, `.gitignore`, local config, initial commit. Idempotent.
- Tests: `test-savia-hub.sh` — 44 structural tests across command, rules, skill, init script, and cross-references.

---

## [2.4.0] — 2026-03-04

### Added — One-Line Installer (Era 29)

- **install.sh**: macOS + Linux one-line installer (`curl -fsSL ... | bash`). OS detection (macOS/Ubuntu/Fedora/Arch/Alpine/WSL), prerequisite checks (git, node ≥18, python3, jq), Claude Code auto-install, pm-workspace clone, npm deps, smoke test. Idempotent, configurable via `SAVIA_HOME` env var, `--skip-tests` and `--help` flags.
- **install.ps1**: Windows PowerShell one-line installer (`irm ... | iex`). Same flow adapted for PowerShell 5.1+. Winget/Chocolatey install hints. WSL detection with cross-platform suggestion.
- Tests: `test-install.sh` — structural validation for both installers.

---

## [2.3.0] — 2026-03-04

### Added — Scoring Intelligence (Era 28)

- **scoring-curves.md**: piecewise linear normalization for 6 dimensions (PR size, context usage, file size, velocity deviation, test coverage, Brier score). Smooth degradation with calibrated breakpoints instead of binary pass/fail. Inspired by kimun (lnds/kimun) and SonarSource/Microsoft Code Metrics.
- **score-diff.md**: `/score-diff` command comparing workspace metrics between git refs. Delta tracking with regression/improvement classification. Haiku subagent for data collection.
- **severity-classification.md**: Rule of Three severity system — 3+ occurrences → CRITICAL, 2 → WARNING, 1 → INFO. Temporal escalation (same WARNING × 3 sprints → auto-CRITICAL). Thresholds for PR quality, sprint health, context health, code quality.
- Tests: `test-scoring-intelligence.sh` — 39 tests across scoring curves, score diff, severity classification, integration and cross-references.

---

## [2.2.0] — 2026-03-04

### Added — Best Practices Audit & Documentation (Era 27)

- **CLAUDE-GUIDE.md**: guide and template for project-level CLAUDE.md files (minimal ~50 lines, complete ~120)
- **estudio-equality-shield.md**: full Equality Shield implementation study with academic references
- External audit of [claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) repo: confirmed existing coverage of 12/13 recommended features (context-map, agent-self-memory, intelligent-hooks, source-tracking, semantic-hub-index, confidence-protocol, consensus-protocol, context-aging, command-ux-feedback, skillssh-publishing, output-first, file-size-limit)

---

## [2.1.0] — 2026-03-04

### Added — Equality Shield (Era 26)

- **equality-shield.md**: anti-bias domain rule based on LLYC "Espejismo de Igualdad" (2026) study blocking 6 bias types
- **bias-check.md**: `/bias-check` command for counterfactual bias auditing in sprints
- **politica-igualdad.md**: equality policy documentation with academic references (Dwivedi 2023, EMNLP 2025, RANLP 2025)
- Rule #23 in CLAUDE.md: mandatory counterfactual test in assignments and communications
- Tests: `test-equality-shield.sh` — 41 tests covering full framework validation

---

## [2.0.0] — 2026-03-04

Quality Validation Framework — Era 25. Multi-judge consensus, confidence calibration, and output coherence validation inspired by BullshitBench.

### Added

- **Multi-Judge Consensus** — 3-judge panel (reflection-validator, code-reviewer, business-analyst) with weighted scoring (0.4/0.3/0.3), verdicts (APPROVED/CONDITIONAL/REJECTED), veto rule for security/GDPR, dissent handling. Skill + rule + command `/validate-consensus`.
- **Confidence Calibration** — Tracks NL-resolution success/failure in JSONL log, computes per-band accuracy and Brier score, decay mechanism (-5% for 3 pattern failures, -10% for 5 command failures, floor 30%), recovery (+3% per success). Script `confidence-calibrate.sh` + protocol rule.
- **Output Coherence Validator** — `coherence-validator` agent (Sonnet 4.6) checks output↔objective alignment: coverage, internal consistency, completeness. Severity levels (ok/warning/critical). Skill + command `/check-coherence`.
- **98 new tests**: `test-consensus.sh` (33) + `test-confidence-calibration.sh` (30) + `test-coherence-validator.sh` (35).

### Changed

- **NL-command resolution** — Added recalibration section with confidence logging and decay mechanism.
- **Agents catalog** — Updated to 27 agents (added `coherence-validator`). Added consensus flow.
- **CLAUDE.md / READMEs** — Updated agent count (26→27), skill count (23→25).

---

## [1.9.1] — 2026-03-04

Reflection Validator agent and skill — System 2 meta-cognitive validation protocol.

### Added

- **`reflection-validator` agent** (Opus 4.6): 5-step System 2 protocol — extracts real objective, audits assumptions, simulates causal chain, detects gaps, corrects transparently.
- **`reflection-validation` skill** (SKILL.md, 148 lines): embeddable pattern for internal reflection, cognitive bias taxonomy, structured output format.
- **Agent memory** (`agent-memory/reflection-validator/MEMORY.md`): persistent context for reflection sessions.
- **65 new tests** (`scripts/test-reflection-validator.sh`): covers agent structure, skill protocol, memory, integration, and cognitive bias detection.

### Changed

- **Agents catalog** — Updated to 26 agents (added `drift-auditor` and `reflection-validator`).
- **CLAUDE.md / READMEs** — Updated agent count (25→26) and skill count (22→23).

---

## [1.9.0] — 2026-03-04

Memory improvements inspired by claude-mem + Natural Language command resolution system.

### Added

- **Concepts dimension** in `memory-store.sh`: `--concepts` parameter stores CSV tags as JSON array for 2D taxonomy (type + concepts).
- **Token economics**: every memory entry tracks `tokens_est` (content length / 4) for budget awareness.
- **Hybrid search**: scored multi-field search (title 3x, concepts 2x, content 1x) with `--type` and `--since` filters, top-10 limit.
- **`/memory-recall`** — Progressive disclosure in 3 layers: index (titles only), timeline (last N), detail (full entry).
- **`/memory-stats`** — Dedicated stats command with type/concept breakdown and token estimates.
- **`/memory-consolidate`** — Session consolidation: groups entries by concept, generates session-summary, deduplicates.
- **`/savia-recall`** — Unified search across memory store, agent MEMORY.md files, and lessons.md.
- **`memory-auto-capture.sh`** — PostToolUse async hook that auto-captures patterns from Edit/Write operations with 5-min rate limit.
- **Intent catalog** (`.claude/commands/references/intent-catalog.md`): 60+ NL patterns mapped to commands across 19 categories, bilingual ES/EN.
- **NL resolution rule** (`.claude/rules/domain/nl-command-resolution.md`): automatic intent detection, confidence scoring (base + context + history), anti-improvisation guards.
- **`/nl-query` rewritten**: loads intent catalog, scores confidence, resolves params from context, learns from successful mappings. Subcommands: `--explain`, `--learn`, `--history`.
- **32 new tests**: `test-memory-improvements.sh` (13 tests) + `test-nl-resolution.sh` (19 tests).

### Changed

- **`memory-store.sh`** — Enhanced `cmd_save()` (concepts, tokens), `cmd_search()` (scored, filtered), `cmd_stats()` (concept breakdown). Fixed dedup logic.
- **README.md / README.en.md** — Added new memory and NL commands to command catalog. Version history updated.

---

## [1.8.0] — 2026-03-04

Usage guides by scenario + README restructure + documentation alignment.

### Added

- **10 usage guides** in `docs/guides/`: Azure DevOps consultancy, Jira consultancy, Savia standalone, Education (Savia School), Hardware lab, Research lab, Startup, Non-profit, Legal firm, Healthcare. Each guide includes roles, setup, day-to-day workflows, command sequences, and example conversations with Savia.
- **20 gap proposals** identified during guide writing (hardware BOM, experiment tracking, grant lifecycle, legal deadlines, PDCA cycles, and more). Added to roadmap backlog.
- **Guides section** in both README.md and README.en.md with links to all 10 guides.

### Changed

- **README restructured**: removed 3 scattered release note blocks, added clean "Version History" table.
- **README.en.md aligned**: added missing `/excel-report`, `/savia-gallery`, `/vertical-*` commands and `/aepd-compliance` + `/governance-*` to match Spanish version.
- **CLAUDE.md compacted**: 123→119 lines to pass CI gate (max: 120).
- **ROADMAP.md updated**: added Era 22 (v1.6–v1.7) and Era 23 (v1.8 guides) with gap analysis table.

### Fixed

- **README parity**: English and Spanish READMEs now have identical feature coverage and command references.

---

## [1.7.0] — 2026-03-03

Company Savia v3: branch-based isolation with Git orphan branches + quality framework.

### Added

- **`savia-branch.sh`**: new abstraction layer for cross-branch read/write/list/exists/ensure-orphan/check-permission/fetch-messages via `git show` and temporary worktrees.
- **`test-savia-branches.sh`**: 15 tests for branch abstraction layer.
- **Rule #21 — Self-Improvement Loop**: persistent `tasks/lessons.md` reviewed at session start. Rule: `.claude/rules/domain/self-improvement.md`.
- **Rule #22 — Verification Before Done**: proof-based completion. Rule: `.claude/rules/domain/verification-before-done.md`.
- **Agent Self-Memory**: 10 agents with persistent `MEMORY.md` files (code-reviewer, architect, security-guardian, test-runner, triage, and 5 more). Rule: `.claude/rules/domain/agent-self-memory.md`.
- **`/drift-check` command**: audits CLAUDE.md rules vs repo state. Agent: `drift-auditor.md`.
- **`hook-pii-gate.sh`**: pre-commit PII scanner (emails, phones, API keys, IBAN, DNI/NIE).
- **Frontend Component Rules**: `.claude/rules/domain/frontend-components.md` (naming, a11y checklist, states, design tokens).
- **Roadmap v1.7.0**: archived (content integrated into `docs/ROADMAP.md` Era 22).

### Changed

- **20 core scripts migrated**: from directory-based to orphan branch isolation (main, user/{handle}, team/{name}, exchange).
- **8 test suites rewritten**: 120 Savia tests pass (branch-based architecture).
- **Config, skills, docs updated**: `company-savia-config.md`, `SKILL.md`, `message-schema.md` reflect branch architecture.
- **CLAUDE.md**: 22 rules (was 20). New checklist entries for self-improvement and verification.

### Fixed

- **`git fetch origin --all`**: invalid command replaced with `git fetch --all` across all tests.
- **`assert_ok` pattern**: fixed `$?` capture bug in test harnesses (was always 0).
- **Dispatcher command names**: tests now use short names (read, write, exists) matching savia-branch.sh dispatcher.

---

## [1.6.0] — 2026-03-03

Company Savia v2: complete directory restructure for clarity, consistency, and indexing.

### Changed

- **Directory layout**: `team/` → `users/`, `company-inbox/` → `company/inbox/`, new `teams/` directory with per-team member references.
- **User paths simplified**: removed `public/` subdirectory and `savia-` prefixes (`savia-inbox/` → `inbox/`, `savia-state/` → `state/`, `savia-flow/` → `flow/`).
- **35+ files updated**: all scripts, tests, config rules, skills, and docs aligned with new structure.

### Added

- **`inboxes.idx`**: new index mapping handle → inbox path for fast lookup.
- **`teams.idx`**: new index mapping team → members.
- **`teams/{name}/users/{handle}.md`**: per-team member reference files with role and join date.

### Fixed

- **`.gitignore`**: pubkey exclusion rule updated (`!**/pubkey.pem` instead of `!**/public/*.pem`).
- **Test company repo**: reinitialized with new structure.

---

## [1.5.1] — 2026-03-03

Confidentiality hardening: E2E encryption testing, subject sensitivity validation, 7 bug fixes, 5 new test suites.

### Added

- **5 test scripts**: `test-savia-confidentiality.sh` (34 tests — E2E encryption, metadata, non-recipient rejection, privacy scanner, idempotency, subject sensitivity), `test-savia-flow-tasks.sh` (24 tests), `test-savia-index.sh` (12 tests), `test-savia-travel.sh` (18 tests), `test-savia-school.sh` (34 tests).
- **1 script**: `savia-messaging-privacy.sh` — Subject sensitivity validation: detects monetary amounts, dates, company names, credentials, API keys, IPs, emails, DNI/NIE, IBAN in subjects. Warns but doesn't block delivery.
- **1 rule**: `messaging-subject-safety.md` — Agent guidance for safe subject lines. "Instead of X, use Y" table. 12 pattern categories.
- **Company Savia initialization**: Structure deployed to test repo via `company-repo-templates.sh`.

### Fixed

- **savia-flow-tasks.sh**: Multiline seq from `ls|grep|echo` pipeline; `mkdir` with braces inside quotes (no shell expansion).
- **savia-travel.sh**: `local` keyword used outside functions in `case` blocks — refactored into proper functions.
- **savia-index.sh**: Missing `init` dispatcher entry; `update_entry` shift bug (captured name before shift).
- **savia-school.sh**: `SCHOOL_ROOT` used `$1` (the command) as base path — replaced with `SCHOOL_BASE` env var.
- **savia-flow.sh**: Missing `do_sprint_start`/`do_sprint_close`/`do_metrics` adapter functions.
- **savia-flow-sprint.sh**: Case dispatcher executed when sourced — added `BASH_SOURCE` guard.
- **savia-messaging.sh**: Integrated `savia-messaging-privacy.sh` and `check_subject_sensitivity()` call before send.

### Changed

- **test-integration-company.sh**: Runs 18 suites (197 tests total, all green). Accepts repo URL as parameter.

---

## [1.5.0] — 2026-03-03

Ecosystem Integration: research of 12+ Claude Code repos with actionable improvements for pm-workspace.

### Added

- **2 research docs**: `investigacion-ecosistema-claude-code-2026.md` (12 repos analyzed), `era21-masterplan.md` (7 workstreams planned).
- **12 improvement proposals**: instincts system, adversarial security, skill evaluation engine, anti-rationalization hook, quality sweeps, deny rules, pass@k metrics, verify/fix loops, audit trail, AGENTS.md format, VoiceMode, event broker.

---

## [1.4.0] — 2026-03-03

Savia School: educational vertical for classrooms. Teachers tutor and evaluate, students create projects. GDPR/LOPD compliant.

### Added

- **12 commands**: `/school-setup`, `/school-enroll`, `/school-project`, `/school-submit`, `/school-evaluate`, `/school-progress`, `/school-portfolio`, `/school-diary`, `/school-export`, `/school-forget`, `/school-analytics`, `/school-rubric`.
- **2 scripts**: `savia-school.sh` (classroom management), `savia-school-security.sh` (encryption, audit, content filtering, GDPR compliance).
- **1 rule**: `school-safety-config.md` — Security config for school vertical (encryption, consent, isolation, content filtering).

### Security

- Alias-based enrollment (no PII in repository).
- AES-256-CBC encrypted evaluations (teacher-only decryption).
- GDPR Art. 8 (parental consent), Art. 15 (data export), Art. 17 (right to erasure).
- Student folder isolation. Audit trail for all operations.

---

## [1.3.0] — 2026-03-03

Git Persistence Engine: TSV indexes for low-context lookups. ~60-80% token reduction per query.

### Added

- **3 commands**: `/index-rebuild`, `/index-status`, `/index-compact` — Manage TSV indexes.
- **2 scripts**: `savia-index.sh` (core: lookup, update, remove, verify, compact), `savia-index-rebuild.sh` (rebuild profiles, messages, projects, specs, timesheets from source files).
- **6 index types**: profiles.idx, messages.idx, projects.idx, tasks.idx, specs.idx, timesheets.idx.

---

## [1.2.0] — 2026-03-03

SDD/Tickets/Tasks Git-native: complete Savia Flow task management in Git folders. No database dependency.

### Added

- **12 commands**: `/flow-task-create`, `/flow-task-move`, `/flow-task-assign`, `/flow-sprint-create`, `/flow-sprint-close`, `/flow-sprint-board`, `/flow-timesheet`, `/flow-timesheet-report`, `/flow-burndown`, `/flow-velocity`, `/flow-spec-create`, `/flow-backlog-groom`.
- **3 scripts**: `savia-flow-tasks.sh` (task CRUD + board), `savia-flow-sprint.sh` (sprint lifecycle + metrics), `savia-flow-timesheet.sh` (time tracking + reporting).
- **1 rule**: `flow-tasks-config.md` — Configuration for Git-native flow system.

---

## [1.1.0] — 2026-03-03

Travel Mode extended: full pack/unpack/sync/verify/clean lifecycle for portable Savia on USB.

### Added

- **5 commands**: `/travel-pack`, `/travel-unpack`, `/travel-sync`, `/travel-verify`, `/travel-clean`.
- **3 scripts**: `savia-travel.sh` (core dispatcher), `savia-travel-ops.sh` (advanced sync operations), `savia-travel-init.sh` (self-contained USB bootstrap).

### Security

- AES-256-CBC encryption for keys and PATs on USB.
- SHA256 integrity checksums for all files.
- Secure cleanup of traces from borrowed machines.

---

## [1.0.0] — 2026-03-03

Script Hardening: 6 critical + 7 medium fixes across 9 scripts. Cross-platform (macOS + Linux + WSL).

### Fixed

- **backup.sh**: Hash comparison bug (comparing plaintext vs SHA256), race condition in rotation (subshell pipe), cp -r without -p flag.
- **contribute.sh**: Perl regex lookahead (?!) invalid in grep -E — corporate email detection was silently failing.
- **memory-store.sh**: grep without -F allows regex injection via topic_key; newlines corrupt JSONL format.
- **pre-commit-review.sh**: Cache invalidation on empty CACHE_DIR.
- **session-init.sh**: Unquoted git branch variable.
- **update.sh**: sed -i not portable on macOS — now uses portable_sed_i.
- **context-aging.sh**: date -d doesn't exist on macOS — now detects OSTYPE.
- **validate-bash-global.sh**: \s not POSIX ERE — replaced with [[:space:]].
- **block-force-push.sh**: Pattern matching bypass via compound commands — added anchoring.

---

## [0.101.0] — 2026-03-03

Savia Flow: Git-based project management — PBIs, sprints, Kanban board, timesheets. No Azure DevOps dependency.

### Added

- **5 commands**: `/savia-pbi`, `/savia-sprint`, `/savia-board`, `/savia-timesheet`, `/savia-team` — Git-based PM lifecycle stored as markdown in company repo.
- **5 scripts**: `savia-flow.sh` (dispatcher), `savia-flow-ops.sh` (PBI CRUD), `savia-flow-sprint.sh` (sprint lifecycle + metrics), `savia-flow-board.sh` (ASCII Kanban), `savia-flow-templates.sh` (project/team scaffolding).
- **1 test script**: `test-savia-flow.sh` — 29 tests covering PBI create/assign/move, sprint start/close, log-time, board, metrics.
- **1 reference**: `flow-schemas.md` — YAML schema specs for PBI, Sprint, Timesheet, Team.

### Changed

- **`company-repo-templates-init.sh`** — Added `projects/` and `teams/` dirs to repo init.

---

## [0.100.0] — 2026-03-03

Travel Mode: portable USB bootstrap with `savia-init` for deploying pm-workspace on new machines.

### Added

- **2 commands**: `/savia-travel-pack`, `/savia-travel-init` — Pack and bootstrap pm-workspace portably.
- **2 scripts**: `savia-travel.sh` (pack), `savia-travel-init.sh` (bootstrap: OS detect, deps check, Claude Code install, workspace copy, profile restore).

---

## [0.99.2] — 2026-03-03

Integration tests against real Company Savia repo structure.

### Added

- **1 test script**: `test-integration-company.sh` — Orchestrates all 3 Company Savia test suites + smoke tests against cloned repo.

---

## [0.99.1] — 2026-03-03

Cross-platform compatibility: replace GNU-only patterns with portable helpers.

### Added

- **1 script**: `savia-compat.sh` — Portable helper library: `portable_base64_encode`, `portable_base64_decode`, `portable_sed_i`, `portable_read_config`, `portable_yaml_field`, `portable_wc_l`.

### Fixed

- **7 scripts**: Replaced `base64 -w0`, `grep -oP`, bare `sed -i` with portable helpers from `savia-compat.sh`. Affected: `savia-crypto-ops.sh`, `savia-messaging.sh`, `savia-messaging-inbox.sh`, `company-repo.sh`, `company-repo-ops.sh`, `backup.sh`, `test-savia-messaging.sh`.

---

## [0.99.0] — 2026-03-03

Company Savia: shared company repository with async messaging and E2E encryption.

### Added

- **7 commands**: `/company-repo`, `/savia-send`, `/savia-inbox`, `/savia-reply`, `/savia-announce`, `/savia-directory`, `/savia-broadcast` — Git-based company repo lifecycle and async messaging with @handle addressing.
- **4 scripts**: `company-repo.sh` (repo lifecycle), `savia-messaging.sh` (message CRUD), `savia-crypto.sh` (RSA-4096 + AES-256-CBC encryption), `privacy-check-company.sh` (pre-push privacy filter).
- **1 script**: `company-repo-templates.sh` — Heredoc templates for repo structure (CODEOWNERS, directory.md, org-chart, holidays, conventions).
- **1 skill**: `company-messaging` — Knowledge module with message schema, encryption protocol, and privacy rules.
- **1 rule**: `company-savia-config.md` — Configuration constants for repo, encryption, privacy, inbox, and messaging.
- **3 test scripts**: `test-company-repo.sh`, `test-savia-messaging.sh`, `test-savia-crypto.sh` — Full test coverage for repo lifecycle, messaging round-trip, and encryption.
- **Session-init integration**: unread inbox count displayed at startup (filesystem-only, no network).

---

## [0.98.0] — 2026-03-03

PR Guardian System — Automated PR validation with 8 quality gates + contextual digest.

### Added

- **`.github/workflows/pr-guardian.yml`** — 8-gate automated PR validation: description quality, conventional commits, CLAUDE.md context guard (≤120 lines), ShellCheck differential, Gitleaks secret scanning (700+ patterns), hook safety validator, context impact analysis, PR Digest (auto-comment in Spanish with risk assessment for maintainer).
- **`.claude/commands/pr-digest.md`** — `/pr-digest` command for manual contextual PR analysis. Classifies changes by area, evaluates risk level, measures context impact, generates executive summary in Spanish.
- **`.gitleaks.toml`** — Gitleaks configuration with allowlist for mock data, test fixtures, and placeholder patterns.
- **`docs/propuestas/propuesta-pr-guardian-system.md`** — Full design document with gap analysis, 8-gate architecture, and implementation plan.
- **`docs/propuestas/roadmap-research-era20.md`** — Era 20 research based on claude-code-best-practice analysis.

### Changed

- **`.github/pull_request_template.md`** — Added "Context impact" and "Hook safety" sections, conventional commits requirement.
- **`docs/ROADMAP.md`** — Added Era 19 (Open Source Synergy) and Era 20 (Persistent Intelligence & Adaptive Workflows) with 6 milestones.

---

## [0.97.0] — 2026-03-03

Era 20 — MCP Toolkit & Async Hooks.

### Added

- **`/mcp-recommend`** — Curated MCP recommendations by stack and role (Context7, DeepWiki, Playwright, Excalidraw, Docker, Slack).
- **`async-hooks-config.md`** — Hook classification (2 async, 10 blocking), event coverage 9/16 (56%), `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50`.

---

## [0.96.0] — 2026-03-03

Era 20 — Adaptive Output & Onboarding.

### Added

- **`/onboard`** — Guided onboarding for new team members with role-specific checklists (dev/PM/QA). Auto-explore, component map, personalized Day 1/Week 1/Month 1 plan.
- **`adaptive-output.md`** — Three output modes: Coaching (junior devs), Executive (stakeholders), Technical (senior engineers). Auto-detection from profile and command context.

---

## [0.95.0] — 2026-03-03

Era 20 — RPI Workflow Engine.

### Added

- **`/rpi-start`** — Research → Plan → Implement workflow with GO/NO-GO gates. Creates `rpi/{feature}/` folder structure orchestrating product-discovery, pbi-decomposition, and spec-driven-development skills.
- **`/rpi-status`** — Track progress of active RPI workflows with phase detection.

---

## [0.94.0] — 2026-03-03

Era 20 — Smart Command Frontmatter.

### Added

- **`smart-frontmatter.md`** — Domain rule defining model selection taxonomy (haiku/sonnet/opus), allowed-tools, context_cost, validation.

### Changed

- **57 commands** updated with `model` and `context_cost` frontmatter fields: 20 haiku, 29 sonnet, 8 opus.

---

## [0.93.0] — 2026-03-03

Era 20 — Savia Contextual Memory.

### Added

- **`/savia-recall`** — Query Savia's accumulated contextual memory (decisions, vocabulary, communication preferences).
- **`/savia-forget`** — GDPR-compliant memory pruning implementing Art. 17 RGPD.
- **`.claude/agent-memory/savia/MEMORY.md`** — Savia-specific persistent memory template.

---

## [0.92.0] — 2026-03-03

Era 20 — Agent Memory Foundation.

### Added

- **`.claude/agent-memory/`** — Persistent memory directory with MEMORY.md templates for 9 agents (architect, security-guardian, commit-guardian, code-reviewer, business-analyst, sdd-spec-writer, test-runner, dotnet-developer, savia).
- **`/agent-memory`** — Command to inspect and manage agent memory fragments (list, show, clear).
- **`agent-memory-protocol.md`** — Domain rule defining three memory scopes (project, local, user), hygiene rules, and integration with existing systems.

---

## [0.91.0] — 2026-03-03

Era 20 — Stress Testing & Bug Fixes. 5 bug fixes + 165 new tests + orchestrator.

### Fixed

- **`block-credential-leak.sh`** — jq fallback: if jq not installed, secrets no longer pass through. Added grep-based extraction.
- **`block-credential-leak.sh`** — Added missing Azure SAS token (`sv=20`), Google API key (`AIza`), and PEM private key detection patterns.
- **`session-init.sh`** — ERR trap now exits 1 (not 0) and includes `$LINENO` for diagnostics.
- **`agent-hook-premerge.sh`** — File line count uses `awk 'END{print NR}'` instead of `wc -l` (fixes off-by-one for files without trailing newline).
- **`agent-hook-premerge.sh`** — Merge conflict markers now detected with `\s*` prefix (catches indented markers).
- **`skillssh-adapter.sh`** — `references:` removal now uses `awk` frontmatter-aware parser instead of broad `sed` that matched comments.

### Added

- **`scripts/test-stress-hooks.sh`** — 25 stress tests for all 14 hooks under edge conditions (credential patterns, jq fallback, line counting, merge markers).
- **`scripts/test-stress-security.sh`** — 27 tests covering SEC-1 through SEC-9 security patterns.
- **`scripts/test-stress-scripts.sh`** — 21 tests for supporting scripts (skillssh-adapter, validate-commands, validate-ci-local, context-tracker, memory-store).
- **`scripts/test-era18-commands.sh`** — 32 tests validating Era 18 command structure (frontmatter, line limits, content).
- **`scripts/test-era18-rules.sh`** — 37 tests validating Era 18 rules (6 AI competencies, 4 AEPD phases, hook taxonomy, source tracking, skills.sh publishing).
- **`scripts/test-era18-formulas.sh`** — 23 tests for scoring formula correctness (AI Competency boundaries, AEPD weights, banking detection weights).
- **`scripts/test-stress-runner.sh`** — Orchestrator that runs all 9 test suites, aggregates counts, generates report in `output/test-results/`.

### Changed

- **`test-savia-e2e-harness.sh`** — Added Section 9: Era 18 Integration (6 tests).
- Tests: 64→229 (+165 new tests across 7 scripts)

---

## [0.90.0] — 2026-03-03

Era 19 — Open Source Synergy (6/6). ERA 19 COMPLETA.

### Added

- **`/mcp-browse`** — Comando para explorar el catálogo de 66+ MCPs del ecosistema claude-code-templates (database, devtools, browser_automation, deepresearch, productivity).
- **`/component-search`** — Búsqueda de componentes en el marketplace claude-code-templates (5.788+ components: agents, commands, hooks, MCPs, settings, skills).
- **`docs/recommended-mcps.md`** — Catálogo curado de MCPs recomendados para equipos PM/Scrum con instrucciones de instalación y contexto de uso.
- **`hooks/README.md`** — Documentación categorizada de los 14 hooks: seguridad (4), puertas de calidad (4), integración de agentes (3), flujo de desarrollo (3). Inspirado en la organización por categorías de claude-code-templates.
- **`agent-observability-patterns.md`** — Regla de dominio con patrones de observabilidad inspirados en el analytics dashboard de claude-code-templates: detección de estado en tiempo real, caché multinivel, WebSocket live updates, monitorización de rendimiento.
- **`component-marketplace.md`** — Regla de dominio que documenta la integración con el marketplace de componentes claude-code-templates (instalación, tipos de componentes, complementariedad).
- **Agradecimiento especial** en README.md y README.en.md a [claude-code-templates](https://github.com/davila7/claude-code-templates) de Daniel Avila (21K+ stars) como referencia imprescindible para herramientas libres para Claude Code.
- **`projects/claude-code-templates/`** — Repositorio clonado para seguimiento de releases, análisis de sinergias y preparación de contribuciones bidireccionales.
- **`SYNERGY-REPORT-PM-WORKSPACE.md`** — Informe completo de sinergias entre ambos proyectos con plan de contribución en 4 fases.

### Changed

- **README.md / README.en.md** — Añadida sección v0.90.0 con nuevos comandos y sección "Agradecimiento especial" con enlace a claude-code-templates.
- Commands: 271→273 · Rules: 50→52

---

## [0.89.0] — 2026-03-03

Era 18 — Compliance, Distribution & Intelligent Hooks (6/6). ERA 18 COMPLETA.

### Added

- **`/aepd-compliance`** — Auditoría de cumplimiento AEPD para IA agéntica (framework 4 fases: tecnología → cumplimiento → vulnerabilidades → medidas). Scoring calibrado.
- **`aepd-framework.md`** — Regla de dominio con el framework AEPD completo, mapping de controles pm-workspace, integración EU AI Act/NIST/ISO 42001.
- **`framework-aepd-agentic.md`** — Marcadores de detección de proyectos agénticos y checklist de compliance.
- **`skillssh-publishing.md`** — Especificación de formato para publicar en skills.sh marketplace (5 skills core mapeadas).
- **`scripts/skillssh-adapter.sh`** — Script de conversión pm-workspace → skills.sh (package.json, README, LICENSE).
- **`intelligent-hooks.md`** — Taxonomía de 3 tipos de hooks (Command/Prompt/Agent) con protocolo de calibración gradual.
- **`hooks/prompt-hook-commit.sh`** — Hook semántico de validación de mensajes de commit (heurísticas, sin LLM).
- **`hooks/agent-hook-premerge.sh`** — Quality gate pre-merge (secrets, TODOs, conflict markers, 150-line limit).
- **`/excel-report`** — Generar plantillas Excel interactivas (capacity, CEO, time-tracking) en CSV multi-tab.
- **`excel-templates.md`** — Estructuras CSV con fórmulas documentadas y reglas de validación.
- **`/savia-gallery`** — Catálogo interactivo de 271 comandos por rol y vertical con source tracking.
- **`source-tracking.md`** — Sistema de citación de fuentes (rule:/skill:/doc:/agent:/cmd:/ext:) con formatos inline/footer/compacto.
- **`ai-competency-framework.md`** — 6 competencias AI-era (Problem Formulation, Output Evaluation, Context Engineering, AI Orchestration, Critical Thinking, Ethical Awareness) con 4 niveles cada una.

### Changed

- **`governance-audit.md`** — Añadidos 4 criterios AEPD (EIPD, base jurídica, scope guard, protocolo brechas).
- **`governance-report.md`** — Añadido AEPD como framework soportado con score 4 fases.
- **`regulatory-compliance/SKILL.md`** — Nueva referencia framework-aepd-agentic.md.
- **`marketplace-publish.md`** — Añadido `--target skillssh` con referencia a adapter script.
- **`settings.json`** — Registrados 2 nuevos hooks (prompt-hook-commit, agent-hook-premerge).
- **`adoption-assess.md`** — Añadida opción `--ai-skills` con AI Competency radar (6 dimensiones).
- Commands: 268→271 · Hooks: 12→14

---

## [0.83.0] — 2026-03-02

Safe Boot, Deterministic CI, PR Governance — Savia arranca siempre: MCP servers vacíos (conexión bajo demanda), session-init blindado (sin red, sin jq, timeout 5s). Mock engine determinista (cksum hash, 29/29 consistente). Hooks de gobernanza PR (bloqueo auto-aprobación y bypass branch protection).

### Changed

- **`mcp.json`** — Servidores vacíos. Savia conecta bajo demanda con `/mcp-server start`, no al arranque.
- **`session-init.sh`** — v0.42.0: sin llamadas de red, sin dependencia `jq`, timeout global 5s, ERR trap para salida limpia garantizada. Context tracker en background.
- **`engines.sh`** — Mock determinista: varianza con `cksum` hash (no `$RANDOM`), context overflow solo en límite real (200k tokens).
- **`CLAUDE.md`** — 216→120 líneas: sección Savia duplicada eliminada, catálogo de comandos movido a referencia, regla 19 (arranque seguro).
- **`validate-bash-global.sh`** — Nuevos bloqueos: `gh pr review --approve` (auto-aprobación) y `gh pr merge --admin` (bypass branch protection).
- **`github-flow.md`** — Reglas explícitas: NUNCA auto-aprobar, NUNCA --admin.

---

## [0.82.0] — 2026-03-02

Auto-Compact — Compresión automática de contexto entre escenarios. Cuando el contexto acumulado supera un umbral configurable (default 40%), se ejecuta `retro-summary --compact` simulado que reduce 60-70% del contexto. Harness refactorizado en 3 ficheros (≤150 líneas cada uno).

### Added

- **`--auto-compact`** flag en harness.sh — activa compresión automática entre escenarios.
- **`--compact-threshold=N`** — umbral configurable (% de ventana 200K) para disparar compactación.
- **`engines.sh`** — Mock engine + live engine extraídos a fichero independiente.
- **`report-gen.sh`** — Generador de reports extraído a fichero independiente.
- Sección "Auto-Compaction Events" en el report cuando se activa.

### Changed

- **`harness.sh`** — Refactorizado de 269→150 líneas, ahora orquestador puro.
- **`test-savia-e2e-harness.sh`** — 44 tests (vs 38), incluye test de auto-compact.

---

## [0.81.0] — 2026-03-02

AI Role Tooling — Dos nuevos comandos basados en gaps detectados en role-evolution-ai: `/knowledge-prime` (genera `.priming/` con 7 secciones Fowler) y `/savia-persona-tune` (5 perfiles de tono/personalidad).

### Added

- **`/knowledge-prime`** — Genera `.priming/` analizando código, packages, ADRs y git log. 7 secciones: architecture, stack, sources, structure, naming, examples, anti-patterns.
- **`/savia-persona-tune`** — 5 perfiles (warm, technical, executive, mentor, minimal). Genera `.savia-persona.yml`.

### Changed

- CLAUDE.md, README.md, README.en.md — Command count 267→268.

---

## [0.80.0] — 2026-03-02

Context Optimization v2 — Mock engine realista calibrado por tipo de comando. State file para acumulación de contexto entre steps. Probabilidad de overflow crece con contexto acumulado (>80K: +10%, >120K: +20%).

### Changed

- **`harness.sh`** — Mock engine reescrito: rangos de tokens calibrados por comando, state file `state.json`, columna `context_acc` en CSV, sección "Context Accumulation" en report con umbrales 50%/70%.

---

## [0.79.1] — 2026-03-02

Role Evolution update — Reescrita `role-evolution-ai.md` con la taxonomía real de Kelman Celis (6 categorías: Estrategia, Ingeniería, Datos, Gobernanza, Interacción, Mantenimiento). Mapping equipo SocialApp a categorías Kelman. Gaps detectados → propuestas de mejora en roadmap.

### Changed

- **`role-evolution-ai.md`** — Reescrita completa: 6 categorías Kelman (vs genéricas previas), roles industria mapeados a Savia Flow, gaps detectados (RAG Engineer, Behavioral Trainer, AI UX Designer).
- **`ROADMAP.md`** — Añadido "AI Role Tooling" en propuestas: `/knowledge-prime`, `/savia-persona-tune`, mock engine realista.

---

## [0.79.0] — 2026-03-02

CI + Multimodal Agent Prep — GitHub Action para E2E mock en PRs. Reference de agentes multimodales (VLM vision+text+code) con roadmap de integración para quality gates visuales.

### Added

- **`.github/workflows/savia-e2e.yml`** — CI workflow: E2E mock test en PRs que modifiquen flow-* o savia-test.
- **`multimodal-agents.md`** — Reference: agentes VLM, tool-use, roadmap integración visual gates + spec from wireframe.

---

## [0.78.0] — 2026-03-02

Role Evolution — 6 categorías roles AI-era mapeadas a Savia Flow. Escenario stress test (10+ specs concurrentes).

### Added

- **`role-evolution-ai.md`** — 6 categorías (Orchestrator, Translator, Guardian, Builder, Context Engineer, Governance), mapping equipo, madurez L1-L4.
- **`05-stress.md`** — Escenario stress: 10+ specs, intake masivo, board full-load, retro exhaustivo.

---

## [0.77.0] — 2026-03-02

Knowledge Priming (Fowler) — 5 patrones para reducir fricción AI. Estructura `.priming/` por proyecto.

### Added

- **`knowledge-priming.md`** — 7 secciones priming, Design-First, Context Anchoring, Feedback Flywheel.

### Changed

- SKILL.md: +3 references (knowledge-priming, role-evolution-ai, multimodal-agents).

---

## [0.76.0] — 2026-03-02

Context Optimization — Correcciones del informe E2E v0.75.0. `max_context` budgets, `--spec` filter, escenario flow-protect.

### Changed

- `flow-board/intake/metrics/spec.md` — `max_context` en frontmatter para budget enforcement.
- `flow-intake.md` — Nuevo `--spec {ID}` para intake individual.
- `03-coordination.md` — Nuevo Step 5: flow-protect (WIP overload, deep work).
- `test-savia-e2e-harness.sh` — Check flow-protect en escenario 03.

---

## [0.75.0] — 2026-03-02

Savia E2E Test Harness — Entorno Docker aislado con agente autónomo que ejecuta Claude Code headless contra pm-workspace. Simula 4 roles de equipo ejecutando 23 pasos en 5 escenarios (setup → exploration → production → coordination → release). Recopila métricas de tokens, tiempos, errores y bloqueos de contexto. Modo mock para CI, modo live con API key real.

### Added

- **`docker/savia-test/`** — Test harness Docker: Dockerfile, docker-compose.yml, harness.sh orchestrator.
- **5 escenarios E2E** — 00-setup (3 pasos), 01-exploration (5), 02-production (5), 03-coordination (5), 04-release (5). 23 pasos totales cubriendo todo el ciclo Savia Flow.
- **Motor mock** — Simula respuestas con tokens aleatorios, 5% error rate (context overflow + timeout). Para CI sin API key.
- **Motor live** — Ejecuta `claude -p` headless real. Captura tokens, duración, errores. Configurable via env vars.
- **Métricas CSV** — scenario, step, role, command, tokens_in, tokens_out, duration_ms, status, error.
- **Informe automático** — report.md generado al final con resumen, failures, errors, token totals.

---

## [0.74.0] — 2026-03-02

Savia Flow Practice — Implementación práctica de la metodología Savia Flow: configuración Azure DevOps dual-track, tablero exploración/producción, intake continuo, métricas de flujo y creación de specs. Ejemplo completo: SocialApp (Ionic + microservicios + RabbitMQ) con equipo de 4 personas.

### Added

- **`/flow-setup`** — Configurar Azure DevOps para Savia Flow: board dual-track (Exploration + Production), campos custom (Track, Outcome ID, Cycle Time), area paths. Modos: `--plan` (preview), `--execute` (aplicar), `--validate` (verificar).
- **`/flow-board`** — Visualizar tablero dual-track: exploración a la izquierda, producción a la derecha. Alerta WIP limits excedidos. Filtros por track y persona.
- **`/flow-intake`** — Intake continuo: mover items Spec-Ready a Production. Valida acceptance criteria, check capacidad, asigna a builder disponible.
- **`/flow-metrics`** — Dashboard métricas de flujo: Cycle Time, Lead Time, Throughput, CFR. Métricas IA: spec-to-built time, handoff latency. Tendencias y comparativas.
- **`/flow-spec`** — Crear spec ejecutable desde outcome de exploración. Genera stub con 5 secciones Savia Flow, crea User Story vinculada al Epic padre.
- **Skill `savia-flow-practice/`** — Guía práctica con 6 references: azure-devops-config, backlog-structure, task-template-sdd, meetings-cadence, dual-track-coordination, example-socialapp.

### Changed

- Command count: 262 → 267 (+5 comandos flow)
- Skills: 20 → 21 (+savia-flow-practice)
- Context-map: añadido grupo Savia Flow

---

## [0.73.0] — 2026-03-02

Vertical Banking — Herramientas especializadas para equipos de desarrollo en banca: validación BIAN + ArchiMate, pipelines Kafka/EDA, data governance (lineage, clasificación, GDPR), auditoría MLOps (model risk, XAI, scoring). Auto-detección de proyectos bancarios.

### Added

- **`/banking-detect`** — Auto-detección de proyecto bancario. 5 fases: entidades BIAN (Account, Settlement, KYC/AML), rutas API bancarias, deps (Kafka, Snowflake, MLflow), config (BIAN_*, KAFKA_*, SWIFT_*), documentación. Score ≥55% → confirmar.
- **`/banking-bian`** — Validar arquitectura contra estándar BIAN. Mapeo microservicios a Service Domains (Payments, Settlement, Deposits, Lending, Risk). Diagrama ArchiMate en Mermaid. Detección de anti-patrones (God Service, Fragmented Domain).
- **`/banking-eda-validate`** — Validar pipelines Kafka/MSK/AMQ: topologías, DLQ, schemas Avro/Protobuf, idempotencia, ordering guarantees. Evaluar patrones EDA: Saga, CQRS, Event Sourcing. Circuit breakers en settlement flows.
- **`/banking-data-governance`** — Auditar data governance: lineage (BCBS 239), clasificación (PII/PCI/Confidencial), catálogo Snowflake/Iceberg, feature stores (batch + real-time). Validar GDPR/LOPD. Data mesh domain ownership.
- **`/banking-mlops-audit`** — Auditar pipeline MLOps bancario: versionado, CI/CD/CT, drift detection, model registry. Explicabilidad (XAI/SHAP/LIME). Model risk management (SR 11-7). Scoring architectures (batch/streaming/event-driven). GenAI (RAG, embeddings).
- **Skill `banking-architecture/`** — Skill con 3 references: BIAN framework, EDA patterns banking, data governance banking.
- **Regla `banking-detection.md`** — Regla de detección automática de proyectos bancarios con 5 fases y scoring.

### Changed

- Command count: 257 → 262 (+5 comandos banking)
- Context-map: añadido grupo Banking
- CLAUDE.md: añadida sección Banking Architecture

---

## [0.72.0] — 2026-03-02

Trace Intelligence — Búsqueda y análisis profundo de trazas distribuidas, investigación asistida de errores con root cause analysis, correlación multi-fuente de incidentes. Era 13 — Observability & Intelligence (2/2). ERA 13 COMPLETE!

### Added

- **`/trace-search {criterio}`** — Buscar y filtrar trazas en Grafana Tempo, Datadog APM, Azure App Insights, OpenTelemetry. Soporta búsqueda en lenguaje natural. Filtros: servicio, estado (error/slow), periodo temporal, código error, tipo de excepción, usuario. Resultados con paginación automática.
- **`/trace-analyze {trace-id}`** — Análisis profundo de traza específica. Waterfall ASCII timeline, detección de cuellos de botella (span más lento), cadena de errores (origen y propagación), detección de anomalías vs baseline, mapa de dependencias de servicios, recomendaciones contextuales. Output adaptado por rol.
- **`/error-investigate {descripción}`** — Investigación asistida de errores. Busca logs coincidentes, correlaciona trazas, analiza despliegues recientes, verifica métricas de infraestructura, identifica servicio origen, construye hipótesis de root cause, sugiere mitigación inmediata y preventiva.
- **`/incident-correlate [--incident-id ID]`** — Correlación cruzada de métricas (Grafana, Datadog, App Insights), logs (Loki, Datadog, App Insights), trazas (Tempo, APM, Dependencies), despliegues (CI/CD), alertas previas y cambios de configuración. Genera timeline unificado, detecta cascading failures, cuantifica blast radius, draft de post-mortem automático.

### Changed

- Command count: 253 → 257 (+4 comandos trace intelligence)
- Era 13 (Observability & Intelligence): COMPLETE! (2/2)

---

## [0.71.0] — 2026-03-02

Observability Core — Conexión a Grafana, Datadog, Azure App Insights, OpenTelemetry. Consultas en lenguaje natural a datos de observabilidad (PromQL, KQL, Datadog Query Language). Dashboards digeridos por rol (CEO, CTO, PM, Dev, QA, SRE). Health checks de fuentes. Era 13 — Observability & Intelligence (1/2).

### Added

- **`/obs-connect {platform}`** — Conectar Savia a Grafana, Datadog, App Insights, OpenTelemetry. Almacena credenciales cifradas (AES-256-CBC). Soporta múltiples instancias simultáneamente. Test de conexión automático.
- **`/obs-query {pregunta}`** — Consultas en lenguaje natural a datos de observabilidad. Traduce automáticamente a PromQL (Grafana), KQL (App Insights), Datadog Query Language. Detecta anomalías vs baseline. Correlaciona con deployments.
- **`/obs-dashboard [--role]`** — Dashboard digerido por rol. CEO: disponibilidad + SLA + costos. CTO: latencias por servicio + errors. PM: impacto en usuarios + features. Dev/SRE: detalles técnicos + logs/traces. QA: pre/post deploy comparisons.
- **`/obs-status`** — Health check de todas las fuentes conectadas. Estado de conexión, última sincronización, volumen de datos, alertas activas, recomendaciones.

### Changed

- Command count: 249 → 253 (+4 comandos observabilidad)
- Era 13 (Observability & Intelligence): iniciada (1/2)

---

## [0.70.0] — 2026-03-02

Multi-Tenant & Skills Marketplace — Workspaces aislados por departamento/equipo, marketplace interno de skills/playbooks, compartición de recursos con control de aprobación. Era 12 — Team Excellence & Enterprise (5/5). PLAN COMPLETADO: v0.54-v0.70 = 68 comandos en 17 versiones.

### Added

- **`/tenant-create`** — Crea workspace aislado por departamento con perfiles, roles, configuración de proyecto e herencia empresarial. Isolation levels: full (separado) o shared (datos separados, reglas comunes).
- **`/tenant-share`** — Comparte recursos (playbooks, templates, skills, reglas) entre tenants con flujo de aprobación, versionado y prevención de config drift.
- **`/marketplace-publish`** — Publica skills/playbooks al marketplace interno con metadatos, validación de calidad y sistema de ratings tipo Anthropic Skills.
- **`/marketplace-install`** — Instala recursos del marketplace con resolución de dependencias, preview y rollback automático. Verificación de compatibilidad.

### Changed

- Command count: 249 → 253 (+4 comandos multi-tenant y marketplace)
- Era 12 (Team Excellence & Enterprise): ahora completa (5/5 fases)

### Plan Roadmap Completado

**v0.54–v0.70**: 17 versiones, 68 nuevos comandos estructurados en 4 eras:

- Era 9 (v0.54–v0.57): Company Intelligence — 16 comandos
- Era 10 (v0.58–v0.61): AI Governance — 17 comandos
- Era 11 (v0.62–v0.65): Context Engineering 2.0 — 17 comandos
- Era 12 (v0.66–v0.70): Team Excellence & Enterprise — 18 comandos

**Total**: 253 comandos en pm-workspace. Todos los comandos ≤150 líneas, con YAML frontmatter, warm Savia persona (female owl), contexto Spanish.

---

## [0.69.0] — 2026-03-02

Audit Trail & Compliance — Inmutable audit trail de todas las acciones de Savia con exportación para auditorías externas, búsqueda contextual y alertas de anomalías. Era 12 — Team Excellence & Enterprise (4/5).

### Added

- **`/audit-trail`** — Log inmutable de todas acciones: comandos ejecutados, recomendaciones, decisiones, archivos. Append-only. Cumple EU AI Act, ISO 42001, NIST AI RMF.
- **`/audit-export`** — Exporta trail en JSON (SIEM), CSV (análisis), PDF (compliance). Incluye hash SHA-256 para verificación de integridad.
- **`/audit-search`** — Búsqueda contextual por fecha, usuario, acción. NL search soportado. Regex patterns. Timeline visualization. Saved searches.
- **`/audit-alert`** — Alertas automáticas por patrones anómalos: fuera de horario, comandos riesgo alto sin aprobación, volumen inusual, acceso a datos sensibles. Canales: Slack, email, dashboard.

### Changed

- Command count: 245 → 249 (+4 comandos auditoría)

---

## [0.68.0] — 2026-03-02

Accessibility & Inclusive Design — Auditoría WCAG 2.2, correcciones automáticas, reportes de conformidad, monitorización continua.

### Added

- **`/a11y-audit`** — Auditoría exhaustiva de accesibilidad WCAG 2.2 (AA/AAA) con detección de alt text, contraste, navegación por teclado, ARIA, focus management, jerarquía de encabezados
- **`/a11y-fix`** — Correcciones automáticas con preview y verificación; covers alt text, ARIA attributes, focus traps, skip links, color contrast
- **`/a11y-report`** — Reportes multi-formato: ejecutivo (score + gráficos), técnico (detalles + código), legal (VPAT/Section 508); tracking de tendencias
- **`/a11y-monitor`** — Monitorización continua en CI/CD; bloquea deploys con regresiones de accesibilidad; digest semanal

### Changed

- Command count: 245 → 249 (+4 comandos accesibilidad)

---

## [0.67.0] — 2026-03-02

Team Wellbeing & Sustainability — Detección temprana de burnout, equilibrado de carga y ritmo sostenible.

### Added

- **`/burnout-radar`** — Detección de señales tempranas de burnout con mapa de calor por miembro
- **`/workload-balance`** — Equilibrado objetivo de carga respetando especialidades
- **`/sustainable-pace`** — Cálculo de ritmo sostenible basado en histórico y capacidad
- **`/team-sentiment`** — Análisis de sentimiento del equipo con pulse surveys y tendencias

### Enhanced

- **role-workflows.md** — Aggregated wellbeing commands for SM/Flow Facilitator role
- **context-map.md** — Added wellbeing group for Team Excellence domain

### Changed

- Command count: 237 → 241 (+4 wellbeing commands in Era 12)
- Era 12 — Team Excellence & Enterprise (2/5 features)

---

## [0.66.0] — 2026-02-28

Advanced DX Metrics — Deep-work analysis, flow-state protection, developer experience profiling, and prevention-focused feedback loops.

### Added

- **`/dx-core4-survey`** — Adapted survey for Speed, Effectiveness, Quality, Impact dimensions
- **`/flow-protect`** — Detect and protect deep-work sessions; block interruptions; suggest focus blocks
- **`/deep-work-analyze`** — Analyze developer deep-work patterns; measure focus time and context switching
- **`/prevention-metrics`** — Preventive metrics: friction points before they block; suggested workflow improvements

### Changed

- Command count: 241 → 245 (+4 DX metrics commands)

---

## [0.65.0] — 2026-02-28

Multi-Layer Caching — Cache strategy, warm operations, analytics, and selective invalidation for context optimization.

### Added

- **`/cache-strategy`** — Define multi-layer cache policy (system, session, command, query levels)
- **`/cache-warm`** — Predictive pre-warming for next operations based on patterns
- **`/cache-analytics`** — Dashboard of cache hit rates, latency improvements, and cost savings
- **`/cache-invalidate`** — Selective invalidation after configuration changes; audit trail

### Changed

- Command count: 237 → 241 (+4 caching commands)

---

## [0.64.0] — 2026-03-02

Semantic Memory 2.0 — Four new memory intelligence commands for semantic compression, importance scoring, knowledge graphs, and intelligent pruning.

### Added

- **`/memory-compress`** — Semantic compression: reduce engrams by up to 80% while preserving fidelity via entity extraction, event summarization, decision condensation, context deduplication
- **`/memory-importance`** — Importance scoring: rank engrams by composite score (relevance × recency × frequency access). Identify high-value and low-value candidates
- **`/memory-graph`** — Knowledge graph from engrams: build relational map of entities, events, decisions. Query connections, detect isolated memories, generate Mermaid visualization
- **`/memory-prune`** — Intelligent pruning: archive low-importance memories, preserve critical ones. Reversible with restore. Never prunes decision-log entries

### Changed

- Command count: 237 → 241 (+4 memory commands)

---

## [0.63.0] — 2026-03-02

Evolving Playbooks — Four new playbook commands for capturing and evolving repetitive workflows using ACE framework.

### Added

- **`/playbook-create`** — Create evolutionary playbooks for releases, onboarding, audits, deploys
- **`/playbook-reflect`** — Post-execution reflection (ACE Reflector): analyze what worked, failed, improve
- **`/playbook-evolve`** — Evolve playbooks with insights (Generator→Reflector→Curator cycle from ACE)
- **`/playbook-library`** — Shareable library of mature playbooks across projects with effectiveness ratings

### Changed

- Command count: 233 → 237 (+4 playbook commands)

---

## [0.62.0] — 2026-03-02

Intelligent Context Loading — Four new context management commands for optimal token budgeting and lazy loading (Context Engineering 2.0).

### Added

- **`/context-budget`** — Token budget per session with optimization suggestions
- **`/context-defer`** — Deferred loading system (85% token reduction)
- **`/context-profile`** — Context consumption profiling (flame-graph style)
- **`/context-compress`** — Semantic compression (80% reduction target)

### Changed

- Command count: 229 → 233 (+4 context commands)

---

## [0.61.0] — 2026-03-02

Vertical Compliance Extensions — Four new vertical-specific compliance commands for regulated sectors (healthcare, finance, legal, education).

### Added

- **`/vertical-healthcare`** — HIPAA, HL7 FHIR, FDA 21 CFR Part 11
- **`/vertical-finance`** — SOX, Basel III, MiFID II, PCI DSS
- **`/vertical-legal`** — GDPR, eDiscovery, contract lifecycle, legal hold
- **`/vertical-education`** — FERPA, Section 508/WCAG, COPPA, LMS integration

### Changed

- Command count: 225 → 229 (+4 vertical compliance commands)

---

## [0.60.0] — 2026-03-02

Enterprise AI Governance — Four new governance commands based on NIST AI RMF, ISO/IEC 42001, and EU AI Act.

### Added

- **`/governance-policy`** — Define company AI policy, risk classification, approval matrix, audit trail
- **`/governance-audit`** — Compliance audit against policy
- **`/governance-report`** — Executive report mapped to frameworks
- **`/governance-certify`** — Certification checklist and readiness scoring

### Changed

- Command count: 221 → 225 (+4 governance commands)

---

## [0.59.0] — 2026-03-02

AI Adoption Companion — Four new adoption commands for team maturity assessment, personalized learning paths, safe practice environments, and friction tracking.

### Added

- **`/adoption-assess`** — Evaluate team adoption maturity using ADKAR model
- **`/adoption-plan`** — Personalized adoption plan by role with learning paths
- **`/adoption-sandbox`** — Safe practice environment without risks
- **`/adoption-track`** — Adoption metrics and friction point detection

### Changed

- Command count: 217 → 221 (+4 adoption commands)

---

## [0.58.0] — 2026-03-02

AI Safety & Human Oversight — Four new safety commands for supervision levels, confidence transparency, boundary definition, and incident tracking.

### Added

- **`/ai-safety-config`** — Configure supervision levels (inform/recommend/decide/execute)
- **`/ai-confidence`** — Transparency dashboard showing confidence, reasoning, data used
- **`/ai-boundary`** — Define explicit boundary matrix per role
- **`/ai-incident`** — Record and analyze Savia incidents

### Changed

- Command count: 213 → 217 (+4 safety commands)

---

## [0.57.0] — 2026-03-02

Ceremony Intelligence — Four new commands for asynchronous standups, retro pattern analysis, ceremony health metrics, and smart agenda generation.

### Added

- **`/async-standup`** — Asynchronous standup collection and compilation
- **`/retro-patterns`** — Pattern analysis from retrospectives
- **`/ceremony-health`** — Health metrics for ceremonies
- **`/meeting-agenda`** — Intelligent agenda generation

### Changed

- Command count: 209 → 213 (+4 ceremony commands)

---

## [0.56.0] — 2026-03-02

Intelligent Backlog Management — Four new commands for assisted grooming, smart prioritization (RICE/WSJF), outcome tracking, and conflict resolution.

### Added

- **`/backlog-groom`** — Detect obsolete, duplicate items without acceptance criteria
- **`/backlog-prioritize`** — Automatic RICE/WSJF prioritization
- **`/outcome-track`** — Post-release outcome tracking
- **`/stakeholder-align`** — Conflict resolution with objective data

### Changed

- Command count: 205 → 209 (+4 backlog commands)

---

## [0.55.0] — 2026-03-02

OKR & Strategic Alignment — Four new commands for OKR definition, tracking, visualization, and strategic mapping.

### Added

- **`/okr-define`** — Define Objectives and Key Results linked to projects
- **`/okr-track`** — Automatic OKR progress tracking
- **`/okr-align`** — Visualize project→OKR→strategy alignment
- **`/strategy-map`** — Strategic map with initiatives and dependencies

### Changed

- Command count: 201 → 205 (+4 strategy commands)

---

## [0.54.0] — 2026-03-02

Company Profile — Four new commands for enterprise onboarding and configuration.

### Added

- **`/company-setup`** — Conversational onboarding of enterprise profile
- **`/company-edit`** — Edit company profile sections
- **`/company-show`** — Display consolidated profile with gap detection
- **`/company-vertical`** — Detect and configure vertical and regulations

### Changed

- Command count: 197 → 201 (+4 company setup commands)

---

## [0.53.0] — 2026-03-02

Multi-Platform Support — Three new commands for multi-platform integration.

### Added

- **`/jira-connect`** — Connect and sync with Jira Cloud
- **`/github-projects`** — Integration with GitHub Projects v2
- **`/platform-migrate`** — Assisted migration between platforms

### Changed

- **`/linear-sync`** — Rewritten with new format, webhooks, unified metrics

---

## [0.52.0] — 2026-03-02

Integration Hub — Four new commands for MCP server exposure, natural language queries, webhook configuration, and integration status.

### Added

- **`/mcp-server`** — Expose Savia tools as MCP server for other projects
- **`/nl-query`** — Natural language queries without memorizing commands
- **`/webhook-config`** — Configure webhooks for real-time event push
- **`/integration-status`** — Dashboard of all integration health

### Changed

- Command count: 174 → 178 (+4 integration commands)

---

## [0.51.0] — 2026-03-02

AI-Powered Planning — Four new commands for intelligent sprint planning, risk prediction, meeting summarization, and capacity forecasting.

### Added

- **`/sprint-autoplan`** — Intelligent sprint planning from backlog and capacity
- **`/risk-predict`** — Sprint risk prediction with early signals
- **`/meeting-summarize`** — Transcription and action item extraction
- **`/capacity-forecast`** — Medium-term capacity forecasting (3-6 sprints)

### Changed

- Command count: 170 → 174 (+4 planning commands)

---

## [0.50.0] — 2026-03-02

Cross-Project Intelligence — Four new commands for portfolio-level visibility and analysis.

### Added

- **`/portfolio-deps`** — Inter-project dependency graph with bottleneck detection
- **`/backlog-patterns`** — Detect duplicates across projects
- **`/org-metrics`** — Aggregated DORA metrics at organization level
- **`/cross-project-search`** — Unified search across all portfolio projects

### Changed

- Command count: 166 → 170 (+4 cross-project commands)

---

## [0.49.0] — 2026-03-01

Product Owner Analytics — Four new commands providing strategic views for POs.

### Added

- **`/value-stream-map`** — Value stream mapping with bottleneck detection
- **`/feature-impact`** — Feature impact on ROI and engagement
- **`/stakeholder-report`** — Executive report for stakeholders
- **`/release-readiness`** — Release readiness verification

### Changed

- Command count: 162 → 166 (+4 PO commands)

---

## [0.48.0] — 2026-03-01

Tech Lead Intelligence — Four new commands for technology health and team knowledge.

### Added

- **`/tech-radar`** — Technology stack mapping (adopt/trial/hold/retire)
- **`/team-skills-matrix`** — Competency matrix with bus factor calculation
- **`/arch-health`** — Architectural health scoring
- **`/incident-postmortem`** — Blameless postmortem template

### Changed

- Command count: 158 → 162 (+4 tech lead commands)

---

## [0.47.0] — 2026-03-01

Developer Productivity — Four new commands for personal sprint view, deep focus, learning opportunities, and pattern catalog.

### Added

- **`/my-sprint`** — Personal sprint view (private, no comparisons)
- **`/my-focus`** — Deep focus mode with context loading
- **`/my-learning`** — Learning opportunity detection from commits
- **`/code-patterns`** — Living pattern catalog from codebase

### Changed

- Command count: 154 → 158 (+4 developer commands)

---

## [0.46.0] — 2026-03-01

QA and Testing Toolkit — Four new commands for complete testing workflow.

### Added

- **`/qa-dashboard`** — Quality panel with coverage and test metrics
- **`/qa-regression-plan`** — Regression test planning based on changes
- **`/qa-bug-triage`** — Assisted bug triage with duplicate detection
- **`/testplan-generate`** — Test plan generation from specs

### Changed

- Command count: 150 → 154 (+4 QA commands)

---

## [0.45.0] — 2026-03-01

Executive Reports for Leadership — Three new commands for C-level strategic views.

### Added

- **`/ceo-report`** — Multi-project executive report with traffic-light scoring
- **`/ceo-alerts`** — Strategic alert panel for director-level decisions
- **`/portfolio-overview`** — Bird's-eye portfolio view with dependencies

### Changed

- Command count: 147 → 150 (+3 CEO commands)

---

## [0.44.0] — 2026-03-01

Semantic Hub Topology — Agentexecution tracing, cost estimation, and efficiency metrics for subagent operations.

### Added

- **`/hub-audit`** — Topology audit revealing hubs, near-hubs, and dormant rules

### Changed

- Command count: 146 → 147 (+1 hub audit command)

---

## [0.43.0] — 2026-03-01

Context Aging and Verified Positioning — Semantic compression of old decisions using neuroscience-inspired aging.

### Added

- **`/context-age`** — Analyze and compress aged decisions
- **`/context-benchmark`** — Verify optimal information positioning
- **`scripts/context-aging.sh`** — Automation script

### Changed

- Command count: 144 → 146 (+2 context commands)

---

## [0.42.0] — 2026-03-01

Subagent Context Budget System — All 24 agents now have explicit max_context_tokens and output_max_tokens fields.

### Changed

- All 24 agent frontmatter files updated with context budgets (4 tiers)

---

## [0.41.0] — 2026-03-01

Session-Init Compression and CLAUDE.md Pre-compaction — 4-level priority system for session initialization.

### Changed

- **`session-init.sh`** — Rewritten with priority-based array system
- **CLAUDE.md** — Pre-compacted from 154 → 125 lines (36% reduction)

---

## [0.40.0] — 2026-03-01

Role-Adaptive Daily Routines, Project Health Dashboard, and Context Usage Optimization.

### Added

- **`/daily-routine`** — Role-adaptive daily routine
- **`/health-dashboard`** — Unified project health dashboard
- **`/context-optimize`** — Context usage analysis with recommendations
- **`scripts/context-tracker.sh`** — Lightweight context usage tracking

### Changed

- Command count: 141 → 144 (+3 context commands)

---

## [0.39.0] — 2026-03-01

Encrypted Cloud Backup System — AES-256-CBC encryption before cloud upload with auto-rotation.

### Added

- **`/backup`** — 5 subcommands for backup management
- **`scripts/backup.sh`** — Full backup lifecycle automation

### Changed

- Command count: 140 → 141 (+1 backup command)

---

## [0.38.0] — 2026-03-01

Private Review Protocol — Maintainer workflow for reviewing community PRs and issues.

### Added

- **`/review-community`** — 5 subcommands for PR/issue review and release

### Changed

- Command count: 139 → 140 (+1 review command)

---

## [0.37.0] — 2026-03-01

Vertical Detection System — Detect non-software sectors and propose specialized extensions.

### Added

- **`/vertical-propose`** — Detect vertical or receive name and generate extensions

### Changed

- Command count: 138 → 139 (+1 vertical detection command)

---

## [0.36.0] — 2026-03-01

Community & Collaboration System — Privacy-first contribution system with credential validation.

### Added

- **`/contribute`** — Create PRs, propose ideas, report bugs
- **`/feedback`** — Open issues with validation

### Changed

- Command count: 136 → 138 (+2 community commands)

---

## [0.35.0] — 2026-03-01

Savia — User Profiling System and Agent Mode. Introduce Savia identity with fragmented user profiles and agent mode support.

### Added

- **`/profile-setup`** — Savia's conversational onboarding
- **`/profile-edit`** — Edit profile sections
- **`/profile-switch`** — Switch between profiles
- **`/profile-show`** — Display active profile

### Changed

- Command count: 131 → 135 (+4 profile commands)
- ~72 existing commands updated with profile loading

---

## [0.34.0] — 2026-02-28

Performance Audit Intelligence — Static analysis for code performance hotspots.

### Added

- **`/perf-audit`** — Static performance analysis
- **`/perf-fix`** — Test-first optimization
- **`/perf-report`** — Executive performance report

### Changed

- Command count: 129 → 131 (+3 performance commands)

---

## [0.33.3] — 2026-02-28

Azure DevOps project validation — Automated audit of project configuration.

### Added

- **`/devops-validate`** — Audit Azure DevOps project config

### Changed

- Command count: 128 → 129 (+1 DevOps command)

---

## [0.33.2] — 2026-02-28

Detection algorithm calibration after real-world testing across regulated sectors.

### Changed

- Detection algorithm: 4 phases → 5 phases
- Confidence thresholds recalibrated

---

## [0.33.1] — 2026-02-28

Compliance commands improvements after real-world testing.

### Fixed

- Output file naming with date suffix
- Scoring formula documentation
- Dry-run vs actual execution indication

---

## [0.33.0] — 2026-02-28

Regulatory Compliance Intelligence — Automated sector detection and compliance scanning across 12 regulated industries.

### Added

- **`/compliance-scan`** — Automated compliance scanning
- **`/compliance-fix`** — Auto-fix framework for violations
- **`/compliance-report`** — Generate compliance report

### Changed

- Command count: 125 → 128 (+3 compliance commands)

---

## [0.32.3] — 2026-02-28

Multi-OS emergency mode — Support for Linux, macOS, and Windows.

---

## [0.32.2] — 2026-02-28

Fix Ollama download — Adapted to new tar.zst archive format.

---

## [0.32.1] — 2026-02-28

Emergency plan — Preventive pre-download of Ollama and LLM for offline installation.

---

## [0.32.0] — 2026-02-28

Emergency mode — Local LLM contingency plan with Ollama setup and offline operations.

### Added

- **`/emergency-mode`** — Manage emergency mode with local LLM

---

## [0.31.0] — 2026-02-28

Architecture intelligence — Pattern detection and recommendations across 16 languages.

### Added

- **`/arch-detect`** — Detect architecture pattern
- **`/arch-suggest`** — Generate improvement suggestions
- **`/arch-recommend`** — Recommend optimal pattern
- **`/arch-fitness`** — Define and execute fitness functions
- **`/arch-compare`** — Compare architecture patterns

---

## [0.30.0] — 2026-02-28

Technical debt intelligence — Automated analysis and prioritization.

### Added

- **`/debt-analyze`** — Automated debt discovery
- **`/debt-prioritize`** — Prioritize by business impact
- **`/debt-budget`** — Propose sprint debt budget

---

## [0.29.0] — 2026-02-28

AI governance and EU AI Act compliance — Model cards and risk assessment.

### Added

- **`/ai-model-card`** — Generate AI model cards
- **`/ai-risk-assessment`** — Risk assessment per EU AI Act
- **`/ai-audit-log`** — Chronological audit log from traces

---

## [0.28.0] — 2026-02-28

Developer Experience metrics — DX Core 4 surveys and automated dashboards.

### Added

- **`/dx-survey`** — Adapted DX Core 4 surveys
- **`/dx-dashboard`** — Automated DX dashboard
- **`/dx-recommendations`** — Friction point analysis

---

## [0.27.0] — 2026-02-28

Agent observability — Execution tracing, cost estimation, and efficiency metrics.

### Added

- **`/agent-trace`** — Dashboard of agent executions
- **`/agent-cost`** — Cost estimation per agent
- **`/agent-efficiency`** — Efficiency analysis

---

## [0.26.0] — 2026-02-28

Predictive analytics and flow metrics — Sprint forecasting with Monte Carlo simulation.

### Added

- **`/sprint-forecast`** — Predict sprint completion
- **`/flow-metrics`** — Value stream dashboard
- **`/velocity-trend`** — Velocity analysis

---

## [0.25.0] — 2026-02-28

Security hardening and community patterns — SAST audit, dependency scanning, and SBOM generation.

### Added

- **`/security-audit`** — SAST analysis against OWASP Top 10
- **`/dependencies-audit`** — Vulnerability scanning
- **`/sbom-generate`** — Generate SBOM
- **`/credential-scan`** — Scan git history for leaked credentials
- **`/epic-plan`** — Multi-sprint epic planning
- **`/worktree-setup`** — Automate git worktree creation

### Changed

- Command count: 96 → 102 (+6 security commands)

---

## [0.24.0] — 2026-02-28

Permissions and CI/CD hardening — Plan-gate hook and CI validation steps.

### Added

- **`/validate-filesize`** — Check file size compliance
- **`/validate-schema`** — Validate JSON schemas

### Changed

- Command count: 94 → 96 (+2 validation commands)

---

## [0.23.0] — 2026-02-28

Automated code review — Pre-commit review hook with SHA256 cache.

### Added

- **`/review-cache-stats`** — Show review cache statistics
- **`/review-cache-clear`** — Clear review cache

### Changed

- Command count: 92 → 94 (+2 review commands)

---

## [0.22.0] — 2026-02-28

SDD workflow enhanced with Agent Teams Lite patterns.

### Added

- **`/spec-explore`** — Pre-spec exploration
- **`/spec-design`** — Technical design phase
- **`/spec-verify`** — Spec compliance matrix

### Changed

- Command count: 89 → 92 (+3 SDD commands)

---

## [0.21.0] — 2026-02-28

Persistent memory system inspired by Engram — JSONL-based memory with deduplication.

### Added

- **`/memory-save`** — Save memory with topic
- **`/memory-search`** — Search memory store
- **`/memory-context`** — Load context from memory

### Changed

- Command count: 86 → 89 (+3 memory commands)

---

## [0.20.1] — 2026-02-27

Fix developer_type format — Revert to hyphen format.

---

## [0.20.0] — 2026-02-27

Context optimization and 150-line discipline enforcement.

### Changed

- 9 skills refactored with progressive disclosure
- 5 agents refactored with companion domain files
- CLAUDE.md compacted from 195 → 130 lines

---

## [0.19.0] — 2026-02-27

Governance hardening — Scope guard hook and parallel session serialization rule.

### Added

- **Scope Guard Hook** for scope creep detection

### Changed

- **`/context-load`** expanded with ADR loading

---

## [0.18.0] — 2026-02-27

Multi-agent coordination — Agent-notes system, TDD gate hook, and ADR support.

### Added

- **`/security-review`** — Pre-implementation security review
- **`/adr-create`** — Create Architecture Decision Records
- **`/agent-notes-archive`** — Archive completed agent-notes

### Changed

- SDD skill workflow expanded with security review and TDD gate

---

## [0.17.0] — 2026-02-27

Advanced agent capabilities and programmatic hooks system.

### Changed

- 23 agents upgraded with advanced frontmatter
- 11 skills updated with context and agent fields
- 7 programmatic hooks added via settings.json

---

## [0.16.0] — 2026-02-27

Intelligent memory system — Path-specific auto-loading and auto memory.

### Added

- **`/memory-sync`** — Consolidate session insights
- **`scripts/setup-memory.sh`** — Initialize memory structure

### Changed

- 21 language files and 3 domain files now have path-specific rules

---

## [0.15.1] — 2026-02-27

Auto-compact post-command — Prevent context saturation.

### Changed

- Auto-compact protocol enforced after every command
- 7 commands freed from context-ux-feedback dependency

---

## [0.15.0] — 2026-02-27

Command naming fix — All commands renamed from colon to hyphen notation.

### Fixed

- All 106 unique command references renamed across 164 files

---

## [0.14.1] — 2026-02-27

Context optimization — Auto-loaded baseline reduced by 79%.

### Changed

- 10 domain rules moved to on-demand loading
- `/help` rewritten with separate setup and catalog modes

---

## [0.14.0] — 2026-02-27

Session persistence — Save/load rituals for persistent "second brain".

### Added

- **`/session-save`** — Capture decisions before clearing
- **`decision-log.md`** — Private cumulative decision register

### Changed

- **`/context-load`** rewritten to load big picture

---

## [0.13.2] — 2026-02-27

Fix silent failures — Heavy commands now explicitly delegate to subagents.

### Fixed

- **`/project-audit`** silent failure fixed with subagent delegation

---

## [0.13.1] — 2026-02-27

Anti-improvisation — Commands strictly execute only what their spec defines.

### Changed

- **`/help`** rewritten with explicit stack detection

---

## [0.13.0] — 2026-02-27

Context health and operational resilience — Proactive context management.

### Added

- **Context health rule** with output-first pattern and compaction suggestions

### Changed

- Auto-loaded context reduced: 2,109 → 899 lines

---

## [0.12.0] — 2026-02-27

Context optimization — 58% reduction in auto-loaded context.

### Changed

- 8 rules moved from auto-load to on-demand
- Auto-loaded context reduced from 2,109 → 882 lines

---

## [0.11.0] — 2026-02-27

UX Feedback Standards — Consistent visual feedback for all commands.

### Added

- **UX Feedback rule** with mandatory standards for all commands

### Changed

- 6 core commands updated with UX feedback pattern

---

## [0.10.0] — 2026-02-27

Infrastructure and tooling — GitHub Actions and MCP migration guide.

### Added

- **GitHub Actions** PR auto-labeling workflow
- **MCP migration guide** for azdevops-queries functions

---

## [0.9.0] — 2026-02-27

Messaging & Voice Inbox — WhatsApp, Nextcloud Talk, and voice transcription.

### Added

- **`/notify-whatsapp`** — Send WhatsApp notifications
- **`/whatsapp-search`** — Search WhatsApp messages
- **`/notify-nctalk`** — Send Nextcloud Talk notifications
- **`/nctalk-search`** — Search Nextcloud Talk messages
- **`/inbox-check`** — Check and process new messages
- **`/inbox-start`** — Start background inbox monitoring

### Changed

- Command count: 75 → 81 (+6 messaging commands)
- Skills count: 12 → 13 (+voice-inbox)

---

## [0.8.0] — 2026-02-27

DevOps Extended — Azure DevOps Wiki, Test Plans, and security alerts.

### Added

- **`/wiki-publish`** — Publish to Azure DevOps Wiki
- **`/wiki-sync`** — Bidirectional wiki sync
- **`/testplan-status`** — Test Plans dashboard
- **`/testplan-results`** — Detailed test run results
- **`/security-alerts`** — Security alerts from Azure DevOps

### Changed

- Command count: 70 → 75 (+5 DevOps Extended commands)

---

## [0.7.0] — 2026-02-27

Project Onboarding Pipeline — 5-phase automated workflow.

### Added

- **`/project-audit`** — Phase 1: deep project audit
- **`/project-release-plan`** — Phase 2: prioritized release plan
- **`/project-assign`** — Phase 3: distribute work across team
- **`/project-roadmap`** — Phase 4: visual roadmap
- **`/project-kickoff`** — Phase 5: compile and notify

### Changed

- Command count: 65 → 70 (+5 onboarding commands)

---

## [0.6.0] — 2026-02-27

Legacy assessment and release notes — Backlog capture from unstructured sources.

### Added

- **`/legacy-assess`** — Legacy application assessment
- **`/backlog-capture`** — Create PBIs from unstructured input
- **`/sprint-release-notes`** — Auto-generate release notes

### Changed

- Command count: 62 → 65 (+3 legacy & capture commands)

---

## [0.5.0] — 2026-02-27

Governance foundations — Technical debt tracking and DORA metrics.

### Added

- **`/debt-track`** — Technical debt register
- **`/kpi-dora`** — DORA metrics dashboard
- **`/dependency-map`** — Cross-team/PBI dependency mapping
- **`/retro-actions`** — Retrospective action tracking
- **`/risk-log`** — Risk register

### Changed

- Command count: 57 → 62 (+5 governance commands)

---

## [0.4.0] — 2026-02-27

Connectors ecosystem and Azure DevOps MCP optimization.

### Added

- **Connector integrations** (12 commands)
- **Azure Pipelines** (5 commands)
- **Azure Repos management** (6 commands)

### Changed

- Command count: 46 → 57 (+11 new commands)
- Skills count: 11 → 12 (+azure-pipelines)

---

## [0.3.0] — 2026-02-26

Multi-language support, multi-environment, and infrastructure as code.

### Added

- **16 Language Packs** with conventions, rules, and agents
- **12 new developer agents** for different languages
- **7 new infrastructure commands**
- **File size governance** (max 150 lines per file)

### Changed

- Command count: 24 → 46
- Skills count: 11 → 23
- Agents count: 8 → 35

---

## [0.2.0] — 2026-02-26

Quality, discovery, and operations expansion.

### Added

- **Product Discovery workflow** (`/pbi-jtbd`, `/pbi-prd`)
- **Quality commands** (`/pr-review`, `/context-load`, `/changelog-update`, `/evaluate-repo`)
- **`product-discovery` skill** with JTBD and PRD templates
- **`test-runner` agent** for post-commit testing

### Changed

- Command count: 19 → 24 (+6)
- Skills count: 7 → 8
- Agents count: 9 → 11

---

## [0.1.0] — 2026-03-01

Initial public release of PM-Workspace.

### Added

- **Core workspace** with CLAUDE.md and setup guide
- **Sprint management** commands (4)
- **Reporting commands** (6)
- **PBI decomposition commands** (4)
- **Spec-Driven Development** with skills and agents
- **Test project** (sala-reservas)
- **Test suite** (96 tests)
- **Documentation** with methodology

[2.80.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.79.0...v2.80.0
[2.79.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.78.0...v2.79.0
[2.78.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.77.0...v2.78.0
[2.77.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.76.5...v2.77.0
[2.76.5]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.76.4...v2.76.5
[2.76.4]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.76.3...v2.76.4
[2.76.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.76.2...v2.76.3
[2.76.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.76.1...v2.76.2
[2.76.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.76.0...v2.76.1
[2.76.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.75.0...v2.76.0
[2.75.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.74.2...v2.75.0
[2.74.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.74.1...v2.74.2
[2.74.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.74.0...v2.74.1
[2.74.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.73.0...v2.74.0
[2.73.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.72.0...v2.73.0
[2.72.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.71.0...v2.72.0
[2.71.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.70.0...v2.71.0
[2.70.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.69.0...v2.70.0
[2.69.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.68.0...v2.69.0
[2.68.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.67.0...v2.68.0
[2.67.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.66.0...v2.67.0
[2.66.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.65.0...v2.66.0
[2.65.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.64.0...v2.65.0
[2.64.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.63.0...v2.64.0
[2.63.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.62.0...v2.63.0
[2.62.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.61.0...v2.62.0
[2.61.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.60.0...v2.61.0
[2.60.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.59.0...v2.60.0
[2.59.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.58.0...v2.59.0
[2.58.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.57.0...v2.58.0
[2.57.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.56.0...v2.57.0
[2.56.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.55.0...v2.56.0
[2.55.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.54.0...v2.55.0
[2.54.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.53.0...v2.54.0
[2.53.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.52.0...v2.53.0
[2.52.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.51.0...v2.52.0
[2.51.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.50.0...v2.51.0
[2.50.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.49.0...v2.50.0
[2.49.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.48.0...v2.49.0
[2.48.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.47.0...v2.48.0
[2.47.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.46.0...v2.47.0
[2.46.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.45.0...v2.46.0
[2.45.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.44.0...v2.45.0
[2.44.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.43.0...v2.44.0
[2.43.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.42.0...v2.43.0
[2.42.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.41.0...v2.42.0
[2.41.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.40.0...v2.41.0
[2.40.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.39.0...v2.40.0
[2.39.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.38.0...v2.39.0
[2.38.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.37.0...v2.38.0
[2.37.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.36.0...v2.37.0
[2.36.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.35.0...v2.36.0
[2.35.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.34.0...v2.35.0
[2.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.33.0...v2.34.0
[2.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.32.0...v2.33.0
[2.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.31.0...v2.32.0
[2.31.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.30.0...v2.31.0
[2.30.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.29.0...v2.30.0
[2.29.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.28.0...v2.29.0
[2.28.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.27.0...v2.28.0
[2.27.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.26.0...v2.27.0
[2.26.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.25.0...v2.26.0
[2.25.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.24.0...v2.25.0
[2.24.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.23.1...v2.24.0
[2.23.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.23.0...v2.23.1
[2.23.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.22.0...v2.23.0
[2.22.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.21.0...v2.22.0
[2.21.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.20.3...v2.21.0
[2.20.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.20.2...v2.20.3
[2.20.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.20.1...v2.20.2
[2.20.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.20.0...v2.20.1
[2.20.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.18.0...v2.19.0
[2.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.17.0...v2.18.0
[2.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.16.1...v2.17.0
[2.16.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.16.0...v2.16.1
[2.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.10.0...v2.14.0
[2.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.8.2...v2.9.0
[2.8.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.8.1...v2.8.2
[2.8.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.8.0...v2.8.1
[2.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.9.1...v2.0.0
[1.9.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.101.0...v1.0.0
[0.101.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.100.0...v0.101.0
[0.100.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.99.2...v0.100.0
[0.99.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.99.1...v0.99.2
[0.99.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.99.0...v0.99.1
[0.99.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.98.0...v0.99.0
[0.98.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.97.0...v0.98.0
[0.97.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.96.0...v0.97.0
[0.96.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.95.0...v0.96.0
[0.95.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.94.0...v0.95.0
[0.94.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.93.0...v0.94.0
[0.93.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.92.0...v0.93.0
[0.92.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.91.0...v0.92.0
[0.91.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.90.0...v0.91.0
[0.90.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.89.0...v0.90.0
[0.89.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.83.0...v0.89.0
[0.83.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.82.0...v0.83.0
[0.82.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.81.0...v0.82.0
[0.81.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.80.0...v0.81.0
[0.80.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.79.1...v0.80.0
[0.79.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.79.0...v0.79.1
[0.79.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.78.0...v0.79.0
[0.78.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.77.0...v0.78.0
[0.77.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.76.0...v0.77.0
[0.76.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.75.0...v0.76.0
[0.75.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.74.0...v0.75.0
[0.74.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.73.0...v0.74.0
[0.73.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.72.0...v0.73.0
[0.72.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.71.0...v0.72.0
[0.71.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.70.0...v0.71.0
[0.70.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.69.0...v0.70.0
[0.69.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.68.0...v0.69.0
[0.68.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.67.0...v0.68.0
[0.67.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.66.0...v0.67.0
[0.66.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.65.0...v0.66.0
[0.65.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.64.0...v0.65.0
[0.64.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.63.0...v0.64.0
[0.63.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.62.0...v0.63.0
[0.62.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.61.0...v0.62.0
[0.61.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.60.0...v0.61.0
[0.60.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.59.0...v0.60.0
[0.59.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.58.0...v0.59.0
[0.58.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.57.0...v0.58.0
[0.57.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.56.0...v0.57.0
[0.56.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.55.0...v0.56.0
[0.55.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.54.0...v0.55.0
[0.54.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.53.0...v0.54.0
[0.53.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.52.0...v0.53.0
[0.52.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.51.0...v0.52.0
[0.51.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.50.0...v0.51.0
[0.50.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.49.0...v0.50.0
[0.49.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.48.0...v0.49.0
[0.48.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.47.0...v0.48.0
[0.47.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.46.0...v0.47.0
[0.46.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.45.0...v0.46.0
[0.45.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.44.0...v0.45.0
[0.44.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.43.0...v0.44.0
[0.43.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.42.0...v0.43.0
[0.42.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.41.0...v0.42.0
[0.41.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.40.0...v0.41.0
[0.40.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.39.0...v0.40.0
[0.39.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.38.0...v0.39.0
[0.38.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.37.0...v0.38.0
[0.37.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.36.0...v0.37.0
[0.36.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.35.0...v0.36.0
[0.35.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.34.0...v0.35.0
[0.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.3...v0.34.0
[0.33.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.2...v0.33.3
[0.33.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.1...v0.33.2
[0.33.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.0...v0.33.1
[0.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.3...v0.33.0
[0.32.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.2...v0.32.3
[0.32.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.1...v0.32.2
[0.32.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.0...v0.32.1
[0.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.31.0...v0.32.0
[0.31.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.30.0...v0.31.0
[0.30.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.29.0...v0.30.0
[0.29.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.28.0...v0.29.0
[0.28.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.27.0...v0.28.0
[0.27.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.26.0...v0.27.0
[0.26.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.25.0...v0.26.0
[0.25.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.24.0...v0.25.0
[0.24.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.23.0...v0.24.0
[0.23.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.22.0...v0.23.0
[0.22.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.21.0...v0.22.0
[0.21.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.1...v0.21.0
[0.20.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.0...v0.20.1
[0.20.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.19.0...v0.20.0
[0.19.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.1...v0.16.0
[0.15.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.2...v0.14.0
[0.13.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.1...v0.13.2
[0.13.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0
[2.99.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.98.0...v2.99.0
[2.98.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.97.0...v2.98.0
[2.97.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.96.0...v2.97.0
[2.96.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.95.0...v2.96.0
[2.95.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.94.0...v2.95.0
[2.93.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.92.0...v2.93.0
[2.92.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.91.0...v2.92.0
[2.91.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.90.0...v2.91.0
[2.90.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.89.0...v2.90.0
[2.89.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.88.0...v2.89.0
[2.88.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.87.0...v2.88.0
[3.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.6.1...v3.7.0
[3.6.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.6.0...v3.6.1
[3.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.5.3...v3.6.0
[3.5.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.5.2...v3.5.3
[3.5.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.5.1...v3.5.2
[3.5.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.5.0...v3.5.1
[3.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.4.1...v3.5.0
[3.4.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.4.0...v3.4.1
[3.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.99.0...v3.0.0
[2.87.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.86.0...v2.87.0
[2.86.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.85.0...v2.86.0
[2.85.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.84.0...v2.85.0
[2.84.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.83.0...v2.84.0
[2.94.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.93.0...v2.94.0
[2.83.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.82.0...v2.83.0
[2.82.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.81.0...v2.82.0
[2.81.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.80.0...v2.81.0
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.0.0...v0.1.0
[3.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.7.1...v3.8.0
[3.7.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.7.0...v3.7.1
[3.8.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.8.0...v3.8.1
[3.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.8.1...v3.9.0
[3.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.9.0...v3.10.0
[3.10.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.10.0...v3.10.1
[3.11.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.10.1...v3.11.0
[3.12.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.11.0...v3.12.0
[3.13.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.12.0...v3.13.0
[3.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.13.0...v3.14.0
[3.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.14.0...v3.15.0
[3.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.15.0...v3.16.0
[3.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.16.0...v3.17.0
[3.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v3.17.0...v3.18.0
