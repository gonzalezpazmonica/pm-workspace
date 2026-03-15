import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Integrations page', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    await page.goto('/integrations')
    await page.waitForSelector('.layout', { timeout: 10000 })
  })

  test('renders page title', async ({ page }) => {
    await expect(page.locator('.page-title')).toContainText('Integrations')
  })

  test('shows n8n connection section', async ({ page }) => {
    await expect(page.locator('h2', { hasText: 'n8n Connection' })).toBeVisible()
  })

  test('shows workflows section with mock data', async ({ page }) => {
    await expect(page.locator('h2', { hasText: 'Workflows' })).toBeVisible()
    const cards = page.locator('.wf-card')
    await expect(cards.first()).toBeVisible({ timeout: 5000 })
  })

  test('shows recent executions table', async ({ page }) => {
    await expect(page.locator('.exec-table')).toBeVisible()
    const rows = page.locator('.exec-table tbody tr')
    await expect(rows.first()).toBeVisible({ timeout: 5000 })
  })

  test('connection setup form is visible when not connected', async ({ page }) => {
    await expect(page.locator('.setup-form')).toBeVisible()
    await expect(page.locator('.setup-form input').first()).toBeVisible()
  })
})
