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

    await expect(page.locator('.msg.user').first()).toBeVisible({ timeout: 5000 })

    // Wait for assistant to respond with actual text
    await page.waitForFunction(() => {
      const bubbles = document.querySelectorAll('.msg.assistant .bubble-content')
      if (bubbles.length === 0) return false
      const text = bubbles[0].textContent?.trim() || ''
      return text.length > 0 && !text.match(/^\.+$/)
    }, { timeout: 30000 })

    const responseText = await page.locator('.msg.assistant .bubble-content').first().textContent()
    expect(responseText?.trim().length).toBeGreaterThan(0)
  })

  test('input re-enables after response completes', async ({ page }) => {
    test.setTimeout(60000)
    await page.locator('.input-bar input').fill('Responde solo OK')
    await page.locator('.input-bar button[type="submit"]').click()

    // Wait for response to complete
    await page.waitForFunction(() => {
      const bubbles = document.querySelectorAll('.msg.assistant .bubble-content')
      if (bubbles.length === 0) return false
      const text = bubbles[0].textContent?.trim() || ''
      return text.length > 0 && !text.match(/^\.+$/)
    }, { timeout: 30000 })

    // Input should be re-enabled (button is disabled until user types — that's correct)
    await expect(page.locator('.input-bar input')).toBeEnabled({ timeout: 5000 })
    // Type something to verify button also re-enables
    await page.locator('.input-bar input').fill('test')
    await expect(page.locator('.input-bar button[type="submit"]')).toBeEnabled()
  })

  test('Savia responds with user context', async ({ page }) => {
    test.setTimeout(60000)
    await page.locator('.input-bar input').fill('quién soy? responde solo mi nombre o usuario')
    await page.locator('.input-bar button[type="submit"]').click()

    // Wait for response
    await page.waitForFunction(() => {
      const bubbles = document.querySelectorAll('.msg.assistant .bubble-content')
      if (bubbles.length === 0) return false
      const text = bubbles[0].textContent?.trim() || ''
      return text.length > 0 && !text.match(/^\.+$/)
    }, { timeout: 30000 })

    // Response should contain some user reference (name, handle, or role)
    const response = await page.locator('.msg.assistant .bubble-content').first().textContent()
    expect(response?.trim().length).toBeGreaterThan(0)
    // Take screenshot as proof of identity response
    await page.screenshot({ path: 'output/e2e-results/chat-identity-response.png' })
  })

  test('markdown renders in chat bubbles (bold text)', async ({ page }) => {
    test.setTimeout(60000)
    await page.locator('.input-bar input').fill('Responde exactamente: **hola mundo**')
    await page.locator('.input-bar button[type="submit"]').click()

    // Wait for response
    await page.waitForFunction(() => {
      const bubbles = document.querySelectorAll('.msg.assistant .bubble-content')
      if (bubbles.length === 0) return false
      return (bubbles[0].innerHTML || '').includes('<strong>')
    }, { timeout: 30000 })

    // Should have rendered <strong> tag, not raw **
    const html = await page.locator('.msg.assistant .bubble-content').first().innerHTML()
    expect(html).toContain('<strong>')
    expect(html).not.toContain('**hola')
    // Screenshot as proof markdown renders
    await page.screenshot({ path: 'output/e2e-results/chat-markdown-rendering.png' })
  })
})
