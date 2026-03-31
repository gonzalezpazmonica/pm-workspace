# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-04-01 | **Version:** v3.97.0 | **505 commands · 49 agents · 85 skills · 31 hooks · 41 test suites**

Status: **Done** · **In progress** · **Planned** · **Proposed**

---

## Done — Eras 1-124 (v0.1.0 → v3.24.0)

PM core, 16 language packs, context engineering, security, Savia persona, Company Savia, Travel Mode, Savia Flow, Git Persistence, Savia School, accessibility, adversarial security, Visual QA, dev sessions. Mobile v0.1. Web Phases 1-3. Digest Suite. SaviaClaw ESP32 (firmware, daemon, voice pipeline). 39 tests.

## Done — Eras 125-137: Memory Intelligence + Security Absorption (v3.25.0 → v3.44.0)

- **125** (v3.25): SPEC-012/015, push-pr.sh, PR signing
- **126** (v3.27-28): Engram patterns (W/W/W/L, topic keys, session summary)
- **127** (v3.29): SPEC-018 vector memory (Recall 40%→90%)
- **128** (v3.30): Readiness check (50+ points)
- **129** (v3.31-32): SPEC-019/020/021 (contradiction, TTL, hardware). Memory split
- **130** (v3.33): 9-language READMEs (gl/eu/ca/fr/de/pt/it)
- **131** (v3.34): SPEC-022-028 specs. Galego fixed. LLM Trainer roadmap
- **132** (v3.35-37): Budget Guard, PM Keybindings, Savia voice in CONTRIBUTING+SECURITY, training data (1542 pairs)
- **133** (v3.38): PreCompact+PostToolUseFailure hooks, reranker. 10 community repos analyzed
- **134** (v3.39): SPEC-027 graph memory (entity-relation extraction)
- **135** (v3.40): Digest-to-memory bridge. 7 digest agents adapted to new memory
- **136** (v3.41-42): memory-architecture.md (379 lines, human-friendly). 25 PRs in one session
- **137** (v3.43-44): SPEC-029/030/031 (security auto-PR, Nuclei, workspace-doctor). jato+strix absorption. Triple audit (code/security/docs). 30+ repos analyzed

## Done — Eras 138-165: Architecture Exploitation (v3.45.0 → v3.97.0)

- **138-163** (v3.45-89): Temporal memory, hybrid search, agent evaluation, cognitive sectors, SaviaDivergent, test architect, CI quality gates, execution supervisor
- **164** (v3.90-96): Getting-started 7 languages, test auditor 80+ scores, AgentScope research, hidden features activation (3 new hooks, raised output limits, deferred tool loading)
- **165** (v3.97): SPEC-067 CLAUDE.md diet (121→48 lines, 60% token/turn savings). SPEC-068 hook enhancement (PreCompact tier classification, PostCompact session-hot reinjection, PostToolUseFailure structured error categorization). 12 new tests. Architecture review revealed CLAUDE.md per-turn cost — exploit-first approach

---

## In Progress

### SPEC-022 F2+F4: Semantic Compact + PR Context Loader (active)

### Tier 0+: Context Engineering — DeepAgents (active, branch: feature/deepagents-improvements)

Inspired by `langchain-ai/deepagents` investigation (2026-03-28). 8 specs generated.

**Week 1 — HIGH priority (arrancando):**
- **SPEC-138**: Token-aware compaction middleware — hook PostToolUse que lee `CLAUDE_CONTEXT_TOKENS_USED/MAX` y sugiere /compact por zonas (Verde/Gradual/Alerta/Crítica). Effort: 4-6h
- **SPEC-139**: Async subagent launcher — `savia-spawn.sh` + async-tasks.jsonl + status polling. Habilita orchestration non-blocking. Effort: 3-4h

**Week 2 — MEDIUM priority:**
- **SPEC-140**: Progressive skill disclosure — `build-skill-manifest.sh` + `.claude/skill-manifests.json` + `/skill-read` command. 95% token reduction (28K → 1.3K tokens). Effort: 3-4h
- **SPEC-141**: Tool-call healing — PreToolUse hook que valida `file_path`/`command` antes de ejecutar. Bloquea parámetros vacíos con diagnóstico claro. Effort: 2-3h
- **SPEC-142**: Memory hygiene automation — `scripts/memory-hygiene.sh` en background SessionStart. Archiva >90 días, dedup, trunca. Effort: 2-3h
- **SPEC-144**: Context-aware skill loading — `scripts/skill-loader.sh --task "..." --budget 800`. Keyword scoring + token budget greedy. Effort: 6-8h

