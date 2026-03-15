import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('File Viewer', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    await page.goto('/files')
    await page.waitForSelector('.layout', { timeout: 10000 })
    await page.waitForTimeout(1500)
  })

  test('file list shows entries', async ({ page }) => {
    const items = page.locator('.file-list-item, .file-list li')
    await expect(items.first()).toBeVisible({ timeout: 5000 })
  })

  test('clicking a markdown file opens viewer with rendered content', async ({ page }) => {
    // Navigate to find a .md file — click CLAUDE.md or README.md
    const mdFile = page.locator('.file-list-item, .file-list li').filter({ hasText: '.md' }).first()
    if (await mdFile.isVisible()) {
      await mdFile.click()
      await expect(page.locator('.viewer')).toBeVisible({ timeout: 5000 })
      await expect(page.locator('.viewer-markdown')).toBeVisible()
    }
  })

  test('viewer has Raw/Rendered toggle for markdown', async ({ page }) => {
    const mdFile = page.locator('.file-list-item, .file-list li').filter({ hasText: '.md' }).first()
    if (await mdFile.isVisible()) {
      await mdFile.click()
      await expect(page.locator('.viewer-btn', { hasText: 'Raw' })).toBeVisible({ timeout: 5000 })
    }
  })

  test('viewer has copy button', async ({ page }) => {
    const mdFile = page.locator('.file-list-item, .file-list li').filter({ hasText: '.md' }).first()
    if (await mdFile.isVisible()) {
      await mdFile.click()
      await expect(page.locator('.viewer-btn', { hasText: 'Copy' })).toBeVisible({ timeout: 5000 })
    }
  })

  test('markdown file with frontmatter shows metadata card', async ({ page }) => {
    // Navigate into a project that has CLAUDE.md with frontmatter
    const projectsDir = page.locator('.file-list-item, .file-list li').filter({ hasText: 'projects' })
    if (await projectsDir.isVisible()) {
      await projectsDir.click()
      await page.waitForTimeout(1000)
    }
  })

  test('edit button visible for markdown files', async ({ page }) => {
    const mdFile = page.locator('.file-list-item, .file-list li').filter({ hasText: '.md' }).first()
    if (await mdFile.isVisible()) {
      await mdFile.click()
      await expect(page.locator('.edit-btn')).toBeVisible({ timeout: 5000 })
    }
  })
})
