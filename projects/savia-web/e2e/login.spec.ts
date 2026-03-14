import { test, expect } from '@playwright/test'
import { BRIDGE_URL, TOKEN, USERNAME, requireBridge, login, clearSession } from './helpers'

test.describe('Login flow', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
  })

  // --- Static UI tests (no bridge required) ---

  test('shows login form on first visit', async ({ page }) => {
    await page.goto('/')
    await expect(page.locator('.login-overlay')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('.login-card')).toBeVisible()
  })

  test('login form has all required fields', async ({ page }) => {
    await page.goto('/')
    await expect(page.locator('input[placeholder*="localhost"]')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('input[placeholder="@your-handle"]')).toBeVisible()
    await expect(page.locator('input[type="password"]')).toBeVisible()
    await expect(page.locator('.btn-connect')).toBeVisible()
  })

  test('shows error when username does not start with @', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    await page.locator('input[placeholder*="localhost"]').fill(BRIDGE_URL)
    await page.locator('input[placeholder="@your-handle"]').fill('no-at-sign')
    await page.locator('input[type="password"]').fill(TOKEN || 'dummy-token')
    await page.locator('.btn-connect').click()
    await expect(page.locator('.error-msg')).toContainText('Username must start with @', { timeout: 5000 })
  })

  test('connect button shows Connecting... while loading', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    await page.locator('input[placeholder*="localhost"]').fill('http://localhost:19999') // unreachable
    await page.locator('input[placeholder="@your-handle"]').fill(USERNAME)
    await page.locator('input[type="password"]').fill('dummy')
    await page.locator('.btn-connect').click()
    // Button should show "Connecting..." immediately
    await expect(page.locator('.btn-connect')).toContainText('Connecting...', { timeout: 3000 })
  })

  // --- Bridge-dependent tests ---

  test('successful login shows dashboard layout', async ({ page }) => {
    await requireBridge()
    test.slow()
    await login(page)
    await expect(page.locator('.layout')).toBeVisible({ timeout: 15000 })
    await expect(page.locator('.login-overlay')).not.toBeVisible()
  })

  test('profile name appears in TopBar after login', async ({ page }) => {
    await requireBridge()
    test.slow()
    await login(page)
    await expect(page.locator('.topbar .profile-name')).toBeVisible({ timeout: 15000 })
    const name = await page.locator('.topbar .profile-name').textContent()
    expect(name?.trim().length).toBeGreaterThan(0)
  })

  test('logout clears session and shows login again', async ({ page }) => {
    await requireBridge()
    test.slow()
    await login(page)
    await page.locator('.btn-logout').click()
    await expect(page.locator('.login-overlay')).toBeVisible({ timeout: 5000 })
    await expect(page.locator('.layout')).not.toBeVisible()
  })

  test('cookie persistence: after login, refresh still logged in', async ({ page }) => {
    await requireBridge()
    test.slow()
    await login(page)
    await page.reload({ waitUntil: 'domcontentloaded' })
    await page.waitForSelector('.layout', { timeout: 15000 })
    await expect(page.locator('.layout')).toBeVisible()
  })
})
