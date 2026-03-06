# Testing Frontend Nueva Era — pm-workspace

## Resumen

pm-workspace incorpora un sistema completo de testing frontend que cubre tres capas: tests funcionales (unit + component + E2E), visual regression testing, y verificación automática de conformidad spec↔UI. Diseñado para la nueva era donde agentes IA generan código frontend y se necesita verificación automatizada rigurosa.

Compatible con React, Angular y cualquier framework detectado vía `package.json`.

## Componentes

### Agente: `frontend-test-runner`

Equivalente frontend del agente `test-runner` (.NET). Detecta automáticamente el stack de testing del proyecto (Vitest, Jest, Playwright, Cypress, ng test) y ejecuta el ciclo completo: unit → component → E2E → coverage. Si los tests fallan, delega al `frontend-developer` con un máximo de 2 ciclos antes de escalar a humano.

Integrado en el flujo SDD: se ejecuta automáticamente después de la implementación (Phase 2.6 TDD Gate).

### Comando: `/visual-regression`

Captura screenshots de la aplicación en 4 breakpoints (mobile 375px, tablet 768px, desktop 1280px, wide 1920px) y los compara contra baselines aprobadas usando Playwright + pixelmatch. Detecta regresiones visuales con un threshold de 0.1% de píxeles diferentes.

**Subcomandos:**

- `/visual-regression` — captura completa y comparación
- `/visual-regression --update-baseline` — actualiza baselines
- `/visual-regression --component {nombre}` — componente aislado (Storybook)
- `/visual-regression --page {/ruta}` — página específica

Stack 100% local y gratuito (Playwright + pixelmatch), sin vendor lock-in. Compatible con Applitools Eyes como opción de pago para comparación con IA y comparación Figma↔producción.

### Comando: `/spec-verify-ui`

Lee un spec SDD y verifica requisito por requisito contra el componente implementado: props, los 8 estados obligatorios (Default, Hover, Focus, Active, Disabled, Loading, Error, Success), atributos ARIA, navegación por teclado y design tokens. Calcula un porcentaje de conformidad y clasifica el resultado.

**Subcomandos:**

- `/spec-verify-ui {spec-path}` — verificar conformidad
- `/spec-verify-ui --generate-tests {spec-path}` — generar tests de verificación
- `/spec-verify-ui --fix {spec-path}` — auto-corregir divergencias
- `/spec-verify-ui --all` — verificar todos los componentes con spec

### Regla: `frontend-testing.md`

Define el stack recomendado, thresholds, estructura de ficheros, convenciones de naming y qué testear vs. qué no testear. Unifica criterios para que todos los equipos apliquen el mismo estándar de calidad frontend.

## Stack Tecnológico

| Necesidad | Herramienta | Justificación |
|---|---|---|
| E2E Testing | Playwright | Cross-browser, TypeScript nativo, codegen, estándar 2026 |
| Unit/Component | Vitest + testing-library | Rápido, compatible Vite/React/Angular |
| Visual Regression | Playwright + pixelmatch | Local, gratuito, sin vendor lock-in |
| Coverage | Istanbul/V8 (built-in) | Zero-config |

## Integración con pm-workspace

- **SDD (Spec-Driven Development)** — `/spec-verify-ui` cierra el ciclo: spec → implementar → verificar → aprobar
- **`/figma-extract`** — tokens extraídos alimentan la verificación de design tokens
- **`/a11y-audit`** — complementa spec-verify (ARIA) con WCAG completo
- **`/qa-dashboard`** — coverage, flaky tests y regresiones visuales en un solo panel
- **`/testplan-generate`** — genera test plans; spec-verify genera tests granulares por componente
- **`frontend-components.md`** — define los 8 estados y tokens que spec-verify verifica

## Conexión con la Nueva Era

El post de Beatriz Martín sobre Paper y Pencil SWARM describe la evolución del diseño hacia agentes autónomos. pm-workspace aborda el otro lado: la verificación automatizada. Cuando un agente IA genera un componente, Savia puede verificar que cumple el spec (funcional), coincide visualmente con la baseline (visual), y es accesible (ARIA + WCAG). Esto eleva el Augmentation Ratio del equipo frontend.

## Referencias

- Playwright — playwright.dev
- Vitest — vitest.dev
- Testing Library — testing-library.com
- pixelmatch — github.com/mapbox/pixelmatch
- Applitools Eyes (Figma plugin, enero 2026) — applitools.com
