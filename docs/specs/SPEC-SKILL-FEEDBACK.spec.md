# Spec: Skill Feedback Loop -- Track, rank, and deprecate skills by effectiveness

**Task ID:**        WORKSPACE (no Azure DevOps task -- workspace-level feature)
**PBI padre:**      N/A -- internal tooling, inspired by Context Hub pattern
**Sprint:**         2026-07 (current)
**Fecha creacion:** 2026-03-27
**Creado por:**     sdd-spec-writer (Opus 4.6)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     5h
**Estado:**         Pendiente

---

## 1. Contexto y Objetivo

pm-workspace has 82 skills. The existing `skill-evaluation` engine recommends
skills based on keyword matching (40%), project context (30%), and history
(30%), but the history component has no real data -- `eval-registry.json` is
empty. There is no mechanism to track whether a skill invocation actually
helped the user, no way to rank skills by measured effectiveness, and no
automated deprecation of skills that consistently fail or get rejected.

The `skill-lifecycle.md` rule defines maturity levels (experimental, beta,
stable) and archival criteria (90+ days unused, rating <30%), but these
criteria are checked manually and have no data pipeline feeding them.

**Objetivo:** Build the data pipeline that closes the feedback loop:
1. A JSONL log that records every skill invocation with its outcome
2. A scoring algorithm that ranks skills by effectiveness
3. A `/skill-rank` command that shows the ranking and flags deprecation candidates
4. Integration with `skill-auto-activation.md` so history_score uses real data

**Principio SDD:** This spec defines the log schema, scoring formula, command
output format, and integration points. The agent decides file organization
and implementation details within these contracts.

**Criterios de Aceptacion (extracto relevante):**
- [ ] Every skill activation records an entry in the JSONL log
- [ ] `/skill-rank` shows skills sorted by effectiveness score
- [ ] Skills with effectiveness <30% are flagged as deprecation candidates
- [ ] The scoring algorithm uses real invocation data, not placeholders

---

## 2. Contrato Tecnico

### 2.1 JSONL Log Schema

File: `data/skill-invocations.jsonl`

Each line is a JSON object with these exact fields:

```json
{
  "skill": "spec-driven-development",
  "command": "spec-generate",
  "timestamp": "2026-03-27T09:15:00Z",
  "project": "alpha",
  "outcome": "success",
  "duration_ms": 4500,
  "user_feedback": "accepted",
  "context_pct": 42
}
```

| Field | Type | Required | Values / Constraints |
|-------|------|----------|---------------------|
| `skill` | string | yes | Skill directory name (kebab-case) |
| `command` | string | yes | Slash command that triggered the skill |
| `timestamp` | string | yes | ISO 8601 UTC |
| `project` | string | no | Active project slug or `null` |
| `outcome` | string | yes | `"success"` or `"failure"` or `"partial"` |
| `duration_ms` | int | no | Wall-clock ms of skill execution, 0 if unknown |
| `user_feedback` | string | no | `"accepted"` or `"rejected"` or `"neutral"` or `null` |
| `context_pct` | int | no | Context usage % at time of invocation (0-100) |

Rules:
- Append-only. Never modify existing lines.
- Max file size: 2MB. At 2MB, rotate to `data/skill-invocations-{YYYYMMDD}.jsonl.gz`
- File is gitignored (local data).

### 2.2 Scoring Algorithm

For each skill with >=3 invocations in the last 90 days, compute:

```
success_rate = count(outcome=success) / total_invocations
accept_rate  = count(user_feedback=accepted) / count(user_feedback != null)
recency_weight = invocations_last_30d / invocations_last_90d  (0.0-1.0)

effectiveness = (success_rate * 0.50) + (accept_rate * 0.30) + (recency_weight * 0.20)
```

Effectiveness is a float 0.0 to 1.0, displayed as percentage (0-100%).

Skills with <3 invocations in 90 days: show as `"insufficient_data"`, do not
rank. Skills with 0 invocations in 90 days: show as `"dormant"`.

### 2.3 Deprecation Thresholds

