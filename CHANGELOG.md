# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.35.0] — 2026-03-07

### Added — Era 64: Verification Lattice

5-layer verification pipeline: deterministic → semantic → security → agentic → human. Each layer informs the next, culminating in a human review enriched by automated analysis.

- **`/verify-full {task-id}`** — Run all 5 verification layers. Progressive results, stop on critical failure.
- **`/verify-layer {N} {task-id}`** — Run specific layer for debugging.
- **`verification-lattice` skill** — 5 layers with dedicated agents: scripts (L1), code-reviewer (L2), security-reviewer (L3), architect (L4), human (L5).
- **`verification-policy` rule** — Layers 1-3 mandatory, L4 for risk>50, L5 always except risk<25. Auto-retry for automated layers.


Dependency-graph-based execution for SDD pipeline. Parallelizes independent phases (spec-slice + security-review, unit-tests + integration-tests + docs) while respecting dependencies. Reduces total execution time by 30-40% through intelligent cohorte scheduling and multi-agent orchestration.

- **`/dag-plan {task-id}`** — Visualize execution DAG, critical path, and estimated time savings vs. sequential. Shows cohortes parallelizable, bottlenecks, and holgura analysis.
- **`/dag-execute {task-id}`** — Execute SDD pipeline with parallel agents. Real-time progress tracking per cohorte, automatic retry on transient failure, atomic merge of results.
- **`dag-scheduling` skill** — 6-phase pipeline: parse DAG → critical path analysis → scheduling → parallel execution → synchronization → reporting.
- **`parallel-execution` rule** — Max 5 concurrent agents, worktree isolation, conflict prevention, timeout and recovery policies. Configurable via `SDD_MAX_PARALLEL_AGENTS`.

---

## [2.32.0] — 2026-03-07

### Added — Era 61: Google Chat Notifier

Rich notifications for PM events via Google Chat webhooks. Card-formatted messages for sprint status, deployments, escalations, and standup summaries.

- **`/chat-setup`** — Guide webhook configuration and send test message.
- **`/chat-notify {type} {project}`** — Send formatted notification: sprint-status, deployment, escalation, standup, custom.
- **`google-chat-notifier` skill** — 5 message types with Google Chat card format. Integrates with scheduled-messaging platform adapters.

---

[2.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v2.32.0
