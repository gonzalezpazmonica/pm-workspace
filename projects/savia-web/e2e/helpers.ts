import { Page, test } from '@playwright/test'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'

const tokenPath = join(process.env.HOME || '', '.savia/bridge/auth_token')

export const BRIDGE_URL = process.env.E2E_BRIDGE_URL || 'https://localhost:8922'
export const TOKEN = process.env.E2E_TOKEN ||
  (existsSync(tokenPath) ? readFileSync(tokenPath, 'utf-8').trim() : '')
export const USERNAME = process.env.E2E_USERNAME || '@test-user'

/** Returns true if the bridge is reachable. Uses curl to bypass Node IPv6 issues. */
export async function isBridgeAvailable(): Promise<boolean> {
  const { execSync } = await import('child_process')
  try {
    const result = execSync(
      `curl -sk --max-time 3 -o /dev/null -w "%{http_code}" https://127.0.0.1:8922/health`,
      { encoding: 'utf-8', timeout: 5000 },
    )
    return result.trim() === '200'
  } catch {
    return false
  }
}

/**
 * Skip the current test when bridge is unreachable.
 * Call this at the top of any test that requires a live backend.
 */
export async function requireBridge() {
  const available = await isBridgeAvailable()
  if (!available) {
    test.skip(true, `Bridge not reachable at ${BRIDGE_URL}`)
  }
}

/**
 * Login to the app. Assumes clearSession was called first.
 * Throws if login fails so the calling test fails explicitly.
 */
export async function login(page: Page) {
  await page.goto('/', { waitUntil: 'domcontentloaded' })

  const alreadyLoggedIn = await page.locator('.layout').isVisible().catch(() => false)
  if (alreadyLoggedIn) return

  await page.waitForSelector('.login-overlay', { timeout: 10000 })

  await page.locator('input[placeholder*="localhost"]').fill(BRIDGE_URL)
  await page.locator('input[placeholder="@your-handle"]').fill(USERNAME)
  await page.locator('input[type="password"]').fill(TOKEN)
  await page.locator('.btn-connect').click()

  await page.waitForSelector('.layout, .register-card, .error-msg', { timeout: 20000 })

  const registerVisible = await page.locator('.register-card').isVisible().catch(() => false)
  if (registerVisible) {
    await page.locator('input[placeholder="Your name"]').fill('Test User')
    await page.locator('.btn-register').click()
    await page.waitForSelector('.layout', { timeout: 10000 })
    return
  }

  const errorVisible = await page.locator('.error-msg').isVisible().catch(() => false)
  if (errorVisible) {
    const msg = await page.locator('.error-msg').textContent()
    throw new Error(`Login failed: ${msg}`)
  }
}

/** Navigate to / and clear localStorage + cookies to force fresh login state */
export async function clearSession(page: Page) {
  await page.goto('/', { waitUntil: 'domcontentloaded' })
  await page.evaluate(() => {
    localStorage.clear()
    // Set English locale for E2E tests (default is Spanish)
    localStorage.setItem('savia:locale', 'en')
  })
  await page.context().clearCookies()
  await page.reload({ waitUntil: 'domcontentloaded' })
}