| Effectiveness | Label | Action |
|---------------|-------|--------|
| >= 70% | `healthy` | No action |
| 50-69% | `underperforming` | Flag in output, suggest review |
| 30-49% | `weak` | Recommend archival |
| < 30% | `deprecation_candidate` | Strong recommendation to archive |

Cross-reference with `skill-lifecycle.md` maturity:
- `stable` skill falling to `weak` -> alert (regression)
- `experimental` skill at `weak` -> expected, suggest iteration
- Any skill `dormant` + maturity `experimental` -> archival candidate

### 2.4 `/skill-rank` Command Output

```
====================================================
  /skill-rank -- Skill Effectiveness Ranking
====================================================

  Period: last 90 days (2026-01-01 to 2026-03-27)
  Total invocations: 342
  Skills with data: 28 / 82

  -- Top 10 by effectiveness --

  #  Skill                        Eff%  Invocations  Status
  1  spec-driven-development      92%   45           healthy
  2  azure-devops-queries         88%   62           healthy
  3  capacity-planning            85%   18           healthy
  ...
  8  diagram-generation           52%   7            underperforming
  9  voice-inbox                  38%   4            weak
  10 ai-labor-impact              22%   3            deprecation_candidate

  -- Dormant (0 invocations in 90d): 12 skills --
  banking-architecture, nuclei-scanning, ...

  -- Insufficient data (<3 invocations): 42 skills --
  ...

  Deprecation candidates: 2 skills flagged.
  Run /skill-rank --detail {skill-name} for per-invocation breakdown.

  File: output/skill-ranking/20260327-skill-rank.md

====================================================
```

### 2.5 `/skill-rank` Subcommands

| Subcommand | Description | Output |
|------------|-------------|--------|
| `/skill-rank` (no args) | Full ranking table | Console summary + file |
| `/skill-rank --detail {name}` | Per-invocation log for one skill | Console table |
| `/skill-rank --dormant` | List dormant skills only | Console list |
| `/skill-rank --deprecated` | List deprecation candidates | Console list |
| `/skill-rank --export csv` | Export ranking as CSV | `output/skill-ranking/YYYYMMDD-ranking.csv` |

---

## 3. Reglas de Negocio

| # | Regla | Verificacion |
|---|-------|-------------|
| RN-01 | Every skill activation via `/skill-eval activate` MUST append a log entry | Test: activate a skill, verify JSONL has new line |
| RN-02 | Scoring ignores invocations older than 90 days | Test: add old entries, verify they do not affect score |
| RN-03 | Skills with <3 invocations are labeled `insufficient_data`, not ranked | Test: skill with 2 invocations shows as insufficient |
| RN-04 | Skills with 0 invocations in 90d are labeled `dormant` | Test: skill with no recent entries shows as dormant |
| RN-05 | Log rotation triggers at 2MB; old file compressed with gzip | Test: write >2MB, verify rotation occurred |
| RN-06 | Effectiveness score is 0.0-1.0 (displayed as 0-100%) | Test: verify score bounds with edge data |
| RN-07 | `stable` skill falling to `weak` generates regression alert | Test: mock data for stable skill with poor outcomes |
| RN-08 | JSONL log is append-only; existing entries never modified | Test: verify no mutation of prior lines |
| RN-09 | User feedback `null` is excluded from `accept_rate` denominator | Test: 3 success + 0 feedback -> accept_rate=N/A |
| RN-10 | Output file follows naming: `output/skill-ranking/YYYYMMDD-skill-rank.md` | Test: verify file path and name format |

---

## 4. Constraints and Limits

### Performance
| Metric | Limit | Note |
|--------|-------|------|
| `/skill-rank` execution | <= 5s | Even with 10K log entries |
| Log append latency | <= 50ms | Must not slow down skill execution |
| Memory for scoring | <= 20MB | Parse JSONL streaming, not load all |

### Storage
| Resource | Limit | Plan |
|----------|-------|------|
| Active JSONL | <= 2MB | Rotate + gzip at threshold |
| Rotated files | <= 10 files | Delete oldest beyond 10 |
| Output files | 30 days | Pruned by standard output cleanup |

