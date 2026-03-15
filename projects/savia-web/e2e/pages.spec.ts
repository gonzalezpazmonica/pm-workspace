import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('All pages smoke tests', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('/commands renders heading "Commands"', async ({ page }) => {
    await page.goto('/commands')
    await page.waitForSelector('.layout')
    await expect(page.locator('h1')).toContainText('Commands')
  })

  test('/backlog renders heading "Backlog"', async ({ page }) => {
    await page.goto('/backlog')
    await page.waitForSelector('.layout')
    await expect(page.locator('.backlog-title')).toContainText('Backlog')
  })

  test('/approvals renders heading "Approvals"', async ({ page }) => {
    await page.goto('/approvals')
    await page.waitForSelector('.layout')
    await expect(page.locator('h1')).toContainText('Approvals')
  })

  test('/timelog renders heading "Time Log"', async ({ page }) => {
    await page.goto('/timelog')
    await page.waitForSelector('.layout')
    await expect(page.locator('h1')).toContainText('Time Log')
  })

  test('/files renders file browser', async ({ page }) => {
    await page.goto('/files')
    await page.waitForSelector('.layout')
    await expect(page.locator('.files-toolbar')).toBeVisible()
  })

  test('/pipelines renders heading "Pipelines"', async ({ page }) => {
    await page.goto('/pipelines')
    await page.waitForSelector('.layout')
    await expect(page.locator('.page-title')).toContainText('Pipelines')
  })

  test('/integrations renders heading "Integrations"', async ({ page }) => {
    await page.goto('/integrations')
    await page.waitForSelector('.layout')
    await expect(page.locator('.page-title')).toContainText('Integrations')
  })

  test('/profile renders heading "Profile"', async ({ page }) => {
    await page.goto('/profile')
    await page.waitForSelector('.layout')
    await expect(page.locator('h1')).toContainText('Profile')
  })

  test('/settings renders heading', async ({ page }) => {
    await page.goto('/settings')
    await page.waitForSelector('.layout')
    await expect(page.locator('h1')).toBeVisible()
  })

  test('all pages render without crashing', async ({ page }) => {
    const routes = ['/commands', '/backlog', '/approvals', '/timelog', '/files',
      '/pipelines', '/integrations', '/profile', '/settings']
    for (const route of routes) {
      const errors: string[] = []
      page.on('pageerror', (e) => {
        if (!e.message.includes('Failed to fetch') && !e.message.includes('NetworkError')) {
          errors.push(`${route}: ${e.message}`)
        }
      })
      await page.goto(route)
      await page.waitForSelector('.layout', { timeout: 5000 })
      expect(errors).toHaveLength(0)
    }
  })
})
