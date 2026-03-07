# Changelog

All notable changes to PM-Workspace will be documented in this file.

## [2.33.0] — 2026-03-07

### Added — Era 62: DAG Scheduling (Parallel Agent Orchestration)

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
