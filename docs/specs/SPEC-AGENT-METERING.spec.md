# Spec: Per-Agent Token Metering

**Task ID:**        SPEC-AGENT-METERING
**PBI padre:**      Observability & Cost Control
**Sprint:**         Backlog
**Fecha creacion:** 2026-03-27
**Creado por:**     sdd-spec-writer

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4h
**Estado:**         Pendiente
**Max Turns:**      40
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

pm-workspace invoca 47 subagentes via the Task tool. Each agent has a
conceptual token budget defined in `agent-context-budget.md` (Heavy=12K,
Standard=8K, Light=4K, Minimal=2K) but there is NO enforcement, NO
measurement of actual consumption, and NO comparison of budget vs actual.

Inspired by OmniArena's per-agent metering, this spec adds:
1. A `token_budget` field to every agent frontmatter
2. Actual token recording in the existing `agent-trace-log.sh` hook
3. Budget-exceeded alerts logged to a dedicated JSONL file
4. Enhancement of `/agent-cost` to show budget vs actual columns

**Criterios de Aceptacion (extracto relevante):**
- [ ] Every agent `.md` has a `token_budget` field in its frontmatter
- [ ] `agent-trace-log.sh` records `tokens_in`, `tokens_out`, and `token_budget` per invocation
- [ ] When `tokens_in + tokens_out > token_budget`, an alert entry is appended to `budget-alerts.jsonl`
- [ ] `/agent-cost` displays budget, actual, and delta columns
- [ ] Existing BATS tests still pass; new tests cover metering logic

---

## 2. Contrato Tecnico

### 2.1 Agent Frontmatter Extension

Every agent file in `.claude/agents/*.md` gains a `token_budget` field:

```yaml
---
name: architect
token_budget: 13000
# ... existing fields unchanged
---
```

Budget values derived from `agent-context-budget.md` categories:

| Category | token_budget | Agents |
|---|---|---|
| Heavy | 13000 | architect, security-guardian, code-reviewer, reflection-validator, pentester, drift-auditor, visual-digest, pdf-digest, meeting-confidentiality-judge, meeting-risk-analyst, infrastructure-agent, sdd-spec-writer, business-analyst, cobol-developer |
| Standard | 8500 | dotnet-developer, typescript-developer, frontend-developer, java-developer, python-developer, go-developer, rust-developer, php-developer, mobile-developer, ruby-developer, test-engineer, test-runner, coherence-validator, frontend-test-runner, security-attacker, security-defender, security-auditor, visual-qa-agent, dev-orchestrator, meeting-digest, commit-guardian, diagram-architect, web-e2e-tester, word-digest, excel-digest, pptx-digest |
| Light | 4500 | tech-writer, performance-analyst |
| Minimal | 2200 | azure-devops-operator, memory-agent |

The `token_budget` is the sum of `max_context_tokens + output_max_tokens` for each
category, giving a total round-trip budget per invocation.

### 2.2 Hook: agent-trace-log.sh Changes

**Current JSONL line format:**
```json
{"timestamp":"...","agent":"...","command":"task","tokens_in":N,"tokens_out":N,"duration_ms":N,"files_modified":[],"outcome":"...","scope_violations":[]}
```

**New JSONL line format (add `token_budget` and `budget_exceeded` fields):**
```json
{"timestamp":"...","agent":"...","command":"task","tokens_in":N,"tokens_out":N,"token_budget":N,"budget_exceeded":false,"duration_ms":N,"files_modified":[],"outcome":"...","scope_violations":[]}
```

New fields:
- `token_budget` (integer): the budget from the agent frontmatter. `0` if agent not found.
- `budget_exceeded` (boolean): `true` if `tokens_in + tokens_out > token_budget`.

### 2.3 Budget Alert File

Path: `projects/{proyecto}/traces/budget-alerts.jsonl`

Written ONLY when `budget_exceeded == true`. One line per violation:

