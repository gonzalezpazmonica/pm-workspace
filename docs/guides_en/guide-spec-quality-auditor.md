# Spec Quality Auditor

> Version: v4.8 | Era: 177 | Since: 2026-04-03

## What it is

A deterministic evaluator that scores SDD specifications on a 0-100 scale using 9 objective criteria. It can evaluate individual specs or full batches, filtering by minimum score. Output is available in text or JSON format.

## Requirements

Pre-installed since v4.8. No external dependencies.

## Basic usage

```bash
# Evaluate a single spec
bash scripts/spec-quality-auditor.sh docs/propuestas/SPEC-078.md

# Evaluate all specs in a directory
bash scripts/spec-quality-auditor.sh --batch docs/propuestas/

# Filter by minimum score
bash scripts/spec-quality-auditor.sh --batch docs/propuestas/ --min-score 80

# JSON output
bash scripts/spec-quality-auditor.sh docs/propuestas/SPEC-078.md --json
```

The output shows the overall score followed by a per-criterion breakdown (each criterion scored against its maximum weight). See the Spanish guide for a sample output.

## The 9 criteria

| Criterion | Weight | Evaluates |
|-----------|--------|-----------|
| header | 10 | Title, SPEC number, correct format |
| metadata | 10 | Status, author, date, version |
| problem | 10 | Problem defined with clarity |
| solution | 10 | Solution described and viable |
| acceptance | 10 | Measurable acceptance criteria |
| effort | 10 | Effort estimation present |
| dependencies | 10 | Dependencies identified |
| testability | 10 | Test cases or strategy |
| clarity | 15 | Overall readability, no ambiguities |

Certification: specs with 80+ are considered "ready for implementation".

## Batch mode

Batch mode scans all `SPEC-*.md` files in a directory and generates a summary with statistics including count of certified specs, mean, median, minimum, and maximum scores.

## Integration

- **SDD pipeline**: evaluate specs before assigning them to implementation agents
- **SPEC triage**: use `--min-score 80` to identify specs ready to promote to Ready
- **CI**: `bash scripts/spec-quality-auditor.sh --batch --min-score 70 --json` returns exit code 1 if any spec does not meet the threshold

## Troubleshooting

**Low score on "acceptance"**: add acceptance criteria in Given/When/Then format with concrete data

**Low score on "metadata"**: verify that the spec has frontmatter with status, author, and date

**Batch finds no specs**: ensure files follow the `SPEC-*.md` naming pattern
