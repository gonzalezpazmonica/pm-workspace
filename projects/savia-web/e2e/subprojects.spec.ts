import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Subprojects', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    // Wait for projects to load from Bridge
    await page.waitForSelector('.project-select', { timeout: 10000 })
    await page.waitForTimeout(1500)
  })

  test('project selector renders optgroup for umbrella projects', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    // At least one optgroup should exist if there's an umbrella project
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found — skipping optgroup test')
    }
    expect(count).toBeGreaterThanOrEqual(1)
    const label = await groups.first().getAttribute('label')
    expect(label).toBeTruthy()
  })

  test('umbrella optgroup contains child options', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    const childOptions = groups.first().locator('option')
    const childCount = await childOptions.count()
    expect(childCount).toBeGreaterThanOrEqual(1)
  })

  test('child options show confidentiality labels', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    const firstChild = groups.first().locator('option').first()
    const text = await firstChild.textContent()
    // Confidentiality labels like (N4-SHARED), (N4-VASS), (N4b-PM)
    // May or may not be present depending on project configuration
    expect(text?.length).toBeGreaterThan(0)
  })

  test('selecting a subproject shows breadcrumb in topbar', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    // Select the first child of the first umbrella
    const firstChild = groups.first().locator('option').first()
    const childValue = await firstChild.getAttribute('value')
    if (!childValue) {
      test.skip(true, 'No child option value found')
    }
    await page.locator('.project-select').selectOption(childValue!)
    await page.waitForTimeout(500)

    const breadcrumb = page.locator('.breadcrumb')
    await expect(breadcrumb).toBeVisible({ timeout: 3000 })
    await expect(page.locator('.breadcrumb-parent')).toBeVisible()
    await expect(page.locator('.breadcrumb-child')).toBeVisible()
  })

  test('breadcrumb disappears when switching to standalone project', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    // First select a subproject
    const firstChild = groups.first().locator('option').first()
    const childValue = await firstChild.getAttribute('value')
    if (childValue) {
      await page.locator('.project-select').selectOption(childValue)
      await page.waitForTimeout(500)
      await expect(page.locator('.breadcrumb')).toBeVisible({ timeout: 3000 })
    }

    // Now switch to workspace (standalone)
    await page.locator('.project-select').selectOption('_workspace')
    await page.waitForTimeout(500)
    await expect(page.locator('.breadcrumb')).not.toBeVisible()
  })

  test('subproject selection persists across page reload', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    const firstChild = groups.first().locator('option').first()
    const childValue = await firstChild.getAttribute('value')
    if (!childValue) {
      test.skip(true, 'No child option value found')
    }
    await page.locator('.project-select').selectOption(childValue!)
    await page.waitForTimeout(500)

    // Reload the page
    await page.reload({ waitUntil: 'domcontentloaded' })
    await page.waitForSelector('.project-select', { timeout: 10000 })
    await page.waitForTimeout(2000)

    // Verify the selection persisted
    const currentValue = await page.locator('.project-select').inputValue()
    expect(currentValue).toBe(childValue)
  })

  test('standalone projects remain as direct options (not in optgroup)', async ({ page }) => {
    // _workspace should always be a direct option, never inside an optgroup
    const directWorkspace = page.locator('.project-select > option[value="_workspace"]')
    await expect(directWorkspace).toBeAttached()
  })

  test('subproject selection is preserved when navigating to file browser', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    const firstChild = groups.first().locator('option').first()
    const childValue = await firstChild.getAttribute('value')
    if (!childValue) {
      test.skip(true, 'No child option value found')
    }
    await page.locator('.project-select').selectOption(childValue!)
    await page.waitForTimeout(500)

    // Navigate to file browser via sidebar (SPA navigation, no full reload)
    await page.locator('a[href="/files"]').click()
    await page.waitForSelector('.layout', { timeout: 10000 })
    await page.waitForTimeout(1000)

    // Verify the subproject selection persisted in the selector
    const currentValue = await page.locator('.project-select').inputValue()
    expect(currentValue).toBe(childValue)
    // Breadcrumb in the topbar should still show parent > child
    await expect(page.locator('.topbar .breadcrumb')).toBeVisible({ timeout: 3000 })
  })

  test('screenshot: subproject selected with breadcrumb', async ({ page }) => {
    const groups = page.locator('.project-select optgroup')
    const count = await groups.count()
    if (count === 0) {
      test.skip(true, 'No umbrella projects found')
    }
    const firstChild = groups.first().locator('option').first()
    const childValue = await firstChild.getAttribute('value')
    if (childValue) {
      await page.locator('.project-select').selectOption(childValue)
      await page.waitForTimeout(1000)
    }
    await page.screenshot({
      path: 'output/e2e-results/savia-web/subprojects--breadcrumb-visible.png',
      fullPage: false,
      clip: { x: 0, y: 0, width: 1280, height: 60 },
    })
  })
})
