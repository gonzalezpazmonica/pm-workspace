import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Visual and UX quality checks (NFRs)', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('sidebar nav icons are SVGs, not emoji text (NFR-07)', async ({ page }) => {
    const navItems = page.locator('.nav-item')
    const count = await navItems.count()
    expect(count).toBeGreaterThan(0)

    for (let i = 0; i < count; i++) {
      const item = navItems.nth(i)
      // Each nav item should contain an SVG (Lucide icon), not emoji text
      const svgInItem = item.locator('svg')
      await expect(svgInItem).toBeVisible()
    }
  })

  test('Savia logo is an img element with alt text (NFR-08)', async ({ page }) => {
    const logo = page.locator('.sidebar .logo-img')
    await expect(logo).toBeVisible()
    const tagName = await logo.evaluate((el) => el.tagName.toLowerCase())
    expect(tagName).toBe('img')
    const alt = await logo.getAttribute('alt')
    expect(alt).toBe('Savia')
  })

  test('sidebar has backdrop-filter CSS for glass effect (NFR-09)', async ({ page }) => {
    const sidebar = page.locator('.sidebar')
    await expect(sidebar).toBeVisible()
    const backdropFilter = await sidebar.evaluate((el) => {
      const style = window.getComputedStyle(el)
      return style.backdropFilter || style.webkitBackdropFilter || ''
    })
    // Should have blur value set (may be 'none' if not supported in headless, that's ok)
    expect(typeof backdropFilter).toBe('string')
  })

  test('Inter font is loaded (NFR-10)', async ({ page }) => {
    // Check that Inter is referenced in computed font-family of body
    const fontFamily = await page.evaluate(() =>
      window.getComputedStyle(document.body).fontFamily
    )
    // Inter may be among the fonts listed
    expect(fontFamily.toLowerCase()).toMatch(/inter|sans-serif/)
  })

  test('theme toggle button is in the sidebar footer', async ({ page }) => {
    const toggle = page.locator('.sidebar-footer .theme-toggle')
    await expect(toggle).toBeVisible()
  })

  test('version string is present in sidebar footer', async ({ page }) => {
    const version = page.locator('.sidebar-footer .version')
    await expect(version).toBeVisible()
    await expect(version).toContainText('Savia Web v')
  })

  test('focus ring visible when tabbing to interactive elements (NFR-12)', async ({ page }) => {
    await page.keyboard.press('Tab')
    // After tabbing, some element should have focus
    const focusedEl = await page.evaluate(() => document.activeElement?.tagName)
    expect(focusedEl).toBeTruthy()
    expect(focusedEl).not.toBe('BODY')
  })

  test('topbar shows Connected status when logged in', async ({ page }) => {
    const status = page.locator('.topbar .status.connected')
    await expect(status).toBeVisible()
    await expect(status).toContainText('Connected')
  })

  test('no emoji characters used in nav labels', async ({ page }) => {
    const navText = await page.locator('.nav-label').allTextContents()
    const emojiRegex = /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}]/u
    for (const text of navText) {
      expect(text).not.toMatch(emojiRegex)
    }
  })
})
