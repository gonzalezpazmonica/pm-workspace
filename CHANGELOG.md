## [2.45.0] — 2026-03-07

### Added — Era 74: Session Recording

Record, replay, and export agent sessions for auditing, documentation, and training.

- **`/record-start`** — Begin recording all session actions. Creates unique session ID, stores events in JSONL format.
- **`/record-stop`** — Stop recording. Summary: duration, events count, files modified.
- **`/record-replay {session-id}`** — Replay recorded session with timeline. Chronological view of all actions performed.
- **`/record-export {session-id}`** — Export as markdown report to output/recordings/. Includes timeline, decisions, modified files, commands executed.
- **`session-recording` skill** — Records commands executed, files modified, API calls made, decisions taken, agent-notes generated, with timestamps. Storage: `data/recordings/{session-id}.jsonl` (one event per line). Use cases: compliance audit, onboarding training, postmortem analysis, documentation of complex operations.

---

# Changelog — pm-workspace

## [2.42.0] — 2026-03-07

### Added — Era 71: Evaluations Framework

Systematic evaluation of agent outputs for quality assurance with 5 built-in evaluation types, scoring rubrics, trend analysis, and automated regression detection.

- **`/eval-run {eval-name}`** — Execute evaluation: pbi-quality, spec-quality, estimation-accuracy, review-quality, assignment-quality. Applies rubric, scores outputs, generates report with findings.
- **`/eval-report {eval-name}`** — Display results and trends. Filter by `--sprint`, analyze with `--trend`. Detect regressions (>10% drop).
- **`/eval-create`** — Define custom evaluations with personalized rubrics. Interactive builder for name, description, criteria, scoring levels.
- **`evaluations-framework` skill** — 5 eval types with scoring rubrics (Excellent/Good/Fair/Poor), automated scheduling, trend analysis, regression detection. Storage: `data/evals/{eval-name}/`.
- **`eval-policy` rule** — Post-sprint evaluation (estimation-accuracy), monthly evals (pbi-quality, spec-quality), 10% regression alert threshold.

---


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
