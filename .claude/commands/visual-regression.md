---
name: visual-regression
description: Automated visual regression testing across builds and branches. Detect visual regressions with baseline comparison and approval workflows.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Visual Regression Command

Automated visual regression testing with baseline management and approval workflows.

## Subcommands

### baseline
Capture baseline screenshots for all registered views.
```bash
/visual-regression baseline [--tag=GIT_REF] [--views=VIEW_LIST]
```
- Captures screenshots for all views (or specified subset)
- Tags with git ref (branch/commit): `baseline-{tag}-{timestamp}`
- Stores in: `output/visual-qa/baselines/{tag}/`
- Creates index: `baseline-index.json` with view manifest
- Snapshot format: `{view_id}-{resolution}.png`

### test
Capture current screenshots and compare against baseline.
```bash
/visual-regression test [--baseline=TAG] [--tolerance=5] [--views=VIEW_LIST]
```
- Compares current captures against specified baseline
- Applies tolerance threshold (default: 5% pixel difference)
- Flags regressions: visual changes exceeding threshold
- Output: `output/visual-qa/reports/regression-test-{timestamp}.json`
- Severity levels: critical (>10%), major (5-10%), minor (<5%)
- Details: before/after screenshots, pixel diffs, affected components

### diff
Show detailed visual diff between two captures.
```bash
/visual-regression diff --current=CURRENT --baseline=BASELINE [--tolerance=0.1]
```
- Generates visual diff overlay
- Pixel-level threshold: 0.1 (0.1% pixel difference = critical)
- Outputs:
  - Diff visualization: `output/visual-qa/diffs/{comparison_id}-diff.png`
  - Diff metadata: `output/visual-qa/diffs/{comparison_id}.json`
- Highlights changed regions, calculates delta percentage

### approve
Mark visual changes as intentional (update baseline).
```bash
/visual-regression approve --test-run=TEST_ID [--reason=JUSTIFICATION]
```
- Approves regression findings as intentional design changes
- Updates baseline reference with current screenshots
- Logs approval decision with reason and reviewer
- Updates: `baseline-{tag}/metadata.json`
- Prevents same regression from flagging again

## Configuration

```yaml
tolerance_percent: 5          # Default regression threshold (%)
pixel_threshold: 0.1          # Pixel-level diff detection (%)
snapshot_resolutions:
  - 375   # Mobile
  - 768   # Tablet
  - 1440  # Desktop
ignore_regions:              # Optional dynamic content regions
  - selector: ".timestamp"
  - selector: ".user-avatar"
```

## Output Structure

```
output/visual-qa/
├── baselines/
│   └── {TAG}/
│       ├── {view_id}-375.png
│       ├── {view_id}-768.png
│       ├── {view_id}-1440.png
│       └── baseline-index.json
├── reports/
│   └── regression-test-*.json
└── diffs/
    ├── {comparison_id}-diff.png
    └── {comparison_id}.json
```

## Integration Points

- **CI Gates**: Works with `/security-pipeline` for automated testing
- **PR Guardian**: Blocks PRs with critical visual regressions until approved
- **Baseline Sync**: Auto-sync baselines to main branch after merge

## Examples

```bash
/visual-regression baseline --tag=v2.0.0 --views=homepage,dashboard,settings
/visual-regression test --baseline=v2.0.0 --tolerance=5
/visual-regression diff --current=output/visual-qa/screenshots/dashboard.png --baseline=output/visual-qa/baselines/v2.0.0/dashboard-1440.png
/visual-regression approve --test-run=regression-test-2026-03-06 --reason="Intentional design refresh"
```

## Regression Report Schema

```json
{
  "timestamp": "2026-03-06T10:30:00Z",
  "baseline_tag": "v2.0.0",
  "tolerance_percent": 5,
  "total_views": 3,
  "regressions": [
    {
      "view_id": "homepage",
      "severity": "major",
      "pixel_diff_percent": 7.2,
      "affected_regions": ["hero-section", "navigation"],
      "before": "baselines/v2.0.0/homepage-1440.png",
      "current": "screenshots/homepage-1440.png"
    }
  ]
}
```
