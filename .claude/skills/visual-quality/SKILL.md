# Visual Quality Analysis Skill

## Vision Analysis Checklist

### Layout Analysis
- Grid alignment (8px/4px snap tolerance)
- Flex/grid property consistency
- Element positioning (absolute/relative)
- Container boundaries and overflow
- Z-index layering correctness

### Color Palette Extraction
- Primary/secondary/accent colors match design tokens
- Gradient definitions (direction, stops)
- Background/foreground contrast ratios (WCAG AA ≥4.5:1, AAA ≥7:1)
- Semantic color usage (success=green, error=red)

### Typography Validation
- Font family fallback chain
- Weight consistency (100, 400, 600, 700)
- Size hierarchy maintenance
- Line height and letter spacing
- Text baseline alignment

### Spacing & Sizing
- Padding/margin consistency (8px multiples)
- Gap between elements
- Responsive breakpoint scaling
- Component sizing against specs

### Accessibility Checks
- Contrast ratio validation (WCAG AA minimum)
- Touch target size (44px minimum)
- Text size (12px minimum readable)
- Focus indicator visibility
- Alt text presence for images

## Comparison Methodology

### Pixel-Level vs Semantic
- Pixel-level: exact positional matching (tolerance ±5px default)
- Semantic: layout intent preservation (grid flow, flex wrap behavior)

### Weighted Scoring Formula
```
visual_match = (layout×0.30) + (colors×0.20) + (typography×0.15) + (spacing×0.20) + (content×0.15)
```

## Common Visual Defects Taxonomy

### Alignment Issues
- Grid breaks (elements off-snap)
- Misaligned text baselines
- Inconsistent vertical/horizontal spacing

### Overflow & Truncation
- Text truncation without ellipsis
- Elements bleeding outside containers
- Missing responsive behaviors

### Contrast Failures
- Text on background (WCAG AA/AAA)
- Icon contrast insufficiency
- Focus state visibility

### Missing Interactive States
- Hover state styling
- Focus ring indicators
- Error/warning states
- Empty/loading states
- Disabled state appearance

### Responsive Breakpoint Failures
- Layout breaks at 768px, 1024px, 1280px
- Image scaling issues
- Typography size jumps

## Reference Formats

### Figma Export
- 2x PNG export (highest fidelity)
- Artboard dimensions noted
- Layer nesting preserved

### Wireframe
- Grayscale layout reference
- Content block dimensions
- Interaction indicators

### Mockup
- Full visual fidelity
- All design tokens applied
- Complete state coverage

### Previous Build (Baseline)
- Production screenshot
- Known good state
- Regression detection

## Screenshot Best Practices

### Viewport Consistency
- Desktop: 1920x1080
- Tablet: 768x1024
- Mobile: 375x812
- Hide browser UI/toolbars

### State Preparation
- No loading spinners/skeletons
- Static content only
- Hide dynamic timestamps
- Use consistent test data

### Content Masking
- Blur real user data (names, emails)
- Use placeholder avatars
- Replace PII with "Lorem ipsum"
- Hide real API responses

## Report Template Structure

```
# Visual QA Report

## Summary
- visual_match: 85/100
- Status: PASS (≥80) | REVIEW (60-79) | FAIL (<60)

## Key Metrics
- Layout: 90 | Colors: 80 | Typography: 85 | Spacing: 82 | Content: 88

## Findings by Severity
### Critical (blocks functionality)
[annotated screenshots]

### Major (UX impact)
[annotated screenshots]

### Minor (quality)
[list]

## Accessibility Status
- Contrast: PASS/FAIL
- Touch targets: PASS/FAIL
- Text size: PASS/FAIL

## Recommendations
[actionable fixes by priority]
```
