# Spec: Wave Execution in DAG Scheduling

**Task ID:**        SPEC-WAVE-DAG
**PBI padre:**      DAG Scheduling Skill Enhancement
**Sprint:**         2026-07
**Fecha creacion:** 2026-03-27
**Creado por:**     sdd-spec-writer (Opus 4.6)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4h
**Estado:**         Pendiente

---

## 1. Contexto y Objetivo

The existing `dag-scheduling` skill (`.claude/skills/dag-scheduling/SKILL.md`) groups
SDD pipeline phases into cohorts and executes them in parallel. However, the cohort
computation is tightly coupled to the SDD pipeline structure (spec-generate, dev-session,
etc.) and lacks a generic, reusable wave-execution engine.

This spec introduces a **wave executor** inspired by the "Get Shit Done" philosophy:
independent tasks run in parallel waves, dependent tasks wait. Each wave commits
atomically. The wave executor becomes the engine underneath `dag-scheduling`, usable
by `/dag-execute` and any future orchestration that needs dependency-ordered parallel
execution of bash commands.

**Objective:** Extend `dag-scheduling` with a `wave-executor.sh` script that:
1. Accepts a task graph (JSON) as input
2. Groups tasks into waves by dependency level (topological sort)
3. Executes each wave in parallel (`bash & + wait`)
4. Verifies all tasks in a wave succeeded before proceeding to the next
5. Produces a structured execution report (JSON)

**Acceptance Criteria (from PBI):**
- [ ] Tasks with no dependencies run in wave 0
- [ ] Tasks depending only on wave-0 tasks run in wave 1, and so on
- [ ] Each wave runs tasks in parallel using background processes
- [ ] A failed task in any wave stops the pipeline immediately
- [ ] Execution report includes per-task timing, exit codes, and wave assignment
- [ ] Max parallel tasks per wave respects SDD_MAX_PARALLEL_AGENTS (default 5)

---

## 2. Contrato Tecnico

### 2.1 Input Format (task-graph JSON)

The wave executor reads a JSON file describing a directed acyclic graph of tasks.

```json
{
  "max_parallel": 5,
  "tasks": [
    {
      "id": "spec-generate",
      "command": "bash scripts/sdd/spec-generate.sh AB#1234",
      "depends_on": [],
      "expected_files": ["output/specs/AB1234.spec.md"],
      "timeout_seconds": 300
    },
    {
      "id": "spec-slice",
      "command": "bash scripts/sdd/spec-slice.sh AB#1234",
      "depends_on": ["spec-generate"],
      "expected_files": ["output/specs/AB1234-slices.json"],
      "timeout_seconds": 480
    },
    {
      "id": "security-review",
      "command": "bash scripts/sdd/security-review.sh AB#1234",
      "depends_on": ["spec-generate"],
      "expected_files": ["output/security/AB1234-review.md"],
      "timeout_seconds": 360
    }
  ]
}
```

**Field definitions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `max_parallel` | integer | No (default: 5) | Max tasks per wave. Maps to SDD_MAX_PARALLEL_AGENTS |
| `tasks` | array | Yes | List of task objects |
| `tasks[].id` | string | Yes | Unique identifier (kebab-case, 1-64 chars) |
| `tasks[].command` | string | Yes | Bash command to execute |
| `tasks[].depends_on` | string[] | Yes (empty array if none) | IDs of tasks this depends on |
| `tasks[].expected_files` | string[] | No (default: []) | Files that must exist after task completes |
| `tasks[].timeout_seconds` | integer | No (default: 1800) | Per-task timeout |

### 2.2 Output Format (execution-report JSON)

```json
{
  "status": "success",
  "total_waves": 3,
  "total_tasks": 6,
  "wall_clock_seconds": 142,
  "sequential_estimate_seconds": 238,
  "speedup_percent": 40,
  "waves": [
    {
      "wave": 0,
      "tasks": [
        {
          "id": "spec-generate",
          "status": "success",
          "exit_code": 0,
          "duration_seconds": 28,
          "expected_files_present": true
        }
      ],
      "wave_duration_seconds": 28
    },
    {
      "wave": 1,
      "tasks": [
        {
          "id": "spec-slice",
          "status": "success",
          "exit_code": 0,
          "duration_seconds": 45,
          "expected_files_present": true
        },
        {
          "id": "security-review",
          "status": "success",
          "exit_code": 0,
          "duration_seconds": 38,
          "expected_files_present": true
        }
      ],
      "wave_duration_seconds": 45
    }
  ]
}
```