```json
{"timestamp":"2026-03-27T10:15:00Z","agent":"architect","tokens_in":9200,"tokens_out":5100,"token_budget":13000,"total":14300,"overage":1300,"overage_pct":10}
```

Fields:
- `timestamp` (string): ISO 8601 UTC
- `agent` (string): agent name from frontmatter
- `tokens_in` (integer): estimated input tokens
- `tokens_out` (integer): estimated output tokens
- `token_budget` (integer): budget from frontmatter
- `total` (integer): `tokens_in + tokens_out`
- `overage` (integer): `total - token_budget`
- `overage_pct` (integer): `round((overage / token_budget) * 100)`

### 2.4 Helper Script: scripts/agent-budget-lookup.sh

A small utility that extracts `token_budget` from an agent frontmatter file.

**Interface:**
```bash
bash scripts/agent-budget-lookup.sh <agent-name>
# stdout: integer (the budget), or "0" if agent not found
# exit 0 always
```

**Algorithm:**
1. Look for `.claude/agents/<agent-name>.md`
2. Parse YAML frontmatter between `---` delimiters
3. Extract `token_budget:` value
4. Print to stdout
5. If file not found or field missing, print `0`

### 2.5 /agent-cost Command Enhancement

The existing `/agent-cost` command (`.claude/commands/agent-cost.md`) adds:

**New columns in output table:**
```
| Agent | Invocations | Tokens In | Tokens Out | Budget | Actual | Delta | Status |
```

Where:
- `Budget` = `token_budget` (from latest trace for that agent)
- `Actual` = average `tokens_in + tokens_out` across invocations
- `Delta` = `Actual - Budget` (negative = under budget, positive = over)
- `Status` = "OK" if Delta <= 0, "OVER" if Delta > 0

**New section "Budget Violations":**
```
Budget Violations (last 30 days):
| Agent | Count | Avg Overage | Max Overage | Recommendation |
```

Recommendations:
- Overage > 50%: "Reduce input context or split task"
- Overage 20-50%: "Review context selection strategy"
- Overage < 20%: "Minor — consider increasing budget"

---

## 3. Reglas de Negocio

| # | Regla | Comportamiento |
|---|---|---|
| RN-01 | `token_budget` must be a positive integer in agent frontmatter | If missing or 0, hook uses 0 and `budget_exceeded` is always false |
| RN-02 | Token estimation uses `length / 4` (existing algorithm) | No change to estimation method |
| RN-03 | Budget alert written only when `tokens_in + tokens_out > token_budget` AND `token_budget > 0` | Agents without budget (budget=0) never trigger alerts |
| RN-04 | Alert file is append-only | Never truncate or rotate; human decides cleanup |
| RN-05 | `/agent-cost` reads both `agent-traces.jsonl` and `budget-alerts.jsonl` | If budget-alerts file missing, show "No violations" |
| RN-06 | Hook must not block (async, exit 0 always) | Errors in budget lookup or alert write are silently ignored |
| RN-07 | Agent frontmatter changes must not break existing agent behavior | `token_budget` is informational only; no enforcement (no blocking) |

---

## 4. Constraints

### Performance
| Metrica | Limite |
|---|---|
| Hook execution time added | < 50ms (lookup is grep + awk on a single file) |
| Alert file growth | ~150 bytes per violation, unbounded (append-only) |

### Compatibility
| Elemento | Constraint |
|---|---|
| Bash | POSIX-compatible (works in Git Bash on Windows) |
| Existing traces | New fields added; old consumers ignore unknown fields (JSON forward-compatible) |
| Agent files | Only add field; no removal or rename of existing fields |

---

## 5. Test Scenarios

### Scenario 1: Budget lookup for known agent
```
Given agent file `.claude/agents/architect.md` contains `token_budget: 13000`
When `bash scripts/agent-budget-lookup.sh architect`
Then stdout is "13000" and exit code is 0
```

### Scenario 2: Budget lookup for unknown agent
```
Given no file `.claude/agents/nonexistent.md` exists
When `bash scripts/agent-budget-lookup.sh nonexistent`
Then stdout is "0" and exit code is 0
```

