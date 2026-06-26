## SPEC-052 — Recursive Task Decomposition (2026-06-24)

### Added
- `scripts/task-decomposer.py`: heuristic recursive task decomposer (no LLM required)
- Classifies tasks as atomic/compound using keyword and conjunction signals
- Hour estimation via keyword patterns (auth=4h, API=3h, database=2h, etc.)
- Decomposition templates for known domains: auth, api, crud, frontend, database, notification, payment, search
- Conjunction splitting: "and / with / , ;" produces subtask titles automatically
- Constraints respected: min 2 / max 7 subtasks per compound node; max-depth 3 default
- `SAVIA_TASK_SIZE_HOURS` env var controls atomic threshold (default 4h)
- Output JSON tree: `{id, title, classification, estimated_hours, depth, can_parallelize, lineage, subtasks}`
- `--tree` flag prints ASCII tree to stderr
- `tests/scripts/test_task_decomposer.py`: 10 pytest tests covering all decomposition paths