**Field definitions:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | `"success"` or `"failed"` |
| `total_waves` | integer | Number of waves executed |
| `total_tasks` | integer | Total tasks in the graph |
| `wall_clock_seconds` | integer | Actual elapsed time |
| `sequential_estimate_seconds` | integer | Sum of all task durations |
| `speedup_percent` | integer | `round((1 - wall/sequential) * 100)` |
| `waves[].wave` | integer | Wave index (0-based) |
| `waves[].tasks[].status` | string | `"success"`, `"failed"`, `"timeout"`, `"skipped"` |
| `waves[].tasks[].exit_code` | integer | Process exit code |
| `waves[].tasks[].duration_seconds` | integer | Actual execution time |
| `waves[].tasks[].expected_files_present` | boolean | All expected_files exist |
| `waves[].wave_duration_seconds` | integer | Max duration among tasks in wave |

### 2.3 CLI Interface

```bash
# Execute a task graph
bash scripts/wave-executor.sh <task-graph.json> [--report <output.json>]

# Exit codes:
#   0  — all waves completed successfully
#   1  — a task failed in some wave
#   2  — invalid input (cycle detected, missing dependency, bad JSON)
#   3  — timeout exceeded for a task
```

Arguments:
- Positional 1: path to task-graph JSON file (required)
- `--report`: path for execution report JSON (default: stdout)

---

## 3. Reglas de Negocio

| # | Regla | Error behavior | Exit code |
|---|-------|---------------|-----------|
| RN-01 | Task IDs must be unique within the graph | Print error to stderr, abort | 2 |
| RN-02 | The graph must be acyclic (no cycles) | Print cycle path to stderr, abort | 2 |
| RN-03 | All `depends_on` references must point to existing task IDs | Print missing ID to stderr, abort | 2 |
| RN-04 | Tasks with no dependencies are assigned to wave 0 | N/A | N/A |
| RN-05 | A task is assigned to wave `max(wave_of_dependency) + 1` | N/A | N/A |
| RN-06 | If a wave has more tasks than `max_parallel`, split into sub-waves | N/A | N/A |
| RN-07 | All tasks in a wave must complete before the next wave starts | N/A | N/A |
| RN-08 | If ANY task in a wave fails (exit code != 0), stop the pipeline | Remaining waves get status `"skipped"` | 1 |
| RN-09 | If a task exceeds `timeout_seconds`, kill it | Task gets status `"timeout"` | 3 |
| RN-10 | After each wave, verify `expected_files` exist for every task | If missing, task status = `"failed"` | 1 |
| RN-11 | Empty task graph (0 tasks) produces empty report with status `"success"` | N/A | 0 |

---

## 4. Constraints and Limits

### Performance

| Metric | Limit | Note |
|--------|-------|------|
| Graph parsing time | < 1 second | For graphs up to 100 tasks |
| Wave overhead (scheduling) | < 500ms per wave | Time between waves excluding task execution |
| Max tasks in graph | 100 | Reject with exit 2 if exceeded |

### Compatibility

| Element | Constraint |
|---------|-----------|
| Shell | Bash 4.0+ (uses associative arrays) |
| Dependencies | `jq` (JSON parsing), `date` (timing) |
| Platform | Linux, macOS, Windows (Git Bash / WSL) |
| Encoding | UTF-8 for all I/O |

### Security

| Aspect | Requirement |
|--------|-------------|
| Command injection | Commands come from the JSON file which is under user control; no user-facing HTTP input |
| File paths | Validate `expected_files` paths do not contain `..` traversal |
| Timeout enforcement | Use `timeout` command (GNU coreutils) or bash trap with `SIGTERM` |

---

## 5. Test Scenarios

### Happy Path