### Scenario 3: Budget lookup for agent without token_budget field
```
Given agent file `.claude/agents/legacy-agent.md` exists WITHOUT token_budget
When `bash scripts/agent-budget-lookup.sh legacy-agent`
Then stdout is "0" and exit code is 0
```

### Scenario 4: Trace line includes budget fields (under budget)
```
Given TOOL_NAME=Task, agent=architect, TOOL_INPUT length=20000 chars, TOOL_OUTPUT length=12000 chars
And architect has token_budget=13000
When agent-trace-log.sh executes
Then the JSONL line contains "token_budget":13000,"budget_exceeded":false
And tokens_in=5000, tokens_out=3000 (20000/4, 12000/4)
And total 8000 < 13000, so budget_exceeded=false
And NO line is appended to budget-alerts.jsonl
```

### Scenario 5: Trace line with budget exceeded
```
Given TOOL_NAME=Task, agent=azure-devops-operator, TOOL_INPUT length=8000, TOOL_OUTPUT length=4000
And azure-devops-operator has token_budget=2200
When agent-trace-log.sh executes
Then tokens_in=2000, tokens_out=1000, total=3000
And 3000 > 2200, so budget_exceeded=true
And a line IS appended to budget-alerts.jsonl with overage=800, overage_pct=36
```

### Scenario 6: Non-Task tool still ignored
```
Given TOOL_NAME=Bash
When agent-trace-log.sh executes
Then exit 0, no trace written, no alert written
```

### Scenario 7: Existing BATS tests still pass
```
Given the existing test-agent-trace-log.bats file
When `bats tests/hooks/test-agent-trace-log.bats`
Then all existing tests pass (no regressions)
```

### Scenario 8: agent-cost shows budget columns
```
Given agent-traces.jsonl has 5 entries for architect with token_budget=13000
And average actual = 10500
When /agent-cost is executed
Then table includes architect row with Budget=13000, Actual=10500, Delta=-2500, Status=OK
```

---

## 6. Ficheros a Crear / Modificar

### Crear (nuevos)
```
scripts/agent-budget-lookup.sh              # Extracts token_budget from agent frontmatter
tests/hooks/test-agent-budget-lookup.bats   # BATS tests for the lookup script
```

### Modificar (existentes)
```
.claude/hooks/agent-trace-log.sh            # Add token_budget lookup, budget_exceeded field, alert write
.claude/commands/agent-cost.md              # Add budget vs actual columns and violations section
tests/hooks/test-agent-trace-log.bats       # Add scenarios 4-6 to existing test suite
```

