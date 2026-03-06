# Frontend Testing New Era — pm-workspace

## Overview

pm-workspace incorporates a complete frontend testing system covering three layers: functional tests (unit + component + E2E), visual regression testing, and automated spec↔UI conformity verification. Designed for the new era where AI agents generate frontend code and rigorous automated verification is needed.

Compatible with React, Angular, and any framework detected via `package.json`.

## Components

### Agent: `frontend-test-runner`

Frontend equivalent of the `test-runner` agent (.NET). Automatically detects the project's testing stack (Vitest, Jest, Playwright, Cypress, ng test) and runs the full cycle: unit → component → E2E → coverage. If tests fail, delegates to `frontend-developer` with a maximum of 2 cycles before escalating to human.

Integrated into the SDD flow: runs automatically after implementation (Phase 2.6 TDD Gate).

### Command: `/visual-regression`

Captures application screenshots at 4 breakpoints (mobile 375px, tablet 768px, desktop 1280px, wide 1920px) and compares them against approved baselines using Playwright + pixelmatch. Detects visual regressions with a 0.1% pixel difference threshold.

**Subcommands:**

- `/visual-regression` — full capture and comparison
- `/visual-regression --update-baseline` — update baselines
- `/visual-regression --component {name}` — isolated component (Storybook)
- `/visual-regression --page {/path}` — specific page

100% local and free stack (Playwright + pixelmatch), no vendor lock-in. Compatible with Applitools Eyes as paid option for AI comparison and Figma↔production comparison.

### Command: `/spec-verify-ui`

Reads an SDD spec and verifies requirement by requirement against the implemented component: props, the 8 mandatory states (Default, Hover, Focus, Active, Disabled, Loading, Error, Success), ARIA attributes, keyboard navigation, and design tokens. Computes a conformity percentage and classifies the result.

**Subcommands:**

- `/spec-verify-ui {spec-path}` — verify conformity
- `/spec-verify-ui --generate-tests {spec-path}` — generate verification tests
- `/spec-verify-ui --fix {spec-path}` — auto-fix divergences
- `/spec-verify-ui --all` — verify all components with specs

### Rule: `frontend-testing.md`

Defines recommended stack, thresholds, file structure, naming conventions, and what to test vs. what not to test. Unifies criteria so all teams apply the same frontend quality standard.

## Technology Stack

| Need | Tool | Rationale |
|---|---|---|
| E2E Testing | Playwright | Cross-browser, native TypeScript, codegen, 2026 standard |
| Unit/Component | Vitest + testing-library | Fast, Vite/React/Angular compatible |
| Visual Regression | Playwright + pixelmatch | Local, free, no vendor lock-in |
| Coverage | Istanbul/V8 (built-in) | Zero-config |

## Integration with pm-workspace

- **SDD (Spec-Driven Development)** — `/spec-verify-ui` closes the loop: spec → implement → verify → approve
- **`/figma-extract`** — extracted tokens feed design token verification
- **`/a11y-audit`** — complements spec-verify (ARIA) with full WCAG coverage
- **`/qa-dashboard`** — coverage, flaky tests, and visual regressions in one panel
- **`/testplan-generate`** — generates test plans; spec-verify generates granular per-component tests
- **`frontend-components.md`** — defines the 8 states and tokens that spec-verify checks

## Connection to the New Era

AI design tools like Paper and Pencil SWARM are evolving design toward autonomous agents. pm-workspace addresses the other side: automated verification. When an AI agent generates a component, Savia can verify it meets the spec (functional), matches the visual baseline (visual), and is accessible (ARIA + WCAG). This raises the team's frontend Augmentation Ratio.

## References

- Playwright — playwright.dev
- Vitest — vitest.dev
- Testing Library — testing-library.com
- pixelmatch — github.com/mapbox/pixelmatch
- Applitools Eyes (Figma plugin, January 2026) — applitools.com
