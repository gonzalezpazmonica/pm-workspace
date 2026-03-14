import { test, expect } from '@playwright/test'
import { requireBridge, login, clearSession } from './helpers'

test.describe('Chat page (FR-02)', () => {
  test.beforeEach(async ({ page }) => {
    await requireBridge()
    await clearSession(page)
    await login(page)
    await page.goto('/chat', { waitUntil: 'domcontentloaded' })
    await page.waitForSelector('.chat-page', { timeout: 10000 })
  })

  test.slow()

  test('chat page container is visible', async ({ page }) => {
    await expect(page.locator('.chat-page')).toBeVisible()
  })

  test('message input has correct placeholder', async ({ page }) => {
    const input = page.locator('.input-bar input')
    await expect(input).toBeVisible()
    await expect(input).toHaveAttribute('placeholder', 'Send a message to Savia...')
  })

  test('send button is disabled when input is empty', async ({ page }) => {
    const btn = page.locator('.input-bar button[type="submit"]')
    await expect(btn).toBeVisible()
    await expect(btn).toBeDisabled()
  })

  test('send button becomes enabled when text is typed', async ({ page }) => {
    await page.locator('.input-bar input').fill('Hello Savia')
    await expect(page.locator('.input-bar button[type="submit"]')).toBeEnabled()
  })

  test('messages container is visible', async ({ page }) => {
    await expect(page.locator('.messages')).toBeVisible()
  })

  test('sending a message adds user bubble to message list', async ({ page }) => {
    await page.locator('.input-bar input').fill('Hello Savia')
    await page.locator('.input-bar button[type="submit"]').click()
    // User message bubble must appear
    await expect(page.locator('.msg.user').first()).toBeVisible({ timeout: 5000 })
    await expect(page.locator('.msg.user .bubble-content').first()).toContainText('Hello Savia')
    // Assistant placeholder appears (do not wait for full response)
    await expect(page.locator('.msg.assistant').first()).toBeVisible({ timeout: 5000 })
  })
})
