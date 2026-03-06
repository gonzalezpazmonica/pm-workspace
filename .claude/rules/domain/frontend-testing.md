# Frontend Testing — Convenciones y Configuración

> Define el stack de testing, convenciones y thresholds para proyectos frontend.
> Complementa `coverage-scripts.md` (backend) con el equivalente frontend.

---

## Stack Recomendado

| Capa | Herramienta | Alternativa |
|---|---|---|
| Unit/Component | Vitest + testing-library | Jest + testing-library |
| E2E | Playwright | Cypress |
| Visual Regression | Playwright + pixelmatch | Applitools (de pago) |
| Coverage | Istanbul/V8 (built-in Vitest) | Istanbul (Jest) |
| Component Docs | Storybook 8+ | Ladle |

---

## Detección de Stack

El agente `frontend-test-runner` detecta automáticamente:

```
package.json → scripts + devDependencies
  vitest         → Vitest runner
  jest           → Jest runner
  @playwright    → Playwright E2E
  cypress        → Cypress E2E
  angular.json   → ng test
  storybook      → Interaction tests
```

---

## Thresholds

| Métrica | Mínimo | Ideal |
|---|---|---|
| Coverage unit/component | 80% | 90%+ |
| Coverage E2E (páginas) | 100% rutas principales | 100% + flujos críticos |
| Visual regression diff | < 0.1% píxeles | 0% |
| Flaky tests | < 5% del total | 0% |

---

## Breakpoints para Visual Regression

```
mobile:  375 × 812   (iPhone SE)
tablet:  768 × 1024  (iPad)
desktop: 1280 × 800  (Standard)
wide:    1920 × 1080 (Full HD)
```

Siempre capturar los 4 salvo `--breakpoint` explícito.

---

## Estructura de Ficheros

```
proyecto/
├── __tests__/              ← Unit + component tests
│   ├── components/
│   └── hooks/
├── e2e/                    ← Playwright E2E tests
│   ├── pages/
│   └── playwright.config.ts
├── screenshots/
│   ├── baseline/           ← Baselines aprobadas (comitear)
│   ├── current/            ← Capturas actuales (gitignore)
│   └── diff/               ← Diferencias (gitignore)
└── .gitignore              ← screenshots/current + screenshots/diff
```

---

## Convenciones de Testing

### Naming

- Unit: `{Component}.test.tsx` o `{hook}.test.ts`
- E2E: `{page}.e2e.ts` o `{flow}.e2e.ts`
- Spec verify: `{Component}.spec-verify.test.tsx`
- Visual: `{page}-{breakpoint}.png`

### Qué testear

- **Unit**: lógica de hooks, utils, formatters, validators
- **Component**: render, interacción, estados, ARIA
- **E2E**: flujos de usuario completos (login, checkout, CRUD)
- **Visual**: cada página × 4 breakpoints

### Qué NO testear

- Detalles de implementación (nombres de clases internas)
- Snapshot tests masivos (frágiles, poco valor)
- Estilos inline (testing-library no los verifica bien)

---

## Integración

| Comando/Agente | Relación |
|---|---|
| `frontend-test-runner` | Ejecuta este protocolo completo |
| `/visual-regression` | Captura y compara screenshots |
| `/spec-verify-ui` | Verifica spec SDD contra componente |
| `/qa-dashboard` | Métricas de coverage y flaky |
| `/testplan-generate` | Genera plan de tests por spec |
| SDD Phase 2.6 | TDD Gate: tests antes de implementación |
| `frontend-components.md` | 8 estados obligatorios a testear |

---

## Referencias

- Playwright docs — playwright.dev
- Vitest docs — vitest.dev
- Testing Library — testing-library.com
- pixelmatch — github.com/mapbox/pixelmatch
- Storybook — storybook.js.org
