import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Backlog page', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    await page.goto('/backlog')
    await page.waitForSelector('.layout', { timeout: 10000 })
    // Wait for backlog data to load
    await page.waitForTimeout(1500)
  })

  test('renders backlog page with title', async ({ page }) => {
    await expect(page.locator('.backlog-title')).toContainText('Backlog')
  })

  test('has tree and kanban view toggle', async ({ page }) => {
    const buttons = page.locator('.view-toggle button')
    await expect(buttons).toHaveCount(2)
  })

  test('has New PBI button', async ({ page }) => {
    await expect(page.locator('.new-pbi-btn')).toBeVisible()
  })

  test('tree view shows spec rows (level 1)', async ({ page }) => {
    const specRows = page.locator('.spec-row')
    await expect(specRows.first()).toBeVisible({ timeout: 5000 })
  })

  test('spec rows show PBI count badge', async ({ page }) => {
    const badge = page.locator('.item-count').first()
    await expect(badge).toBeVisible({ timeout: 5000 })
    await expect(badge).toContainText('PBI')
  })

  test('PBI rows are visible (specs auto-expanded)', async ({ page }) => {
    const pbiRows = page.locator('.pbi-row')
    await expect(pbiRows.first()).toBeVisible({ timeout: 5000 })
  })

  test('PBI rows have type icons', async ({ page }) => {
    const icon = page.locator('.pbi-row .pbi-icon').first()
    await expect(icon).toBeVisible({ timeout: 5000 })
  })

  test('switching to kanban view shows columns', async ({ page }) => {
    await page.locator('.view-toggle button', { hasText: 'Kanban' }).click()
    await expect(page.locator('.kanban-col').first()).toBeVisible()
  })

  test('clicking a PBI opens detail panel with state selector', async ({ page }) => {
    const pbiRow = page.locator('.pbi-row').first()
    await expect(pbiRow).toBeVisible({ timeout: 5000 })
    await pbiRow.click()
    await expect(page.locator('.detail-panel')).toBeVisible({ timeout: 5000 })
    await expect(page.locator('.state-select')).toBeVisible()
  })

  test('clicking a spec row opens spec detail', async ({ page }) => {
    await page.locator('.spec-row').first().click()
    await expect(page.locator('.detail-panel')).toBeVisible({ timeout: 5000 })
  })

  test('PBI detail has 4 tabs', async ({ page }) => {
    await page.locator('.pbi-row').first().click()
    await expect(page.locator('.detail-panel')).toBeVisible({ timeout: 5000 })
    const tabs = page.locator('.tabs button')
    await expect(tabs).toHaveCount(4)
  })

  test('description tab has editable textarea', async ({ page }) => {
    await page.locator('.pbi-row').first().click()
    await expect(page.locator('.desc-editor')).toBeVisible({ timeout: 5000 })
  })

  test('tasks tab has Add Task button', async ({ page }) => {
    await page.locator('.pbi-row').first().click()
    await expect(page.locator('.detail-panel')).toBeVisible({ timeout: 5000 })
    await page.locator('.tabs button', { hasText: 'Tasks' }).click()
    await expect(page.locator('.add-btn')).toBeVisible()
  })

  test('can change PBI state via dropdown', async ({ page }) => {
    await page.locator('.pbi-row').first().click()
    await expect(page.locator('.state-select')).toBeVisible({ timeout: 5000 })
    await page.locator('.state-select').selectOption('Resolved')
    await expect(page.locator('.state-select')).toHaveValue('Resolved')
  })

  test('New PBI form appears and creates item', async ({ page }) => {
    await page.locator('.new-pbi-btn').click()
    await expect(page.locator('.new-pbi-form')).toBeVisible()
    await page.locator('.new-pbi-input').fill('Test PBI from E2E')
    await page.locator('.create-btn').click()
    await expect(page.locator('.detail-panel')).toBeVisible({ timeout: 5000 })
  })

  test('closing detail panel works', async ({ page }) => {
    await page.locator('.pbi-row').first().click()
    await expect(page.locator('.detail-panel')).toBeVisible({ timeout: 5000 })
    await page.locator('.close-btn').click()
    await expect(page.locator('.detail-panel')).not.toBeVisible()
  })

  test('filter bar is visible', async ({ page }) => {
    await expect(page.locator('.filter-bar')).toBeVisible()
  })

  test('type toggle buttons are visible (Spec, PBI, Task)', async ({ page }) => {
    const toggles = page.locator('.type-toggles button')
    await expect(toggles).toHaveCount(3)
  })

  test('clicking type toggle hides items', async ({ page }) => {
    const pbisBefore = await page.locator('.pbi-row').count()
    await page.locator('.type-toggles button', { hasText: 'PBI' }).click()
    await page.waitForTimeout(500)
    const pbisAfter = await page.locator('.pbi-row').count()
    expect(pbisAfter).toBeLessThan(pbisBefore)
  })

  test('assignee filter dropdown is present', async ({ page }) => {
    await expect(page.locator('.assignee-filter')).toBeVisible()
  })
})
