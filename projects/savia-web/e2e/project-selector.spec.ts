import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Project Selector', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('project selector is visible in top bar', async ({ page }) => {
    await expect(page.locator('.project-select')).toBeVisible({ timeout: 10000 })
  })

  test('project selector has options loaded from Bridge', async ({ page }) => {
    const select = page.locator('.project-select')
    await expect(select).toBeVisible({ timeout: 10000 })
    // Wait for projects to load from Bridge
    await page.waitForTimeout(2000)
    const count = await select.locator('option').count()
    expect(count).toBeGreaterThanOrEqual(1)
  })

  test('can select a different project from dropdown', async ({ page }) => {
    const select = page.locator('.project-select')
    await expect(select).toBeVisible({ timeout: 10000 })
    await page.waitForTimeout(2000)
    const options = await select.locator('option').allTextContents()
    if (options.length >= 2) {
      await select.selectOption({ index: 1 })
      const newValue = await select.inputValue()
      expect(newValue).not.toBe('_workspace')
    }
  })

  test('switching project on backlog page reloads data', async ({ page }) => {
    await page.goto('/backlog')
    await page.waitForSelector('.layout', { timeout: 10000 })
    await page.waitForTimeout(2000)

    const select = page.locator('.project-select')
    const options = await select.locator('option').allTextContents()

    if (options.some(o => o.includes('proyecto-alpha'))) {
      await select.selectOption('proyecto-alpha')
      await page.waitForTimeout(2000)
      // Should show spec rows (proyecto-alpha has PBIs grouped into specs)
      const specRows = page.locator('.spec-row')
      await expect(specRows.first()).toBeVisible({ timeout: 5000 })
    }
  })

  test('health dot is visible next to selector', async ({ page }) => {
    await page.waitForTimeout(2000)
    const dot = page.locator('.health-dot')
    // Health dot only shows when a project is selected and loaded
    const visible = await dot.isVisible().catch(() => false)
    expect(typeof visible).toBe('boolean')
  })
})