**LOW priority (propuestas/post-release):**
- **SPEC-143**: Middleware intercept proposal — Feature request a Anthropic para `mode: "transform"` en hooks. No implementable hoy.
- **SPEC-145**: Dependency graph visualization — Grafo Mermaid de dependencias skills↔hooks↔specs. Effort: 2-3h

### SaviaClaw Voice (paused — needs Jabra) · Web Phase 4 (paused) · Mobile v0.2 (paused)

---

## Planned — Q2 2026

### Tier 0: Quick wins (DONE in v3.44.0)
- ~~SPEC-031: Workspace Doctor (4.85)~~ DONE
- ~~SPEC-029: Security Auto-Remediation PRs (4.80)~~ DONE
- ~~SPEC-030: Nuclei Scanner Integration (4.45)~~ DONE

### Tier 1: Memoria Viva
- **P1.** Web Git Manager (4.90) — spec exists
- **P2.** SPEC-034: Temporal Memory (4.75) — hechos con valid_from/valid_to, Graphiti-inspired
- **P3.** Web Test Coverage (4.70)
- **P4.** SPEC-036: Agent Evaluation Framework (4.65) — golden sets + metricas, DeepEval-inspired
- **P5.** SPEC-035: Hybrid Search (4.55) — graph+vector+reranker, LightRAG-inspired
- **P6.** SaviaClaw Sensors (4.95) — BLOCKED: BME280
- **P7.** SPEC-037: Cognitive Memory Sectors (4.35) — 5 sectores con decay propio, OpenMemory-inspired
- **P8.** SPEC-032: Security Benchmarks (4.30) — Juice Shop/DVWA
- **P9.** Web Notifications RT (4.30) · **P10.** Web Approvals (4.10)

## Planned — Q3 2026

### Tier 2: Evaluacion y Confianza
- **P11.** SaviaClaw Actuators (4.80) — needs hardware
- **P12.** Context Engineering Audit (4.50)
- **P13.** SaviaClaw Meeting Collaboration (4.15)
- **P14.** SPEC-033: Security Skills Modulares (3.85) — 10 categorias, strix-inspired
- **P15.** Supervisor Agent (3.80) · **P16.** Competence extend (3.75) · **P17.** Mobile PWA (3.70)

## Proposed — Q4 2026+ (Tier 3-4)

### Tier 3: Interoperabilidad
- **SPEC-023 Fases 2-4: Savia LLM Trainer** (4.90) — Fase 1 DONE
- A2A Protocol — exponer agentes via estandar Google/Strands (4.20)
- Serena MCP — comprension semantica del codigo via LSP (4.00)
- Extended Time Horizon (multi-day autonomous) — 3.75

### Tier 4: Autonomia Calibrada
- Guardrails semanticos — LLM evaluando outputs en tiempo real (3.90)
- Security Sandbox (Docker ligero) — 3.65, strix-inspired
- Self-improvement medible — lecciones → benchmark → mejora verificada (3.60)
- **SPEC-025: Chinese (ZH)** (3.60)
- Plugin Marketplace — 3.55 · Multi-Claw — 3.50 · SSO/LDAP — 3.35

---

## Rejected

Google Sheets · ServiceNow/SAP · Tableau · Kafka · VS Code ext · Cloud voice · SQLite memory · Multi-provider AI (jato) · Heavy infra RAG (RAGFlow) · Opaque memory DBs (sovereignty lost)

## Scoring: PM Impact 30% · Anti lock-in 25% · FOSS 20% · Inverse complexity 15% · Flow 10%

## Sources: Eras 1-137 · SaviaClaw · Web · Engram · Supermemory · Nomad · LightRAG · Hooks Mastery · n8n-MCP · jato · strix · Graphiti · OpenMemory · A-Mem · CrewAI · DeepEval · Giskard · Continue · Backlog.md · Serena · Strands · **DeepAgents (2026-03-28)**
