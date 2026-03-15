# Regla: Capturas de Pantalla Obligatorias en Tests E2E Web

> Aplica a TODOS los proyectos con tests E2E de páginas web (Playwright, Cypress, etc.).

## Principio

Todo test E2E de una página web DEBE incluir al menos una captura de pantalla
que confirme visualmente que los componentes renderizan correctamente.
Las aserciones de DOM son necesarias pero insuficientes: un elemento puede
existir en el DOM y estar roto visualmente (CSS, layout, overflow, z-index).

## Regla obligatoria

1. **Cada test E2E** que navega a una página o renderiza un componente significativo
   DEBE llamar a `page.screenshot()` (Playwright) o `cy.screenshot()` (Cypress)
   al menos una vez tras las aserciones principales.

2. La captura se guarda en `output/e2e-results/{proyecto}/` con nombre descriptivo:
   `{spec-name}--{test-name}.png` (kebab-case, sin espacios).
   La subcarpeta `{proyecto}` coincide con el nombre del proyecto (ej: `savia-web`, `trazabios`).

3. El screenshot se toma en el estado final del test (después de las aserciones),
   no antes. Esto garantiza que la captura refleja el estado validado.

## Cuándo aplica

- Tests que verifican renderizado de páginas completas
- Tests que verifican componentes visuales (formularios, tablas, modales, charts)
- Tests de UI quality, accesibilidad visual, temas (dark/light)
- Tests de responsive o layout

## Cuándo NO aplica

- Tests puramente de API/network (sin UI visible)
- Tests de lógica de navegación que solo verifican URLs
- Tests de localStorage/cookies sin componente visual

## Patrón recomendado (Playwright)

```typescript
test('dashboard renders stats cards', async ({ page }) => {
  await page.goto('/')
  await expect(page.locator('.stats-row')).toBeVisible()
  // ... aserciones de DOM ...

  // OBLIGATORIO: captura visual de confirmación
  await page.screenshot({
    path: 'output/e2e-results/savia-web/dashboard--stats-cards.png',
    fullPage: true,
  })
})
```

## Patrón recomendado (Cypress)

```typescript
it('dashboard renders stats cards', () => {
  cy.visit('/')
  cy.get('.stats-row').should('be.visible')
  // ... aserciones de DOM ...

  // OBLIGATORIO: captura visual de confirmación
  cy.screenshot('mi-proyecto/dashboard--stats-cards', { capture: 'fullPage' })
})
```

## Verificación

En code review de tests E2E, rechazar tests que:
- Navegan a una página y validan elementos visuales sin screenshot
- Solo toman screenshot en caso de fallo (insuficiente como evidencia positiva)

## Configuración de Playwright recomendada

Además de los screenshots explícitos por test, mantener `screenshot: 'only-on-failure'`
en la config global como red de seguridad. Los screenshots obligatorios del test son
**adicionales** a los de fallo automático.
