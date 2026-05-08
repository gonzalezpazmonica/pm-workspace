---
name: wireframe-check
description: Validate implementation against wireframe/mockup designs. Register reference designs and verify implementation fidelity against specifications.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Wireframe Check Command

Validate UI implementation fidelity against wireframe and mockup designs.

## Subcommands

### register
Register a wireframe/mockup as reference for a feature.
```bash
/wireframe-check register --feature=FEATURE_ID --file=PATH_TO_IMAGE [--source=SOURCE]
```
- Stores reference in: `output/visual-qa/references/{FEATURE_ID}/`
- Captures metadata:
  - Feature ID (kebab-case identifier)
  - Registration date (ISO 8601)
  - Source (design-system, figma-link, mockup-tool)
  - Component list
- Creates manifest: `output/visual-qa/references/{FEATURE_ID}/manifest.json`

### validate
Compare implementation screenshot against registered wireframe.
```bash
/wireframe-check validate --feature=FEATURE_ID [--screenshot=PATH]
```
- Analyzes:
  - **Component Presence**: All wireframe components present in implementation
  - **Layout Fidelity**: Grid alignment, positioning accuracy, visual hierarchy
  - **Responsive Behavior**: Breakpoint behavior, reflow correctness
  - **Accessibility Indicators**: ARIA landmarks, focus states, contrast
- Output: `output/visual-qa/reports/wireframe-validation-{FEATURE_ID}.json`
- Generates visual overlay showing deviations

### gaps
List all registered wireframes lacking implementation validation.
```bash
/wireframe-check gaps [--status=unvalidated|partial|complete]
```
- Shows feature ID, registration date, last validation date
- Sorted by priority or date
- Output: Table to stdout + JSON to `output/visual-qa/reports/validation-gaps.json`

### spec
Extract UI specifications from wireframe image.
```bash
/wireframe-check spec --file=WIREFRAME_IMAGE [--output=json|css]
```
- Extracts structured specifications:
  - **Colors**: Hex codes, color names, usage contexts
  - **Fonts**: Family, sizes, weights, line-heights, letter-spacing
  - **Spacing**: Padding, margins, gaps, gutters (in px/rem)
  - **Components**: Identified UI components with dimensions
- Output: `output/visual-qa/reports/spec-{feature_id}.{format}`
- Supports JSON and CSS variable output

## Output Structure

```
output/visual-qa/
├── references/
│   └── {FEATURE_ID}/
│       ├── wireframe.png
│       └── manifest.json
└── reports/
    ├── wireframe-validation-*.json
    ├── validation-gaps.json
    └── spec-*.{json,css}
```

## Manifest Schema

```json
{
  "feature_id": "feature-name",
  "registered_at": "2026-03-06T10:30:00Z",
  "source": "figma-link|mockup-tool",
  "components": ["Button", "Card", "Header"],
  "last_validated": "2026-03-06T11:00:00Z",
  "validation_status": "complete|partial|unvalidated"
}
```

## Examples

```bash
/wireframe-check register --feature=user-dashboard --file=designs/dashboard-mockup.png --source=figma-link
/wireframe-check validate --feature=user-dashboard --screenshot=output/visual-qa/screenshots/dashboard.png
/wireframe-check gaps --status=unvalidated
/wireframe-check spec --file=designs/dashboard-mockup.png --output=json
```
