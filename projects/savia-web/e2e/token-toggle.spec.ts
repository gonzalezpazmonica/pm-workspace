import { test, expect } from '@playwright/test'
import { clearSession } from './helpers'

test.describe('Token visibility toggle', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
  })

  test('eye button is visible on login form', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    await expect(page.locator('[data-testid="toggle-token"]')).toBeVisible()
  })

  test('token field starts as password (hidden)', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    await expect(page.locator('.input-with-eye input')).toHaveAttribute('type', 'password')
  })

  test('clicking eye reveals token text', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    await page.locator('.input-with-eye input').fill('my-secret-token')
    await page.locator('[data-testid="toggle-token"]').click()
    await expect(page.locator('.input-with-eye input')).toHaveAttribute('type', 'text')
  })

  test('clicking eye twice hides token again', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    await page.locator('.input-with-eye input').fill('my-secret-token')
    await page.locator('[data-testid="toggle-token"]').click()
    await expect(page.locator('.input-with-eye input')).toHaveAttribute('type', 'text')
    await page.locator('[data-testid="toggle-token"]').click()
    await expect(page.locator('.input-with-eye input')).toHaveAttribute('type', 'password')
  })
})

test.describe('Certificate hint on HTTPS connection failure', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
  })

  test('shows cert hint with health link when HTTPS connection fails', async ({ page }) => {
    await page.goto('/')
    await page.waitForSelector('.login-overlay', { timeout: 10000 })
    const fakeUrl = 'https://10.255.255.1:19999'
    await page.locator('input[placeholder*="localhost"]').fill(fakeUrl)
    await page.locator('input[placeholder="@your-handle"]').fill('@test')
    await page.locator('.input-with-eye input').fill('dummy-token')
    await page.locator('.btn-connect').click()
    const hint = page.locator('[data-testid="cert-hint"]')
    await expect(hint).toBeVisible({ timeout: 15000 })
    const link = hint.locator('a')
    await expect(link).toHaveAttribute('href', `${fakeUrl}/health`)
  })
})
