---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.vue"
  - "**/frontend-*"
---

# Frontend Component Rules

## Naming & File Structure
- **Components**: PascalCase (`Button.tsx`, `ModalDialog.tsx`)
- **Files**: Match component name exactly
- **Aliases**: Document in component exports (`export { Button as PrimaryButton }`)

## Documentation Template
Every component must include:
```markdown
### ComponentName
**Aliases**: `Alias1`, `Alias2`
**Description**: One sentence describing purpose.
**Use When**: Specific use cases (e.g., "primary user actions")
**Avoid When**: Common mistakes (e.g., "multiple actions per button")
**Related**: `OtherComponent`, `ThirdComponent`
```

## Accessibility Checklist

| Component | ARIA Attributes | Keyboard |
|-----------|-----------------|----------|
| Accordion | `aria-expanded` | Enter/Space toggles, Tab navigates |
| Dialog | `aria-modal`, `aria-labelledby` | Escape closes, Tab trapped |
| Button | `aria-pressed` (if toggle) | Enter/Space activates |
| Dropdown | `aria-haspopup`, `aria-expanded` | Arrow keys navigate, Escape closes |
| Tab | `aria-selected`, `role="tab"` | Arrow keys switch, Enter activates |

**Global Requirements**:
- Focus visible on all interactive elements (outline or indicator)
- Color contrast ≥4.5:1 (normal text), ≥3:1 (large text)
- Never use color alone to convey meaning (add icons/labels)
- Focus trap in modals; restore focus on close

## State Requirements
Every interactive component must support:
1. **Default**: Base appearance
2. **Hover**: Visual feedback on pointer
3. **Focus**: Keyboard/programmatic focus indicator
4. **Active**: During interaction
5. **Disabled**: Non-interactive (50% opacity, no pointer)
6. **Loading**: Spinner or skeleton, disabled interaction
7. **Error**: Red border + error text, aria-invalid="true"
8. **Success**: Green indicator + confirmation message

## Component Spec Template
```markdown
# ComponentName

**File**: `ComponentName.tsx`
**Category**: Atom/Molecule/Organism
**Composition**: List parent components

## Props
| Prop | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| variant | string | false | default | Options: |
| disabled | boolean | false | false | |
| aria-label | string | false | — | Required if no visible text |

## States
- Default
- Hover
- Focus
- Disabled
- Loading
- Error

## ARIA
- Attributes:
- Roles:
- Focus management:
```

## Design Tokens

**Spacing**: 4px grid (4, 8, 12, 16, 24, 32, 48px)
**Typography**:
- Display: 32px/1.2 (bold)
- Heading: 24px/1.25 (semibold)
- Body: 16px/1.5 (regular)
- Small: 14px/1.4 (regular)
- Micro: 12px/1.3 (regular)

**Colors** (Semantic):
- `--color-primary`: Primary actions
- `--color-secondary`: Secondary actions
- `--color-success`: Positive feedback (≥4.5:1 contrast)
- `--color-error`: Validation errors (≥4.5:1 contrast)
- `--color-warning`: Cautions (≥4.5:1 contrast)
- `--color-neutral`: Borders, dividers

## Composition Hierarchy
```
Atom (Button, Input, Icon)
  ↓
Molecule (InputField, ButtonGroup, Card)
  ↓
Organism (Form, Modal, Navigation)
```
**Max Depth**: 3 levels. Flatten complex structures into reusable molecules.

## Composition Rules
1. One responsibility per component
2. Reuse atoms in molecules; reuse molecules in organisms
3. Props flow down; callbacks flow up
4. Document required child components
5. Provide sensible defaults for optional behavior
