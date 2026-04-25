# Opus 4.7 Calibration Playbook

> SE-070 Slice 3. How to decide whether to upgrade a single agent from
> `claude-sonnet-4-6` to `claude-opus-4-7` at effort `xhigh`, based on
> empirical A/B evidence rather than intuition.

## When to run this

- New agent added with unclear model choice.
- Quality complaints surface on an existing sonnet agent (e.g. analysis feels shallow).
- After a new model release (4.8, 5.0) to re-evaluate the cost/quality frontier.

NOT when:
- Agent is utility automation (formatter, digestor, logger) — haiku/sonnet is fine.
- Budget for evals is not available in current sprint.
- The agent has no golden-set and bootstrapping one costs more than upgrading everyone.

## Workflow (per agent)

### 1. Check scorecard

```bash
bash scripts/opus47-calibration-scorecard.sh
cat output/opus47-calibration-$(date +%Y%m%d).md
```

If the agent shows `recommend: eval` → proceed. If `defer` → bootstrap golden-set first (step 1a).

### 1a. Bootstrap golden-set (if missing)

```bash
cp -r tests/golden/opus47-calibration/TEMPLATE tests/golden/opus47-calibration/<agent-name>
mv tests/golden/opus47-calibration/<agent-name> tests/golden/opus47-calibration/<agent-name>/case-01
```

Populate `prompt.txt` + `expected.md` with one concrete case. Repeat for 3 cases total:
- case-01: happy path (normal input)
- case-02: edge case (unusual but valid input)
- case-03: failure mode (input that tests robustness)

### 2. Run A/B on each case

For case `case-XX` of agent `<agent-name>`:

```bash
PROMPT=$(cat tests/golden/opus47-calibration/<agent-name>/case-XX/prompt.txt)

# Run on sonnet-4-6
SONNET_OUT=$(echo "$PROMPT" | claude -p --model claude-sonnet-4-6 2>&1)
echo "$SONNET_OUT" > tests/golden/opus47-calibration/<agent-name>/case-XX/output-sonnet.md

# Run on opus-4-7 xhigh
OPUS_OUT=$(echo "$PROMPT" | claude -p --model claude-opus-4-7 --thinking-tier xhigh 2>&1)
echo "$OPUS_OUT" > tests/golden/opus47-calibration/<agent-name>/case-XX/output-opus.md
```

### 3. Blind-eval

Two options:

**Option A — Human eval** (preferred for first 3 agents):
- Do NOT record which model produced which output.
- Score each output on 5 dimensions (0-10 each, from `README.md` rubric).
- Record scores + token counts in `score.yaml`.

**Option B — LLM-as-judge** (for scale):
- Invoke a third model (haiku works) with rubric + both outputs (anonymized).
- Parse returned scores into `score.yaml`.
- Bias check: rotate judge model every ~10 cases to detect systematic drift.

### 4. Compute derived metrics

```python
quality_delta_pct = (opus_total - sonnet_total) / sonnet_total * 100
cost_delta_pct = (opus_cost - sonnet_cost) / sonnet_cost * 100
quality_cost_ratio = quality_delta_pct / cost_delta_pct
```

### 5. Decision matrix

| quality_cost_ratio | Recommendation |
|---|---|
| `>= 2.0` | **Upgrade to opus-4-7 xhigh**. Quality gain justifies cost. |
| `1.0 – 2.0` | **Keep sonnet-4-6**. Upgrade marginal, not worth disruption. |
| `< 1.0` | **Keep sonnet-4-6**. Opus quality LOWER than cost increase. |
| `quality_delta < 0` | **Keep sonnet-4-6 OR downgrade to haiku-4-5**. Opus underperforms. |
| Single-case outlier | Rerun with 3+ cases to confirm signal. |

### 6. Record decision

Update `score.yaml`:

```yaml
recommendation: upgrade | keep_sonnet | downgrade_haiku | rerun
reasoning: "2-3 sentence explanation citing the scores."
```

If `upgrade`: PR to change `model:` in `.claude/agents/<agent-name>.md` frontmatter + `effort: xhigh`.

## Cost guidance

Approximate per A/B pair (2025-Q2 rates, subject to change):

| Model | In | Out | Cost per typical 2k in / 1k out |
|---|---|---|---|
| sonnet-4-6 | $3/MTok | $15/MTok | ~$0.021 |
| opus-4-7 (default) | $15/MTok | $75/MTok | ~$0.105 |
| opus-4-7 xhigh | $15/MTok | $75/MTok × 2.5 extended thinking | ~$0.218 |

3 cases × 1 agent ≈ $0.72 (all three models)
3 cases × 3 agents (Slice 4) ≈ $2.20 total
Whole 37-agent suite × 3 cases ≈ $27 (if all get evaluated)

Conservative batch budget allocation: **$30/quarter** for opus calibration evals.

## Anti-patterns

1. **Evaluating without blind** — knowing which output is which biases scoring. Anonymize file names.
2. **Single case decisions** — 1 case is noise. 3 is minimum, 5 is confident.
3. **Upgrading all agents in parallel** — if cost delta is high, impact compounds. One at a time with 1-week observation before next.
4. **Skipping failure-mode case** — happy path alone hides robustness differences.
5. **LLM-as-judge without rotation** — systematic judge bias silently inflates one model.

## Rollback

If an upgrade turns out worse in production (unexpected regressions):

```bash
git log --oneline --all | grep -E "opus.*(agent-name|model:)" | head -5
# Find the upgrade commit, revert
git revert <sha>
```

Record in `decision-log.md` with observed regression + revert rationale.

## Re-eval cadence

- Per model release: re-run scorecard. If a cheaper model ships (e.g. opus-5.0), evaluate downgrade.
- Every 6 months: spot-check 2-3 upgraded agents for quality drift.

## References

- Scorecard: `scripts/opus47-calibration-scorecard.sh`
- Golden-set structure: `tests/golden/opus47-calibration/README.md`
- Spec: `docs/propuestas/SE-070-opus47-eval-scorecard.md`
- Related: `.claude/skills/model-upgrade-audit/SKILL.md` (prompt-debt detection, different purpose)
- Related: SE-066..SE-069 (Opus 4.7 immediate adaptations)
