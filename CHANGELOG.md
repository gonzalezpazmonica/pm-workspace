# Changelog — pm-workspace

## [2.40.0] — 2026-03-07

### Added — Era 69: SDLC State Machine

Formal state machine for development lifecycle with 8 states, configurable gates, and audit trail.

- **`/sdlc-status {task-id}`** — Current state, available transitions, gate requirements.
- **`/sdlc-advance {task-id}`** — Evaluate gates and advance to next state.
- **`/sdlc-policy {project}`** — View and configure gate policies per project.
- **`sdlc-state-machine` skill** — 8 states: BACKLOG→DISCOVERY→DECOMPOSED→SPEC_READY→IN_PROGRESS→VERIFICATION→REVIEW→DONE.
- **`sdlc-gates` rule** — Default gate configuration with per-project overrides. Full audit trail.

### Technical Details

States: BACKLOG (idea) → DISCOVERY (investigation) → DECOMPOSED (technical breakdown) → SPEC_READY (documentation complete) → IN_PROGRESS (development) → VERIFICATION (testing) → REVIEW (code review) → DONE (production).

Transitions require gates:
- BACKLOG→DISCOVERY: acceptance criteria defined
- SPEC_READY→IN_PROGRESS: spec approved + security review passed
- VERIFICATION→REVIEW: all 5 verification layers
- REVIEW→DONE: code review + prod tests + deployment

State persisted in `projects/{project}/state/`. Audit trail: timestamp, actor, gate results.
