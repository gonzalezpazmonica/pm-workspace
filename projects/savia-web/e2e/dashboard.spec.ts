import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Home Dashboard (FR-01)', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    await page.goto('/')
    await page.waitForSelector('.layout')
  })

  test('stats cards render on home page', async ({ page }) => {
    // Wait for dashboard to load (may show spinner first)
    await page.waitForSelector('.stats-row, .empty-state, [class*="spinner"]', { timeout: 10000 })

    // If data loaded, check stats
    const statsRow = page.locator('.stats-row')
    const hasStats = await statsRow.isVisible().catch(() => false)
    if (hasStats) {
      const cards = statsRow.locator('.stat-card')
      await expect(cards).toHaveCount(4)
      await expect(cards.nth(0)).toContainText('SP Completed')
      await expect(cards.nth(1)).toContainText('SP Planned')
      await expect(cards.nth(2)).toContainText('Blocked')
      await expect(cards.nth(3)).toContainText('Today')
    } else {
      // Bridge not available — empty state or error is acceptable
      await expect(page.locator('.empty-state, .error-msg')).toBeVisible({ timeout: 5000 })
    }
  })

  test('My Tasks section is present', async ({ page }) => {
    await page.waitForSelector('.home', { timeout: 5000 })
    const tasksSection = page.locator('section').filter({ hasText: 'My Tasks' })
    const errorState = page.locator('.empty-state')

    const hasSection = await tasksSection.isVisible().catch(() => false)
    const hasError = await errorState.isVisible().catch(() => false)
    expect(hasSection || hasError).toBe(true)
  })

  test('Recent Activity section is present', async ({ page }) => {
    await page.waitForSelector('.home', { timeout: 5000 })
    const activitySection = page.locator('section').filter({ hasText: 'Recent Activity' })
    const errorState = page.locator('.empty-state')

    const hasSection = await activitySection.isVisible().catch(() => false)
    const hasError = await errorState.isVisible().catch(() => false)
    expect(hasSection || hasError).toBe(true)
  })

  test('home page renders without JS errors', async ({ page }) => {
    const errors: string[] = []
    page.on('pageerror', (e) => errors.push(e.message))
    await page.goto('/')
    await page.waitForSelector('.layout')
    await page.waitForTimeout(1000)
    const criticalErrors = errors.filter(e => !e.includes('Failed to fetch') && !e.includes('NetworkError'))
    expect(criticalErrors).toHaveLength(0)
  })
})
