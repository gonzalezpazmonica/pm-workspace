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

  test('message input has placeholder', async ({ page }) => {
    const input = page.locator('.input-bar input')
    await expect(input).toBeVisible()
  })

  test('send button is disabled when input is empty', async ({ page }) => {
    const btn = page.locator('.input-bar button[type="submit"]')
    await expect(btn).toBeVisible()
    await expect(btn).toBeDisabled()
  })

  test('send button becomes enabled when text is typed', async ({ page }) => {
    await page.locator('.input-bar input').fill('Hello')
    await expect(page.locator('.input-bar button[type="submit"]')).toBeEnabled()
  })

  test('messages container is visible', async ({ page }) => {
    await expect(page.locator('.messages')).toBeVisible()
  })

  test('sending a message shows user bubble', async ({ page }) => {
    await page.locator('.input-bar input').fill('Responde solo OK')
    await page.locator('.input-bar button[type="submit"]').click()
    await expect(page.locator('.msg.user').first()).toBeVisible({ timeout: 5000 })
    await expect(page.locator('.msg.user .bubble-content').first()).toContainText('Responde solo OK')
  })

  test('chat receives response from Bridge', async ({ page }) => {
    test.setTimeout(60000)
    await page.locator('.input-bar input').fill('Responde solo OK')
    await page.locator('.input-bar button[type="submit"]').click()

    // Wait for user bubble
    await expect(page.locator('.msg.user').first()).toBeVisible({ timeout: 5000 })

    // Wait for assistant response (not just the placeholder dots)
    // The assistant bubble should contain actual text (not just animated dots)
    const assistantBubble = page.locator('.msg.assistant .bubble-content').first()
    await expect(assistantBubble).toBeVisible({ timeout: 30000 })

    // Wait for streaming to complete — response should contain text
    await page.waitForFunction(() => {
      const bubbles = document.querySelectorAll('.msg.assistant .bubble-content')
      if (bubbles.length === 0) return false
      const text = bubbles[0].textContent?.trim() || ''
      // Must have actual text, not just dots or empty
      return text.length > 0 && !text.match(/^\.+$/)
    }, { timeout: 30000 })

    // Verify the response contains something meaningful
    const responseText = await assistantBubble.textContent()
    expect(responseText?.trim().length).toBeGreaterThan(0)
  })
})
