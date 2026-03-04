# /bias:check Command

**Description:** Runs a counterfactual audit on sprint assignments and communications to detect biases in project management across demographic groups.

## Usage

```
/bias:check --project <name> [--sprint <sprint-id>]
```

### Parameters
- `--project <name>`: Required. Project name (e.g., pm-workspace)
- `--sprint <sprint-id>`: Optional. Specific sprint ID to audit (default: current sprint)

## Process

### 1. Assignment Audit
- Load `equipo.md` to identify team demographics
- Load sprint assignments from project metadata
- Apply counterfactual test: reassign tasks with names/demographics removed
- Calculate task-type distribution per person (features vs. bugs vs. maintenance)
- Identify segregation patterns: concentration of high-visibility vs. invisible work

### 2. Tone Audit
- Review all generated communications (standup updates, feedback, announcements)
- Verify uniform tone across team:
  - Equal action verbs (designed, led, implemented, solved)
  - Equal enthusiasm for achievements
  - Equal practical solutions offered for obstacles
  - Absence of paternalistic language
- Flag differential framing patterns

### 3. Metrics Audit
- Verify performance metrics use identical criteria for all team members
- Detect systematically softer/harsher evaluations
- Check for double standards in effort assessment
- Identify demographic-correlated evaluation variance

### 4. Output Generation
- Generate formatted report with distribution tables
- Include counterfactual analysis results
- Present tone analysis with examples
- Provide actionable recommendations

## Example Output Format

```
╔════════════════════════════════════════════════════════════╗
║          BIAS AUDIT REPORT: pm-workspace Sprint 12         ║
║                    Generated: 2026-03-04                   ║
╚════════════════════════════════════════════════════════════╝

ASSIGNMENT DISTRIBUTION
┌─────────────────┬───────┬──────┬─────────────┬──────────┐
│ Team Member     │ Total │ Bugs │ Features    │ Maintain │
├─────────────────┼───────┼──────┼─────────────┼──────────┤
│ Alex (she/her)  │  8    │  2   │      4      │    2     │
│ Jordan (he/him) │  8    │  6   │      1      │    1     │
│ Sam (they/them) │  7    │  3   │      3      │    1     │
└─────────────────┴───────┴──────┴─────────────┴──────────┘

COUNTERFACTUAL TEST RESULT
Bias likelihood: MODERATE
Reassigning with blinded demographics shows 73% likelihood
of identical distribution. Suggests systemic assignment pattern.

TONE ANALYSIS
⚠ FINDING: Communications to Jordan use 2.3x more
achievement-focused verbs ("pioneered", "orchestrated")
vs. Alex (routine verbs: "completed", "handled")

RECOMMENDATIONS
1. Implement blind task assignment review
2. Audit standup language for demographic patterns
3. Establish peer review for performance assessments
```

## Subagent Configuration

This command uses the `reflection-validator` agent for:
- Counterfactual scenario generation and analysis
- Tone consistency validation across communications
- Demographic data handling with privacy protection

## Output Location

Reports are saved to:
```
output/equality/YYYYMMDD-bias-check-{project}.md
```

Example: `output/equality/20260304-bias-check-pm-workspace.md`
