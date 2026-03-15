---
globs: ["**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.css", "**/*.scss"]
---
# Visual Quality Gates

## Trigger Conditions

### File Pattern Detection
Gate activates on PR modifications matching:
- `*.tsx`, `*.jsx` (React components)
- `*.vue` (Vue components)
- `*.svelte` (Svelte components)
- `*.html`, `*.htm` (templates)
- `*.css`, `*.scss`, `*.less` (styles)

### PBI Classifications
- UI-related PBIs with story points ≥5
- Visual design updates or refactors
- Accessibility improvements
- Cross-browser/viewport enhancements

## Gate Levels

### Informational (Score ≥80)
- Non-blocking status
- Shows warnings in PR comment
- Visual metrics included in digest
- Feedback for improvement
- Auto-passes if no critical defects

### Blocking Gate (Score <60)
- Prevents merge until resolved
- Requires PR Guardian review
- Actionable remediation required
- Re-run visual analysis post-fix
- Exemption requires security-team approval

### Auto-Pass (Score ≥90)
- Skips manual review
- Logged for audit trail
- Integrated into merge confidence score

## Required Pre-Merge Checks

1. **Wireframe Validation**: All registered design references validated
2. **Critical Defects**: Zero critical visual defects
3. **Accessibility**: Contrast checks passed (WCAG AA minimum)
4. **Responsive**: Validated at 3+ breakpoints (mobile/tablet/desktop)
5. **State Coverage**: Hover, focus, error, empty, loading states checked

## Integration Points

### PR Guardian
- Add `visual_score` to digest
- Include findings summary
- Link to annotated screenshots
- Merge confidence impact: weight 15%

### Compliance Gate
- Optional visual accessibility check
- Tied to security/privacy concerns
- Auto-trigger for auth/payment UI

### Security Pipeline
- Visual indicators for security UI components
- Highlight changes to credential input fields
- Flag modified warning/error messages
- Validate security state indicators (locked, unlocked)

## Privacy & Data Protection

### Screenshot Storage
- Never store screenshots with real user PII
- Use test/mock data exclusively
- Blur sensitive information before sharing
- Delete reports after 30 days

### Data Handling
- Exclude names, emails, phone numbers
- Mask payment card details
- Hide authentication tokens
- Use placeholder content

## Tolerance Thresholds

### Default Values
- Pixel difference: ±5% (configurable per project)
- Contrast ratio: WCAG AA ≥4.5:1 minimum
- Spacing variance: ±4px acceptable
- Color variance: ±5 RGB units

### Per-Project Configuration
Set in `CLAUDE.md`:
```yaml
visual-qa:
  pixel-tolerance: 0.05
  contrast-level: AA
  viewport-breakpoints:
    - 375
    - 768
    - 1920
```

## Exemptions & Overrides

### Valid Exemption Cases
- Third-party components (iframe, embed)
- Browser-native rendering variations
- Font loading timing (documented font-display)
- User customization features

### Override Process
- Requires explicit PR comment: `/visual-qa exempt [reason]`
- Documents exemption in compliance trail
- Auto-expires after 30 days
