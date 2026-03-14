import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

const REPORT_TABS = [
  { label: 'Sprint', path: '/reports/sprint' },
  { label: 'Board Flow', path: '/reports/board-flow' },
  { label: 'Workload', path: '/reports/team-workload' },
  { label: 'Portfolio', path: '/reports/portfolio' },
  { label: 'DORA', path: '/reports/dora' },
  { label: 'Quality', path: '/reports/quality' },
  { label: 'Debt', path: '/reports/debt' },
]

test.describe('Reports Dashboard (FR-10)', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('/reports redirects to /reports/sprint', async ({ page }) => {
    await page.goto('/reports')
    await page.waitForURL('**/reports/sprint', { timeout: 5000 })
    expect(page.url()).toContain('/reports/sprint')
  })

  test('all 7 report tabs are present', async ({ page }) => {
    await page.goto('/reports/sprint')
    await page.waitForSelector('.tabs', { timeout: 5000 })

    for (const tab of REPORT_TABS) {
      await expect(page.locator(`.tab`, { hasText: tab.label })).toBeVisible()
    }
  })

  for (const tab of REPORT_TABS) {
    test(`tab ${tab.label} navigates to ${tab.path}`, async ({ page }) => {
      await page.goto('/reports/sprint')
      await page.waitForSelector('.tabs')
      await page.locator(`.tab`, { hasText: tab.label }).click()
      await page.waitForURL(`**${tab.path}`, { timeout: 5000 })
      expect(page.url()).toContain(tab.path)
    })
  }

  test('reports layout renders the Reports heading', async ({ page }) => {
    await page.goto('/reports/sprint')
    await page.waitForSelector('.reports-header')
    await expect(page.locator('.reports-header h1')).toContainText('Reports')
  })

  test('active tab has active class', async ({ page }) => {
    await page.goto('/reports/dora')
    await page.waitForSelector('.tabs')
    const activeTab = page.locator('.tab.active')
    await expect(activeTab).toBeVisible()
    await expect(activeTab).toContainText('DORA')
  })

  test('chart containers present on sprint report page', async ({ page }) => {
    await page.goto('/reports/sprint')
    await page.waitForSelector('.reports-content', { timeout: 5000 })
    // Charts or empty/error state should be visible
    const content = page.locator('.reports-content')
    await expect(content).toBeVisible()
  })
})
