---
name: visual-qa
description: Visual quality assurance via screenshot analysis. Analyze UI screenshots against design specs and reference images using vision capabilities.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Visual QA Command

Analyze UI screenshots against design specifications using vision-based QA.

## Subcommands

### capture
Capture screenshot of current UI state.
```bash
/visual-qa capture [--name=SCREENSHOT_ID] [--path=COMPONENT_PATH]
```
- Saves to: `output/visual-qa/screenshots/{SCREENSHOT_ID}.png`
- Default name: `screenshot-{timestamp}`
- Stores metadata: capture time, component path, git ref

### compare
Compare current screenshot against reference image (wireframe, mockup, or previous).
```bash
/visual-qa compare --reference=REF_FILE [--current=CURRENT_SCREENSHOT]
```
- Analyzes differences in:
  - **Layout** (30%): component positioning, alignment, spacing consistency
  - **Colors** (20%): hex accuracy, contrast ratios, palette compliance
  - **Typography** (15%): font families, sizes, weights, line heights
  - **Spacing** (20%): padding, margins, gutters, vertical rhythm
  - **Content** (15%): text presence, image rendering, element visibility
- Output: `output/visual-qa/diffs/{comparison_id}.json`
- Visual match score: 0-100 (aggregated weighted scores)

### regression
Detect visual regressions across git refs.
```bash
/visual-qa regression --ref1=GIT_REF1 --ref2=GIT_REF2 [--view=VIEW_ID]
```
- Captures screenshots at both refs
- Compares using visual diff with default 5% tolerance
- Flags regressions above threshold
- Output: `output/visual-qa/reports/regression-{ref1}-{ref2}.md`

### report
Generate comprehensive visual QA report.
```bash
/visual-qa report [--format=json|md] [--include-screenshots]
```
- Aggregates all findings from session
- Lists issues with severity: critical|major|minor|cosmetic
- Includes: visual match scores, component analysis, recommendations
- Output: `output/visual-qa/reports/qa-report-{timestamp}.{format}`

## Output Structure

```
output/visual-qa/
├── screenshots/       # Captured UI screenshots
├── references/        # Reference images (wireframes, mockups)
├── diffs/            # Comparison analysis results
└── reports/          # QA reports and findings
```

## Scoring Formula

**Visual Match Score** (0-100):
```
score = (layout×0.30) + (colors×0.20) + (typography×0.15) + (spacing×0.20) + (content×0.15)
```

Each component scored on pixel-perfect accuracy percentage.

## Examples

```bash
/visual-qa capture --name=homepage-hero
/visual-qa compare --reference=output/visual-qa/references/homepage-mockup.png --current=output/visual-qa/screenshots/homepage-hero.png
/visual-qa regression --ref1=main --ref2=feature/redesign --view=homepage
/visual-qa report --format=md --include-screenshots
```
