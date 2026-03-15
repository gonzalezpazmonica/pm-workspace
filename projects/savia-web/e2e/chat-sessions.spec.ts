import { test, expect } from '@playwright/test'
import { login, clearSession } from './helpers'

test.describe('Chat session management', () => {
  test.beforeEach(async ({ page }) => {
    await clearSession(page)
    await login(page)
    await page.goto('/chat')
    await page.waitForSelector('.layout', { timeout: 10000 })
    await page.waitForTimeout(1000)
  })

  test.slow()

  test('session panel renders with New Chat button', async ({ page }) => {
    await expect(page.locator('.session-list')).toBeVisible()
    await expect(page.locator('.new-chat-btn')).toBeVisible()
    await expect(page.locator('.new-chat-btn')).toContainText('New Chat')
    await page.screenshot({ path: 'output/e2e-results/sessions-panel-visible.png' })
  })

  test('session panel has correct width (260px)', async ({ page }) => {
    const box = await page.locator('.session-list').boundingBox()
    expect(box).not.toBeNull()
    expect(box!.width).toBeGreaterThanOrEqual(250)
    expect(box!.width).toBeLessThanOrEqual(270)
  })

  test('sending first message sets session title with date and digest', async ({ page }) => {
    test.setTimeout(60000)
    await page.locator('.input-bar input').fill('Hola esto es una prueba de título')
    await page.locator('.input-bar button[type="submit"]').click()

    // Wait for response
    await page.waitForFunction(() => {
      const bubbles = document.querySelectorAll('.msg.assistant .bubble-content')
      return bubbles.length > 0 && (bubbles[0].textContent?.trim().length ?? 0) > 0
    }, { timeout: 30000 })

    // Session title should contain date+time and message digest
    const title = await page.locator('.session-item.active .session-title').textContent()
    // Must have date (e.g. "Mar 15") AND time (e.g. "06:32" or "18:32")
    expect(title).toMatch(/\w+ \d+.*\d{2}:\d{2}/)
    expect(title).toContain('Hola esto es una prueba')
    await page.screenshot({ path: 'output/e2e-results/sessions-title-with-digest.png' })
  })

  test('New Chat creates a fresh empty session', async ({ page }) => {
    test.setTimeout(60000)
    // Send a message in current session
    await page.locator('.input-bar input').fill('Responde solo OK')
    await page.locator('.input-bar button[type="submit"]').click()
    await page.waitForFunction(() => {
      const b = document.querySelectorAll('.msg.assistant .bubble-content')
      return b.length > 0 && (b[0].textContent?.trim().length ?? 0) > 0
    }, { timeout: 30000 })

    const sessionsBefore = await page.locator('.session-item').count()

    // Create new session
    await page.locator('.new-chat-btn').click()
    await page.waitForTimeout(500)

    // Messages should be empty
    await expect(page.locator('.msg')).toHaveCount(0)
    // Session list should have one more entry
    const sessionsAfter = await page.locator('.session-item').count()
    expect(sessionsAfter).toBe(sessionsBefore + 1)
    // Active session should be the new one (first in list)
    await expect(page.locator('.session-item').first()).toHaveClass(/active/)
    await page.screenshot({ path: 'output/e2e-results/sessions-new-chat-created.png' })
  })

  test('switching session loads its message history', async ({ page }) => {
    test.setTimeout(60000)
    // Send message in first session
    await page.locator('.input-bar input').fill('Primera sesión test')
    await page.locator('.input-bar button[type="submit"]').click()
    await page.waitForFunction(() => {
      const b = document.querySelectorAll('.msg.assistant .bubble-content')
      return b.length > 0 && (b[0].textContent?.trim().length ?? 0) > 0
    }, { timeout: 30000 })

    // Create new session
    await page.locator('.new-chat-btn').click()
    await page.waitForTimeout(500)
    // Should have empty chat
    await expect(page.locator('.msg')).toHaveCount(0)

    // Switch back to first session (find it by title containing "Primera")
    const firstSession = page.locator('.session-item', { hasText: 'Primera' })
    await expect(firstSession).toBeVisible({ timeout: 5000 })
    await firstSession.click()
    await page.waitForTimeout(1000)

    // Should see first session's messages restored
    await expect(page.locator('.msg.user').first()).toBeVisible({ timeout: 5000 })
    const userMsg = await page.locator('.msg.user .bubble-content').first().textContent()
    expect(userMsg).toContain('Primera sesión')
    await page.screenshot({ path: 'output/e2e-results/sessions-switch-loads-history.png' })
  })

  test('deleting a non-active session removes it from list', async ({ page }) => {
    test.setTimeout(60000)
    // Send message to create a named session
    await page.locator('.input-bar input').fill('Sesión para borrar')
    await page.locator('.input-bar button[type="submit"]').click()
    await page.waitForTimeout(3000)

    // Create a new session (so the first one becomes deletable)
    await page.locator('.new-chat-btn').click()
    await page.waitForTimeout(500)

    const countBefore = await page.locator('.session-item').count()
    expect(countBefore).toBeGreaterThanOrEqual(2)

    // Hover over non-active session to reveal delete button
    const nonActive = page.locator('.session-item:not(.active)').first()
    await nonActive.hover()
    await page.waitForTimeout(300)

    // Click delete
    const deleteBtn = nonActive.locator('.delete-btn')
    await expect(deleteBtn).toBeVisible()
    await deleteBtn.click()
    await page.waitForTimeout(500)

    // Session count should decrease
    const countAfter = await page.locator('.session-item').count()
    expect(countAfter).toBe(countBefore - 1)
    await page.screenshot({ path: 'output/e2e-results/sessions-delete-removes-item.png' })
  })

  test('sessions persist after navigating away and back', async ({ page }) => {
    test.setTimeout(60000)
    // Send message to create a session with title
    await page.locator('.input-bar input').fill('Persistencia test')
    await page.locator('.input-bar button[type="submit"]').click()
    await page.waitForTimeout(3000)

    const sessionTitle = await page.locator('.session-item.active .session-title').textContent()

    // Navigate to Home
    await page.locator('.nav-item', { hasText: 'Home' }).click()
    await page.waitForURL('**/', { timeout: 5000 })

    // Navigate back to Chat
    await page.locator('.nav-item', { hasText: 'Chat' }).click()
    await page.waitForURL('**/chat', { timeout: 5000 })
    await page.waitForTimeout(1000)

    // Session should still be in the list with same title
    const titleAfter = await page.locator('.session-item.active .session-title').textContent()
    expect(titleAfter).toBe(sessionTitle)

    // Messages should still be there
    await expect(page.locator('.msg.user').first()).toBeVisible()
    await page.screenshot({ path: 'output/e2e-results/sessions-persist-after-nav.png' })
  })

  test('deleted sessions stay deleted after page reload', async ({ page }) => {
    test.setTimeout(60000)
    // Send message to create a session
    await page.locator('.input-bar input').fill('Sesión que vamos a borrar')
    await page.locator('.input-bar button[type="submit"]').click()
    await page.waitForTimeout(3000)

    // Create new session so the first one is deletable
    await page.locator('.new-chat-btn').click()
    await page.waitForTimeout(500)

    const countBefore = await page.locator('.session-item').count()

    // Delete non-active session
    const nonActive = page.locator('.session-item:not(.active)').first()
    await nonActive.hover()
    await page.waitForTimeout(300)
    await nonActive.locator('.delete-btn').click()
    await page.waitForTimeout(500)

    const countAfterDelete = await page.locator('.session-item').count()
    expect(countAfterDelete).toBe(countBefore - 1)

    // Hard reload (Ctrl+F5 equivalent)
    await page.reload({ waitUntil: 'networkidle' })
    await page.waitForSelector('.session-list', { timeout: 10000 })
    await page.waitForTimeout(1000)

    // Count should still be the same as after delete
    const countAfterReload = await page.locator('.session-item').count()
    expect(countAfterReload).toBe(countAfterDelete)
    await page.screenshot({ path: 'output/e2e-results/sessions-persist-delete-after-reload.png' })
  })

  test('typing hola auto-creates session with correct name', async ({ page }) => {
    test.setTimeout(60000)
    // Start fresh — create new session
    await page.locator('.new-chat-btn').click()
    await page.waitForTimeout(500)

    // Send hola
    await page.locator('.input-bar input').fill('hola')
    await page.locator('.input-bar button[type="submit"]').click()

    // Wait for response
    await page.waitForFunction(() => {
      const b = document.querySelectorAll('.msg.assistant .bubble-content')
      return b.length > 0 && (b[0].textContent?.trim().length ?? 0) > 0
    }, { timeout: 30000 })

    await page.waitForTimeout(500)

    // Active session should have title with date+time + "hola"
    const title = await page.locator('.session-item.active .session-title').textContent()
    expect(title).toContain('hola')
    // Must have time (HH:MM pattern)
    expect(title).toMatch(/\d{2}:\d{2}/)
    // Must have date (month + day)
    expect(title).toMatch(/\w+ \d+/)
    await page.screenshot({ path: 'output/e2e-results/sessions-hola-auto-created.png' })
  })

  test('toggle button hides and shows session panel', async ({ page }) => {
    await expect(page.locator('.session-list')).toBeVisible()
    await page.locator('.toggle-sessions').click()
    await expect(page.locator('.session-list')).not.toBeVisible()
    await page.screenshot({ path: 'output/e2e-results/sessions-panel-hidden.png' })
    await page.locator('.toggle-sessions').click()
    await expect(page.locator('.session-list')).toBeVisible()
    await page.screenshot({ path: 'output/e2e-results/sessions-panel-shown.png' })
  })
})
