import { test, expect } from '@playwright/test'
import { requireBridge, login, clearSession } from './helpers'

const navItems = [
  { label: 'Home', path: '/' },
  { label: 'Chat', path: '/chat' },
  { label: 'Commands', path: '/commands' },
  { label: 'Kanban', path: '/kanban' },
  { label: 'Approvals', path: '/approvals' },
  { label: 'Time Log', path: '/timelog' },
  { label: 'Files', path: '/files' },
  { label: 'Reports', path: '/reports' },
  { label: 'Profile', path: '/profile' },
  { label: 'Settings', path: '/settings' },
]

test.describe('Sidebar navigation', () => {
  test.beforeEach(async ({ page }) => {
    await requireBridge()
    await clearSession(page)
    await login(page)
  })

  test.slow()

  for (const item of navItems) {
    test(`clicking ${item.label} navigates to ${item.path}`, async ({ page }) => {
      const link = page.locator('.nav-item', { hasText: item.label })
      await expect(link).toBeVisible({ timeout: 10000 })
      await link.click()
      await page.waitForURL(new RegExp(item.path.replace('/', '\\/') + '.*'), { timeout: 8000 })
      await expect(page.locator('.nav-item.active')).toBeVisible()
    })
  }

  test('active nav item is highlighted for current page', async ({ page }) => {
    await page.goto('/commands', { waitUntil: 'domcontentloaded' })
    await page.waitForSelector('.layout', { timeout: 10000 })
    await expect(page.locator('.nav-item.active')).toContainText('Commands')
  })

  test('sidebar collapse/expand via menu button', async ({ page }) => {
    const sidebar = page.locator('.sidebar')
    await expect(sidebar).not.toHaveClass(/collapsed/)
    await page.locator('.menu-btn').click()
    await expect(sidebar).toHaveClass(/collapsed/)
    await page.locator('.menu-btn').click()
    await expect(sidebar).not.toHaveClass(/collapsed/)
  })

  test('Savia logo is visible in sidebar', async ({ page }) => {
    const logo = page.locator('.sidebar .logo-img')
    await expect(logo).toBeVisible({ timeout: 10000 })
    await expect(logo).toHaveAttribute('alt', 'Savia')
  })

  test('version text visible in sidebar footer', async ({ page }) => {
    await expect(page.locator('.version')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('.version')).toContainText('Savia Web v')
  })
})
