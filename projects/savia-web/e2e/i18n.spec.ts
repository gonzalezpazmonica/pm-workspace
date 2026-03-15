import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Internationalization', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('settings page has language selector', async ({ page }) => {
    await page.goto('/settings')
    await page.waitForSelector('.layout', { timeout: 10000 })
    await expect(page.locator('.lang-select')).toBeVisible()
  })

  test('language selector has ES and EN options', async ({ page }) => {
    await page.goto('/settings')
    await page.waitForSelector('.layout', { timeout: 10000 })
    const options = page.locator('.lang-select option')
    await expect(options).toHaveCount(2)
  })

  test('project selector is visible in top bar', async ({ page }) => {
    await expect(page.locator('.project-select')).toBeVisible({ timeout: 10000 })
  })
})
