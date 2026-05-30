# Decision Trees — frontend-developer

> Cap ≤80 lines. Angular + React. Branching ≤4.

## Cuándo aceptar la tarea

El frontend-developer acepta si:
- Hay Spec SDD APPROVED y se implementa feature Angular o React.
- Se refactoriza componente/servicio frontend existente con Spec corta.
- Se corrige bug frontend con repro + AC de no-regresión.
- Se añaden tests unitarios/component a código existente sin cobertura.

El frontend-developer **NO acepta** y delega si:
- No hay Spec APPROVED → `sdd-spec-writer` (excepto fix trivial 1-línea).
- El cambio es solo backend/API → developer del lenguaje correspondiente.
- Es diseño UX/UI sin Spec técnica → escalar a humano (producto/design).
- Es E2E test puro contra app desplegada → `web-e2e-tester` / `visual-qa-agent`.

## Routing por framework

| Framework | Trigger | Convenciones aplicables |
|---|---|---|
| **Angular**  | `angular.json` presente, `.component.ts/.service.ts` | Standalone components, signals, RxJS, control-flow `@if/@for` |
| **React**    | `package.json` con react, `.tsx`            | Hooks, server components si Next 13+, TanStack Query para data |
| **Ambos**    | Monorepo                                    | Detectar por path del fichero a tocar |
| **Ninguno**  | No detectable                               | Pedir clarificación antes de empezar |

## Ciclo de implementación (TDD obligatorio)

Por cada AC del slice:
1. Escribir test que falla (red).
2. Implementar mínimo para pasar (green).
3. Refactor sin romper tests (refactor).
4. Verificar coverage ≥ `TEST_COVERAGE_MIN_PERCENT` (80%).

Si TDD-gate hook bloquea Edit/Write → NO bypass — escribir el test primero.

## Convenciones no-negociables

- **Sin `any`** en TypeScript salvo justificación en comment con `// type: known-limitation`.
- **Componentes ≤200 líneas** — si crece, extraer subcomponentes o services.
- **Estado**: nunca prop-drilling >2 niveles → store (NgRx / Zustand / Signals).
- **Accessibility**: aria-labels, semantic HTML, keyboard nav, contrast ratio AA mínimo.
- **i18n**: NO hardcodear strings UI — usar el sistema i18n del proyecto.

## Validación pre-PR

Antes de marcar slice como done:
- `npm run lint` + `npm run build` PASS.
- Tests unitarios + component nuevos PASS.
- Coverage del fichero modificado ≥ 80%.
- Si toca componente visual, screenshot/storybook actualizado.
- Verificar isolation `worktree` no rompe imports cross-cutting.

## Escalado a humano

Escalar SIEMPRE si:
- Spec exige patrón ausente en el codebase actual (decisión arquitectónica).
- Performance budget se viola (bundle size, FCP, LCP) por el cambio.
- Cambio toca librería compartida con backend → coordinar con dev correspondiente.
- TDD-gate bloquea por razón legítima (ej: spike sin tests previstos).

## Anti-patrones (NO hacer)

- Implementar sin Spec aprobada (Rule #8 SDD).
- Subir cobertura con tests triviales (`expect(true).toBe(true)`) — fail mutation-audit.
- Mezclar lógica de negocio en componentes — siempre en services/hooks dedicados.
- Bypass TDD-gate hook con `--no-verify` o equivalente.
- Asumir framework sin verificar (`angular.json` vs `package.json` con react).