```
Scenario: Three tasks, two waves, all succeed
  Given a task graph JSON with:
    - "compile" (no deps, command: "echo compiled")
    - "test-unit" (depends_on: ["compile"], command: "echo tested")
    - "test-integration" (depends_on: ["compile"], command: "echo integrated")
  When wave-executor.sh runs
  Then exit code is 0
  And report.status is "success"
  And report.total_waves is 2
  And wave 0 contains ["compile"]
  And wave 1 contains ["test-unit", "test-integration"]
  And speedup_percent > 0

Scenario: Single task with no dependencies
  Given a task graph with 1 task "build" (no deps, command: "echo built")
  When wave-executor.sh runs
  Then exit code is 0
  And report.total_waves is 1
  And wave 0 contains ["build"]

Scenario: Diamond dependency pattern
  Given tasks: A (no deps) -> B,C (depend on A) -> D (depends on B,C)
  When wave-executor.sh runs
  Then wave 0 = [A], wave 1 = [B, C], wave 2 = [D]
  And total_waves is 3
```

### Error Cases

```
Scenario: Task fails mid-wave
  Given tasks: "good" (command: "true") and "bad" (command: "false") both in wave 0
  When wave-executor.sh runs
  Then exit code is 1
  And report.status is "failed"
  And task "bad" has status "failed" and exit_code 1
  And no wave 1 tasks are executed (if any exist, they get status "skipped")

Scenario: Cycle detected
  Given tasks: A depends on B, B depends on A
  When wave-executor.sh runs
  Then exit code is 2
  And stderr contains "cycle detected"
  And no tasks are executed

Scenario: Missing dependency reference
  Given task "test" depends_on ["compile"] but "compile" is not in the graph
  When wave-executor.sh runs
  Then exit code is 2
  And stderr contains "unknown dependency: compile"

Scenario: Task timeout
  Given task "slow" with timeout_seconds=1 and command "sleep 10"
  When wave-executor.sh runs
  Then exit code is 3
  And task "slow" has status "timeout"

Scenario: Expected file missing after successful command
  Given task "generate" with command "true" and expected_files ["nonexistent.txt"]
  When wave-executor.sh runs
  Then exit code is 1
  And task "generate" has status "failed"
  And task "generate" has expected_files_present = false
```

### Edge Cases

```
Scenario: Empty task graph
  Given a JSON with "tasks": []
  When wave-executor.sh runs
  Then exit code is 0
  And report.status is "success"
  And report.total_waves is 0

Scenario: Wave exceeds max_parallel (splitting)
  Given max_parallel=2 and 4 independent tasks (A, B, C, D all with no deps)
  When wave-executor.sh runs
  Then tasks are split into sub-waves: wave 0 = [A, B], wave 1 = [C, D]
  And total_waves is 2

Scenario: All tasks in single linear chain
  Given A -> B -> C -> D (each depends on previous)
  When wave-executor.sh runs
  Then total_waves is 4, each wave has exactly 1 task
  And speedup_percent is 0

Scenario: Duplicate task ID
  Given two tasks both with id "build"
  When wave-executor.sh runs
  Then exit code is 2
  And stderr contains "duplicate task id: build"
```

---

## 6. Ficheros a Crear / Modificar

### Crear (nuevos)

```
scripts/wave-executor.sh              # Main wave execution engine (bash)
tests/test-wave-executor.bats         # BATS test suite for wave-executor
tests/fixtures/wave-dag-happy.json    # Fixture: 3 tasks, 2 waves, all succeed
tests/fixtures/wave-dag-diamond.json  # Fixture: diamond dependency A->B,C->D
tests/fixtures/wave-dag-cycle.json    # Fixture: cycle A->B->A
tests/fixtures/wave-dag-empty.json    # Fixture: empty task list
tests/fixtures/wave-dag-overflow.json # Fixture: 4 independent tasks, max_parallel=2
```

### Modificar (existentes)

```
.claude/skills/dag-scheduling/SKILL.md     # Add reference to wave-executor.sh in Fase 4
.claude/commands/dag-execute.md            # Update Paso 3 to delegate to wave-executor.sh
```

### NO tocar

```
.claude/skills/dag-scheduling/DOMAIN.md      # Domain concepts unchanged
docs/rules/domain/parallel-execution.md   # Rule unchanged, wave-executor complies with it
.claude/commands/dag-plan.md                 # Planning command unchanged
```

---

## 7. Codigo de Referencia

### Pattern: BATS test in this repo

