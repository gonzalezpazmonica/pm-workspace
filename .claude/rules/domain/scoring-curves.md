---
globs: [".claude/commands/code-audit*", ".claude/commands/sprint-review*"]
---
# Scoring Curves — Piecewise Linear Normalization

## Purpose

Replace binary pass/fail scoring with calibrated piecewise linear curves
that degrade smoothly. Inspired by kimun's normalization model and
industry thresholds (SonarQube, Microsoft Code Metrics).

## How It Works

Each dimension maps a raw metric to a 0-100 score using breakpoints.
Between breakpoints, values interpolate linearly. No cliff edges.

```
Score formula:
  score = low_score + (high_score - low_score) × (value - low) / (high - low)
```

## Dimension Curves

### PR Size (lines changed)

```
Lines    Score   Label
≤ 50     100     XS — ideal
100       85     S — good
250       65     M — review carefully
500       35     L — consider splitting
1000      10     XL — split required
≥ 2000     0     XXL — reject
```

### Context Usage (% of 200K window)

Zones calibrated per TurboQuant (arXiv:2504.19874) — degradation starts ~70%, not 50%.

```
Usage%   Score   Zone       Action
≤ 30     100     Verde      Healthy — full capacity
50        80     Verde      Normal — monitor
70        50     Gradual    Warning — /compact recommended (Zona Gradual)
85        25     Alerta     Critical — /compact required (Zona Alerta)
95         5     Crítica    Emergency — subagent isolation mandatory (Zona Crítica)
≥ 100      0     Crítica    Exhausted — session restart
```

### File Size (lines)

```
Lines    Score   Note
≤ 80     100     Optimal for context loading
120       80     Within limits
150       50     At hard cap — split soon
200       20     Over limit — must split
≥ 300      0     Violates architecture
```

### Sprint Velocity Deviation (% from average)

```
Deviation%   Score   Interpretation
≤ 10         100     Stable velocity
20            75     Normal variance
35            50     Investigate causes
50            25     Team may be overloaded or blocked
≥ 80           0     Sprint planning failure
```

### Test Coverage (%)

```
Coverage%   Score   Threshold
≥ 90        100     Excellent
80           80     Target (TEST_COVERAGE_MIN_PERCENT)
65           50     Acceptable for legacy
50           25     Risk zone
≤ 30          0     Unacceptable
```

### Confidence Calibration (Brier score)

```
Brier    Score   Interpretation
≤ 0.05   100     Near-perfect calibration
0.10      80     Well calibrated
0.15      60     Adjustment recommended
0.20      35     Recalibration required
0.30      10     System unreliable
≥ 0.50     0     Broken — disable NL resolution
```

### Per-Finding Confidence (judge output)

```
Confidence   Score   Action
≥ 0.90       100     High confidence — auto-applicable finding
0.75          80     Good — include in consensus score
0.50          50     Moderate — flag for human review
0.30          20     Low — exclude from aggregate, show as advisory
≤ 0.15        0     Noise — suppress from report
```

Each consensus judge emits per-finding confidence (0.0–1.0). Findings below 0.50 are excluded from the weighted consensus score and flagged as "needs human review". Findings above 0.90 can auto-apply fixes when verdict is APPROVED.

## Usage

Commands that produce scores SHOULD use these curves:
- `/code-audit` → file size, coverage, complexity
- `/sprint-review` → velocity deviation
- `/context-budget` → context usage
- `/confidence-calibrate` → Brier score
- PR Guardian Gate 7 → PR size, context impact
- `consensus-validation` → per-finding confidence filtering

## Extending

To add a new dimension:
1. Define 5-6 breakpoints based on published thresholds
2. Include source (SonarQube, research paper, team consensus)
3. Test with `scripts/test-scoring-curves.sh`

## References

- SonarSource (2017). "Cognitive Complexity — A new way of measuring understandability"
- Microsoft. "Code Metrics Values" — docs.microsoft.com
- kimun (lnds/kimun). Piecewise linear normalization for code quality
- TurboQuant (arXiv:2504.19874). Context window quality degradation — gradual, not cliff
