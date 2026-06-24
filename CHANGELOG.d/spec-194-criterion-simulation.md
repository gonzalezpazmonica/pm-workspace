## SPEC-194 — Criterion Simulation Layer (2026-06-24)

### Added

- `scripts/criterion-simulation/operator-state-signals.py`: Computes operator-state signals (fatigue_score, pressure_score, override_rate, time_band) from local data only. Zero network calls. Reads deadline_proximity from ~/.savia/preferences.yaml if present.
- `scripts/criterion-simulation/trigger-evaluator.py`: Evaluates task context to decide if criterion-simulation should activate. Threshold: SAVIA_CS_TRIGGER_THRESHOLD (default 50). High-impact signals: touches_production (+25), touches_security (+30), touches_human_safety (+50), estimated_hours>16 (+15).
- `scripts/criterion-simulation/historical-priors.py`: Searches KG (SQLite .savia-kg/graph.db) for similar reverted tasks within lookback window. Graceful: returns {count:0} if KG absent.
- `scripts/criterion-simulation/reaffirmation-log.py`: Records conscious human reaffirmations (reaffirm) and problem reformulations (reframe). Enforces reason >= 20 chars for reaffirm (exit 2 if violated).
- `scripts/kg-schema-migrate-cs.py`: Idempotent SQLite migration adding frame_reaffirmations table (task_id, ts, operator, reason, verdict_before, tags). Separate from SPEC-193 migration.
- `.opencode/agents/criterion-simulation-judge.md`: Heavy-model LLM judge. Executes 4 meta-questions (frame challenge, historical priors, operator state, alternative reframing). Emits verdict FRAME_OK|FRAME_DOUBT|FRAME_REJECT + banner_text + confidence. Always includes is_simulation_disclaimer field.
- `.opencode/skills/meta-reflection/SKILL.md`: Protocol for the 4 meta-questions. Includes replacement protocol (reaffirm/reframe commands) and declared limitations.
- `.opencode/skills/meta-reflection/DOMAIN.md`: Conceptual knowledge: difference between evaluation (correct application of given criterion) and reflection (questioning the criterion itself). Cites origin quote 2026-06-13.
- `.opencode/hooks/criterion-simulation-challenge.sh`: Pre-task hook. Master switch SAVIA_CRITERION_SIMULATION=off (default; opt-in). Modes: shadow (telemetry only), advise (banner, no block), interrupt (banner + reaffirmation_required log). Exit 0 always. Never blocks.
- `docs/rules/domain/criterion-simulation-honesty.md`: Declares explicitly that this layer is NOT real criterion — it is a declared heuristic simulation of pause. Cites spec quote verbatim.
- `output/criterion-simulation/` directory: Telemetry events.jsonl + reaffirmations.jsonl.
- `tests/scripts/test_criterion_simulation_trigger.py`: 50 synthetic normal tasks (AC3: trigger rate <=20%), 10 high-impact tasks (AC4: trigger rate >=8/10), socket mock test (AC5: no network calls).
- `tests/scripts/test_criterion_simulation_misc.py`: reaffirmation-log validation (AC7), kg-schema-migrate-cs idempotency (AC14).
- `tests/test-criterion-simulation-hook.bats`: Hook tests covering AC1 (disclaimer), AC2 (exit 0 always), AC9 (JSONL telemetry), AC10 (shadow no stderr), AC11 (advise banner), AC12 (interrupt reaffirmation_required), AC13 (master switch off).

### Architecture note

Default is SAVIA_CRITERION_SIMULATION=off (opt-in). This layer interrupts visually but NEVER blocks execution. The disclaimer "simulacion de meta-reflexion, no tu criterio" appears in every banner. Deployment follows gradual migration: shadow (weeks 1-2) → advise partial (weeks 3-4) → advise broad → interrupt opt-in.

### ACs covered

AC1, AC2, AC3, AC4, AC5, AC7, AC9, AC10, AC11, AC12, AC13, AC14, AC16 (rule exists), AC19 (DOMAIN.md)