### Compatibility
| Element | Constraint |
|---------|-----------|
| Shell | Bash (Git Bash on Windows, native on Linux/macOS) |
| Dependencies | jq (already in workspace), gzip (standard) |
| Node/Python | NOT required -- pure bash + jq |

---

## 5. Test Scenarios

### Happy Path
```
Scenario: Record skill invocation and verify log entry
  Given data/skill-invocations.jsonl exists (empty or with prior entries)
  And skill "spec-driven-development" is activated via /skill-eval activate
  When the activation completes with outcome "success"
  Then a new line exists in data/skill-invocations.jsonl
  And the line contains {"skill":"spec-driven-development","outcome":"success"}
  And the timestamp is within 5 seconds of now (UTC)
```

```
Scenario: Compute effectiveness for skill with sufficient data
  Given data/skill-invocations.jsonl has these entries for "capacity-planning":
    | outcome | user_feedback | days_ago |
    | success | accepted      | 5        |
    | success | accepted      | 15       |
    | failure | rejected      | 25       |
    | success | neutral       | 45       |
    | success | accepted      | 60       |
  When /skill-rank is executed
  Then "capacity-planning" has effectiveness = (4/5*0.50 + 3/4*0.30 + 3/5*0.20) = 0.40+0.225+0.12 = 74.5%
  And status is "healthy"
```

```
Scenario: /skill-rank generates output file
  Given data/skill-invocations.jsonl has >= 10 entries across 5 skills
  When /skill-rank is executed
  Then file output/skill-ranking/20260327-skill-rank.md exists
  And console shows summary with top skills table
  And banner shows file path
```

### Error Cases
```
Scenario: No invocation data exists
  Given data/skill-invocations.jsonl does not exist or is empty
  When /skill-rank is executed
  Then output shows "No invocation data found. Skills will be tracked as they are used."
  And exit code is 0 (not an error)
```

```
Scenario: Skill with insufficient data
  Given "diagram-generation" has exactly 2 invocations in last 90 days
  When /skill-rank is executed
  Then "diagram-generation" appears under "Insufficient data" section
  And it does NOT appear in the ranked table
```

```
Scenario: Corrupt JSONL line
  Given data/skill-invocations.jsonl has a line that is not valid JSON
  When /skill-rank is executed
  Then the corrupt line is skipped with warning "Skipped 1 malformed entry"
  And all other entries are processed normally
```

### Edge Cases
```
Scenario: Log rotation at 2MB
  Given data/skill-invocations.jsonl is 2.01MB
  When a new invocation is logged
  Then the current file is moved to data/skill-invocations-20260327.jsonl.gz
  And a new data/skill-invocations.jsonl is created with only the new entry
  And the gzipped file is valid (gunzip test passes)
```

```
Scenario: All feedback is null (no user feedback ever given)
  Given 5 invocations for "azure-devops-queries" all with user_feedback: null
  When scoring is computed
  Then accept_rate is treated as 0.5 (neutral default)
  And effectiveness = (success_rate * 0.50) + (0.5 * 0.30) + (recency * 0.20)
```

```
Scenario: Stable skill regresses to weak
  Given "executive-reporting" has maturity: stable in SKILL.md frontmatter
  And effectiveness computed as 35% (weak)
  When /skill-rank is executed
  Then output includes alert: "REGRESSION: executive-reporting (stable) scored 35% (weak)"
```

```
Scenario: Exactly 90-day boundary
  Given an invocation with timestamp exactly 90 days ago (to the second)
  When scoring is computed
  Then that invocation IS included (boundary inclusive: >= now - 90d)
```

---

## 6. Ficheros a Crear / Modificar

### Crear (nuevos)

```
scripts/skill-feedback-log.sh          # Append invocation entry to JSONL log
scripts/skill-feedback-rank.sh         # Compute scores, generate ranking report
.opencode/commands/skill-rank.md         # /skill-rank command definition
data/.gitkeep                          # Ensure data/ directory exists
```

### Modificar (existentes)

```
.opencode/skills/eval-registry.json      # NOT modified -- remains for eval engine
.opencode/commands/skill-eval.md         # Add step: after activate, call skill-feedback-log.sh
.gitignore                             # Add: data/skill-invocations*.jsonl*
```