### Modificar (bulk — add token_budget to frontmatter)
```
.claude/agents/architect.md                 # token_budget: 13000
.claude/agents/security-guardian.md         # token_budget: 13000
.claude/agents/code-reviewer.md             # token_budget: 13000
.claude/agents/reflection-validator.md      # token_budget: 13000
.claude/agents/pentester.md                 # token_budget: 13000
.claude/agents/drift-auditor.md             # token_budget: 13000
.claude/agents/visual-digest.md             # token_budget: 13000
.claude/agents/pdf-digest.md                # token_budget: 13000
.claude/agents/meeting-confidentiality-judge.md  # token_budget: 13000
.claude/agents/meeting-risk-analyst.md      # token_budget: 13000
.claude/agents/infrastructure-agent.md      # token_budget: 13000
.claude/agents/sdd-spec-writer.md           # token_budget: 13000
.claude/agents/business-analyst.md          # token_budget: 13000
.claude/agents/cobol-developer.md           # token_budget: 13000
.claude/agents/dotnet-developer.md          # token_budget: 8500
.claude/agents/typescript-developer.md      # token_budget: 8500
.claude/agents/frontend-developer.md        # token_budget: 8500
.claude/agents/java-developer.md            # token_budget: 8500
.claude/agents/python-developer.md          # token_budget: 8500
.claude/agents/go-developer.md              # token_budget: 8500
.claude/agents/rust-developer.md            # token_budget: 8500
.claude/agents/php-developer.md             # token_budget: 8500
.claude/agents/mobile-developer.md          # token_budget: 8500
.claude/agents/ruby-developer.md            # token_budget: 8500
.claude/agents/test-engineer.md             # token_budget: 8500
.claude/agents/test-runner.md               # token_budget: 8500
.claude/agents/coherence-validator.md       # token_budget: 8500
.claude/agents/frontend-test-runner.md      # token_budget: 8500
.claude/agents/security-attacker.md         # token_budget: 8500
.claude/agents/security-defender.md         # token_budget: 8500
.claude/agents/security-auditor.md          # token_budget: 8500
.claude/agents/visual-qa-agent.md           # token_budget: 8500
.claude/agents/dev-orchestrator.md          # token_budget: 8500
.claude/agents/meeting-digest.md            # token_budget: 8500
.claude/agents/commit-guardian.md           # token_budget: 8500
.claude/agents/diagram-architect.md         # token_budget: 8500
.claude/agents/web-e2e-tester.md            # token_budget: 8500
.claude/agents/word-digest.md               # token_budget: 8500
.claude/agents/excel-digest.md              # token_budget: 8500
.claude/agents/pptx-digest.md               # token_budget: 8500
.claude/agents/tech-writer.md               # token_budget: 4500
.claude/agents/performance-analyst.md       # token_budget: 4500  (if exists)
.claude/agents/azure-devops-operator.md     # token_budget: 2200
.claude/agents/memory-agent.md              # token_budget: 2200
```

### NO tocar
```
.claude/hooks/session-init.sh               # Unrelated hook
docs/rules/domain/agent-context-budget.md # Reference doc, not code
scripts/context-tracker.sh                  # Separate tracking system
```

---

## 7. Codigo de Referencia

### Existing hook pattern (agent-trace-log.sh lines 24-52):
```bash
AGENT_NAME=$(echo "$TOOL_INPUT" | grep -o '"agent":\s*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
# ... token estimation ...
TOKENS_IN=$((INPUT_LENGTH / 4))
TOKENS_OUT=$((OUTPUT_LENGTH / 4))
# ... JSONL construction ...
echo "$TRACE_LINE" >> "$TRACES_DIR/agent-traces.jsonl" 2>/dev/null || true
```

### Frontmatter parsing pattern (used in validate-commands.sh):
```bash
# Extract field from YAML frontmatter between --- delimiters
awk '/^---$/{ if(++c==2) exit } c==1 && /^token_budget:/ { print $2 }' "$file"
```

---

## 8. Configuracion de Entorno

```bash
# Project structure
PROJECT_DIR="."
AGENTS_DIR=".claude/agents"
HOOKS_DIR=".claude/hooks"
TRACES_DIR="projects/{proyecto}/traces"

# Verification commands
bash tests/run-all.sh                                    # All BATS suites
bats tests/hooks/test-agent-trace-log.bats               # Hook tests
bats tests/hooks/test-agent-budget-lookup.bats            # Lookup tests
bash scripts/agent-budget-lookup.sh architect             # Manual check: should print 13000
```

---

## 9. Implementation Guide

### Step 1: Create scripts/agent-budget-lookup.sh

```bash
#!/usr/bin/env bash
set -uo pipefail
# Extracts token_budget from agent frontmatter
# Usage: agent-budget-lookup.sh <agent-name>
# Output: integer on stdout (0 if not found)

AGENT_NAME="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_FILE="$SCRIPT_DIR/.claude/agents/${AGENT_NAME}.md"

if [[ -z "$AGENT_NAME" ]] || [[ ! -f "$AGENT_FILE" ]]; then
  echo "0"
  exit 0
fi

BUDGET=$(awk '/^---$/{ if(++c==2) exit } c==1 && /^token_budget:/ { gsub(/[^0-9]/, "", $2); print $2 }' "$AGENT_FILE" 2>/dev/null)

echo "${BUDGET:-0}"
exit 0
```

