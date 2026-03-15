import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Create Project', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
  })

  test('create project button is visible in topbar', async ({ page }) => {
    await expect(page.locator('.add-project-btn')).toBeVisible({ timeout: 10000 })
  })

  test('clicking create button opens modal', async ({ page }) => {
    await page.locator('.add-project-btn').click()
    await expect(page.locator('.modal-overlay')).toBeVisible()
    await expect(page.locator('.modal')).toBeVisible()
  })

  test('modal has required form fields', async ({ page }) => {
    await page.locator('.add-project-btn').click()
    await expect(page.locator('.modal input').first()).toBeVisible()
    await expect(page.locator('.modal select').first()).toBeVisible()
  })

  test('modal can be closed by clicking overlay', async ({ page }) => {
    await page.locator('.add-project-btn').click()
    await expect(page.locator('.modal')).toBeVisible()
    // Click on the overlay (outside the modal)
    await page.locator('.modal-overlay').click({ position: { x: 10, y: 10 } })
    await expect(page.locator('.modal')).not.toBeVisible({ timeout: 5000 })
  })

  test('create button is present in modal', async ({ page }) => {
    await page.locator('.add-project-btn').click()
    await expect(page.locator('.modal .btn-create')).toBeVisible({ timeout: 5000 })
  })
})
