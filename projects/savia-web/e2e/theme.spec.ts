import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Dark/light mode toggle (NFR-02)', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('theme toggle button is visible in sidebar footer', async ({ page }) => {
    await expect(page.locator('.theme-toggle')).toBeVisible()
  })

  test('clicking toggle changes data-theme on html element', async ({ page }) => {
    // Get initial theme
    const initialTheme = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme') || 'light'
    )

    await page.locator('.theme-toggle').click()
    await page.waitForTimeout(200)

    const newTheme = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme') || 'light'
    )

    expect(newTheme).not.toBe(initialTheme)
    expect(['light', 'dark']).toContain(newTheme)
  })

  test('dark mode setting persists after page refresh', async ({ page }) => {
    // Ensure we're in light mode first
    const currentTheme = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme') || 'light'
    )

    if (currentTheme !== 'dark') {
      await page.locator('.theme-toggle').click()
      await page.waitForTimeout(200)
    }

    const themeBefore = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme')
    )
    expect(themeBefore).toBe('dark')

    // Reload — theme should persist via localStorage
    await page.reload()
    await page.waitForSelector('.layout', { timeout: 15000 })

    const themeAfter = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme')
    )
    expect(themeAfter).toBe('dark')
  })

  test('can toggle back from dark mode to light mode', async ({ page }) => {
    // Activate dark mode
    const currentTheme = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme') || 'light'
    )
    if (currentTheme !== 'dark') {
      await page.locator('.theme-toggle').click()
      await page.waitForTimeout(200)
    }

    // Toggle back to light
    await page.locator('.theme-toggle').click()
    await page.waitForTimeout(200)

    const theme = await page.evaluate(() =>
      document.documentElement.getAttribute('data-theme')
    )
    expect(theme).toBe('light')
  })

  test('localStorage stores the theme preference', async ({ page }) => {
    await page.locator('.theme-toggle').click()
    await page.waitForTimeout(200)

    const storedTheme = await page.evaluate(() =>
      localStorage.getItem('savia_theme')
    )
    expect(storedTheme).toBeTruthy()
    expect(['light', 'dark']).toContain(storedTheme)
  })
})
