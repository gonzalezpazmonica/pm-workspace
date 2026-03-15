import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Pipelines page', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    await page.goto('/pipelines')
    await page.waitForSelector('.layout', { timeout: 10000 })
  })

  test('renders page title', async ({ page }) => {
    await expect(page.locator('.page-title')).toContainText('Pipelines')
  })

  test('shows pipeline run cards with mock data', async ({ page }) => {
    const cards = page.locator('.run-card')
    await expect(cards.first()).toBeVisible({ timeout: 5000 })
  })

  test('clicking a run card shows detail with stages', async ({ page }) => {
    await page.locator('.run-card').first().click()
    await expect(page.locator('.run-detail')).toBeVisible()
    await expect(page.locator('.stage-box').first()).toBeVisible()
  })

  test('stage boxes show name and duration', async ({ page }) => {
    await page.locator('.run-card').first().click()
    const stage = page.locator('.stage-box').first()
    await expect(stage.locator('.stage-name')).toBeVisible()
    await expect(stage.locator('.stage-dur')).toBeVisible()
  })

  test('clicking a stage shows log viewer', async ({ page }) => {
    await page.locator('.run-card').first().click()
    await page.locator('.stage-box').first().click()
    await expect(page.locator('.log-viewer')).toBeVisible()
  })
})