### Step 2: Modify agent-trace-log.sh

After computing TOKENS_IN and TOKENS_OUT, add:

```bash
# Look up budget
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN_BUDGET=$(bash "$SCRIPT_DIR/scripts/agent-budget-lookup.sh" "$AGENT_NAME" 2>/dev/null || echo "0")
TOKEN_BUDGET=${TOKEN_BUDGET:-0}

TOTAL_TOKENS=$((TOKENS_IN + TOKENS_OUT))
BUDGET_EXCEEDED="false"
if [[ "$TOKEN_BUDGET" -gt 0 ]] && [[ "$TOTAL_TOKENS" -gt "$TOKEN_BUDGET" ]]; then
  BUDGET_EXCEEDED="true"
fi
```

Add `token_budget` and `budget_exceeded` to the JSONL line.

If `BUDGET_EXCEEDED == "true"`, append alert:

```bash
if [[ "$BUDGET_EXCEEDED" == "true" ]]; then
  OVERAGE=$((TOTAL_TOKENS - TOKEN_BUDGET))
  OVERAGE_PCT=$(( (OVERAGE * 100) / TOKEN_BUDGET ))
  ALERTS_DIR="$TRACES_DIR"
  ALERT_LINE="{\"timestamp\":\"$TIMESTAMP\",\"agent\":\"$AGENT_NAME\",\"tokens_in\":$TOKENS_IN,\"tokens_out\":$TOKENS_OUT,\"token_budget\":$TOKEN_BUDGET,\"total\":$TOTAL_TOKENS,\"overage\":$OVERAGE,\"overage_pct\":$OVERAGE_PCT}"
  echo "$ALERT_LINE" >> "$ALERTS_DIR/budget-alerts.jsonl" 2>/dev/null || true
fi
```

### Step 3: Add token_budget to all 44 agent frontmatter files

For each agent file, insert `token_budget: NNNN` as the last field before the closing `---`.

### Step 4: Update agent-cost.md command

Add budget vs actual table columns and a "Budget Violations" section that reads
`budget-alerts.jsonl`.

### Step 5: Write BATS tests

File: `tests/hooks/test-agent-budget-lookup.bats`
Cover scenarios 1-3.

File: `tests/hooks/test-agent-trace-log.bats` (extend)
Cover scenarios 4-6.

---

## 10. Checklist Pre-Entrega

### Implementacion
- [ ] `scripts/agent-budget-lookup.sh` created and executable
- [ ] `.claude/hooks/agent-trace-log.sh` modified with budget fields
- [ ] All 44 agent `.md` files have `token_budget` in frontmatter
- [ ] `.claude/commands/agent-cost.md` updated with budget columns
- [ ] `tests/hooks/test-agent-budget-lookup.bats` created with 3+ scenarios
- [ ] `tests/hooks/test-agent-trace-log.bats` extended with budget scenarios
- [ ] `bash tests/run-all.sh` passes (zero failures)

### Especifico para agente
- [ ] No design decisions taken outside this spec
- [ ] No files created beyond those listed in section 6
- [ ] Agent frontmatter changes are additive only (no field removals)
- [ ] Hook remains async (exit 0 always, never blocks)

---

## 11. Notas para el Revisor

- The `length / 4` token estimation is a rough heuristic. Future work could
  integrate actual API response headers for precise counts. This spec
  deliberately preserves the existing estimation to minimize risk.
- Budget values (13000, 8500, 4500, 2200) are `max_context_tokens + output_max_tokens`
  from `agent-context-budget.md`. They can be tuned per-agent after collecting
  real data for 2-3 sprints.
- The alert system is informational only (no blocking). Enforcement would
  require a PreToolUse hook, which is out of scope for this spec.
- Windows Git Bash compatibility: avoid `date +%s%N` (not supported).
  Use `date -u +"%Y-%m-%dT%H:%M:%SZ"` which is already in the hook.