### NO tocar

```
.opencode/skills/skill-evaluation/SKILL.md   # Scoring engine stays separate
docs/rules/domain/skill-lifecycle.md    # Rules stay declarative
docs/rules/domain/skill-auto-activation.md  # Integration is via log data, not code change
```

---

## 7. Codigo de Referencia

### Pattern: JSONL logging (same pattern as confidence-log)

From `confidence-protocol.md`:
```bash
echo "{\"command\":\"...\",\"confidence\":$score,\"success\":true,\"timestamp\":\"$(date -Iseconds)\"}" \
  >> data/confidence-log.jsonl
```

### Pattern: scoring with jq

```bash
# Count outcomes
jq -s '[.[] | select(.skill=="'$SKILL'" and .outcome=="success")] | length' \
  data/skill-invocations.jsonl
```

### Pattern: command structure (from skill-eval.md)

The `/skill-rank` command follows the same structure as `/skill-eval`:
- Banner start
- Read data
- Compute
- Display table
- Save to file
- Banner end

---

## 8. Configuracion de Entorno

```bash
# Directories
DATA_DIR="data"
OUTPUT_DIR="output/skill-ranking"
LOG_FILE="$DATA_DIR/skill-invocations.jsonl"

# Dependencies (verify)
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

# Verification commands
bash scripts/skill-feedback-log.sh --test   # Self-test: writes test entry, verifies, removes
bash scripts/skill-feedback-rank.sh --test  # Self-test: uses fixture data, verifies scores
```

---

## 9. Estado de Implementacion

**Estado:** Pendiente

---

## 10. Checklist Pre-Entrega

### Implementacion
- [ ] `scripts/skill-feedback-log.sh` appends valid JSONL entries
- [ ] `scripts/skill-feedback-rank.sh` computes scores matching formula in 2.2
- [ ] `/skill-rank` command shows ranking table with correct format (2.4)
- [ ] Log rotation works at 2MB threshold
- [ ] `.gitignore` updated to exclude JSONL log files
- [ ] `skill-eval.md` updated to call log script after activation
- [ ] All 10 test scenarios pass
- [ ] Output file generated at correct path with correct naming

### Especifico para agente
- [ ] No decisions outside this spec were made
- [ ] No files outside section 6 were created or modified
- [ ] Scripts use `set -euo pipefail` and follow `scripts/` conventions
- [ ] Command follows UX feedback rules (banner, progress, result)
- [ ] Scripts are <= 150 lines each (file-size-limit rule)

---

## 11. Notas para el Revisor

1. **Integration with skill-auto-activation**: The `history_score` in
   `skill-auto-activation.md` (section "History scoring (30%)") currently
   has no data source. After this feature ships, the activation protocol
   should read from `data/skill-invocations.jsonl` to compute real
   `history_boost`. This is a FUTURE integration, not part of this spec.

2. **Relationship to eval-registry.json**: The existing registry is a
   simple JSON with an empty `entries` array. This spec does NOT replace
   it -- `eval-registry.json` tracks activation metadata for the eval
   engine, while `skill-invocations.jsonl` tracks outcomes for the
   feedback loop. They serve different purposes.

3. **Privacy**: The log contains skill names, commands, and project
   slugs. Project slugs are N2 (company level). The file is gitignored.
   No PII is stored.

---

## 12. Comandos de Verificacion

```bash
# 1. Build check (scripts are bash, no compilation needed)
bash -n scripts/skill-feedback-log.sh && echo "OK: log script syntax"
bash -n scripts/skill-feedback-rank.sh && echo "OK: rank script syntax"

# 2. Self-test for logging
bash scripts/skill-feedback-log.sh --test

# 3. Self-test for ranking
bash scripts/skill-feedback-rank.sh --test

# 4. Verify gitignore
grep -q "skill-invocations" .gitignore && echo "OK: gitignored"

# 5. Verify command exists
test -f .opencode/commands/skill-rank.md && echo "OK: command exists"

# 6. Full validation
bash tests/run-all.sh
```
