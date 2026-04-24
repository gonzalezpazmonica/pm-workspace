# Opus 4.7 Calibration — Golden Set

> SE-070 Slice 2. Structure for A/B eval of `claude-sonnet-4-6` vs `claude-opus-4-7` xhigh per agent.

## Directory structure

```
tests/golden/opus47-calibration/
├── README.md                    # This file
├── TEMPLATE/                    # Copy this for a new agent
│   ├── prompt.txt               # The input prompt (same for both models)
│   ├── expected.md              # Expected output / acceptance criteria
│   └── score.yaml               # Scoring rubric + eval results
└── <agent-name>/                # One dir per agent under eval
    ├── case-01/
    │   ├── prompt.txt
    │   ├── expected.md
    │   └── score.yaml
    ├── case-02/
    │   └── ...
    └── ...
```

## Eval workflow

1. **Pick an agent** on `claude-sonnet-4-6` with clear quality signal (scorecard recommends `eval`).
2. **Create 3 cases**: happy path + edge case + failure-mode case.
3. **Run A/B**: invoke agent twice (once on each model). Capture output.
4. **Score**: use LLM-as-judge on rubric OR human blind-eval.
5. **Record**: populate `score.yaml` with scores + token counts + timestamp.
6. **Decide**: if avg opus quality gain >= 2x cost delta → recommend upgrade. Else keep.

## Score rubric

Each case scored on 5 dimensions (0-10 per dimension, 50 max):

| Dimension | Criterion |
|---|---|
| Correctness | Technically accurate per expected output |
| Depth | Covers nuance, edge cases, implications |
| Conciseness | No filler, no redundancy |
| Actionability | Output directly usable by human or downstream agent |
| Formatting | Follows expected structure (code blocks, tables, etc.) |

## Candidate agents for eval (Slice 4)

Per scorecard recommendation, prioritize:
1. `business-analyst` — strategic analysis, high value of depth
2. `drift-auditor` — pattern detection, benefits from extended thinking
3. `tech-writer` — long-form output quality matters

## Cost budget

Per SE-070 risk matrix: run evals only when batch budget allows. Typical cost per A/B pair: ~$0.50 sonnet + ~$3 opus xhigh = ~$3.50 per case. 3 cases × 3 agents = ~$31.50 total for Slice 4.

## References

- Scorecard: `scripts/opus47-calibration-scorecard.sh`
- Playbook: `docs/rules/domain/opus47-calibration-playbook.md`
- Spec: `docs/propuestas/SE-070-opus47-eval-scorecard.md`
