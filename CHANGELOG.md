# Changelog — pm-workspace

All notable changes to this project will be documented in this file.

## [2.40.0] — 2026-03-07

### Added — Era 69: SDLC State Machine

Formal state machine for the development lifecycle with 8 states, configurable gates, and audit trail. Every transition validated against policy.

- **`/sdlc-status {task-id}`** — Current state, available transitions, gate requirements.
- **`/sdlc-advance {task-id}`** — Evaluate gates and advance to next state. Shows blockers if gates fail.
- **`/sdlc-policy {project}`** — View and configure gate policies per project.
- **`sdlc-state-machine` skill** — 8 states: BACKLOG→DISCOVERY→DECOMPOSED→SPEC_READY→IN_PROGRESS→VERIFICATION→REVIEW→DONE.
- **`sdlc-gates` rule** — Default gate configuration with per-project overrides. Full audit trail.

### Technical Details

States: BACKLOG (idea) → DISCOVERY (investigation) → DECOMPOSED (technical breakdown) → SPEC_READY (documentation complete) → IN_PROGRESS (active development) → VERIFICATION (testing & validation) → REVIEW (code review) → DONE (production).

Transitions require gates (evaluable conditions):
- BACKLOG→DISCOVERY: acceptance criteria defined
- SPEC_READY→IN_PROGRESS: spec approved + security review passed
- VERIFICATION→REVIEW: all 5 verification layers (unit, integration, e2e, performance, security)
- REVIEW→DONE: code review approved + prod tests passing + deployment successful

State persisted in `projects/{project}/state/`. Audit trail: every transition logged with timestamp, actor, gate results.

---

## [2.39.0] — 2026-03-01

Previous releases summary available in `.gitignore` archived versions.