```
tests/run-all.sh                      # Test runner pattern
tests/test-changelog.bats             # Example BATS test structure
```

### Pattern: bash scripts with set -euo pipefail

All scripts in `scripts/` use this header:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

### Pattern: jq for JSON processing

Scripts already use `jq` for JSON parsing (see `scripts/azdevops-queries.sh`).

---

## 8. Algoritmo de Wave Assignment (pseudocode)

This section is normative. The implementation MUST follow this algorithm.

```
function assign_waves(tasks):
    # Step 1 — Validate
    assert all task.id are unique                     # RN-01
    assert no cycles in dependency graph              # RN-02
    assert all depends_on references exist            # RN-03

    # Step 2 — Topological level assignment
    level = {}
    for task in topological_sort(tasks):
        if task.depends_on is empty:
            level[task.id] = 0
        else:
            level[task.id] = max(level[dep] for dep in task.depends_on) + 1

    # Step 3 — Group by level
    waves_raw = group_by(tasks, key=level[task.id])

    # Step 4 — Split waves exceeding max_parallel (RN-06)
    waves = []
    for wave_tasks in waves_raw:
        for chunk in chunks(wave_tasks, max_parallel):
            waves.append(chunk)

    return waves

function execute_waves(waves):
    report = { waves: [], status: "success" }
    for wave in waves:
        # Launch all tasks in parallel
        pids = {}
        for task in wave:
            start task.command in background with timeout
            pids[task.id] = (pid, start_time)
        # Wait for all
        wait for all pids
        # Collect results
        for task in wave:
            check exit code
            check expected_files exist
            record duration
        # Gate: if any failed, stop (RN-08)
        if any task failed:
            mark remaining waves as skipped
            report.status = "failed"
            break
    return report
```

---

## 9. Configuracion de Entorno

```bash
# Dependencies
jq --version        # Required: jq 1.6+
bash --version      # Required: bash 4.0+
timeout --version   # Required: GNU coreutils timeout (or gtimeout on macOS)

# Verification commands
bash scripts/wave-executor.sh tests/fixtures/wave-dag-happy.json --report /tmp/report.json
cat /tmp/report.json | jq .status   # Expected: "success"

# Run tests
bash tests/test-wave-executor.bats
```

---

## 10. Checklist Pre-Entrega

### Implementacion
- [ ] `scripts/wave-executor.sh` exists and is executable (`chmod +x`)
- [ ] Script starts with `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] Script is <= 150 lines (file-size-limit rule)
- [ ] All 11 business rules (RN-01 through RN-11) are implemented
- [ ] Exit codes match the contract (0, 1, 2, 3)
- [ ] JSON output matches the schema in section 2.2
- [ ] No hardcoded paths; all paths from input JSON

### Tests
- [ ] `tests/test-wave-executor.bats` exists with >= 10 test cases
- [ ] All happy path scenarios pass
- [ ] All error case scenarios pass
- [ ] All edge case scenarios pass
- [ ] Fixtures in `tests/fixtures/` match expected structure

### Integration
- [ ] `dag-scheduling/SKILL.md` updated with wave-executor reference
- [ ] `dag-execute.md` updated to reference wave-executor.sh in execution step
- [ ] No changes to files listed in "NO tocar"

### Verification
```bash
bash tests/test-wave-executor.bats                          # All tests pass
bash scripts/wave-executor.sh tests/fixtures/wave-dag-happy.json  # Exit 0
bash scripts/wave-executor.sh tests/fixtures/wave-dag-cycle.json  # Exit 2
```

---

## 11. Notas para el Revisor

- The wave executor is a generic engine. It does not know about SDD phases, specs,
  or Azure DevOps. It only knows about task IDs, commands, dependencies, and files.
  This decoupling is intentional: it makes the engine reusable for any DAG workflow.

- The `dag-execute` command becomes a thin orchestrator that builds the task-graph
  JSON from the SDD pipeline definition and passes it to `wave-executor.sh`.

- On macOS, GNU `timeout` may not be available. The script should check for `gtimeout`
  (from `brew install coreutils`) and fall back to a bash `SIGALRM` trap if neither exists.

- The 150-line limit applies. If the script grows beyond that, extract helper functions
  into `scripts/wave-executor-lib.sh` (sourced by the main script).
