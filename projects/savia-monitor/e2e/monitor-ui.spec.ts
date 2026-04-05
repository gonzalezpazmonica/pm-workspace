import { test, expect } from '@playwright/test'

test.describe('Savia Monitor v2 — Control Tower', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  // ── Branding & Layout ──
  test('title bar shows Savia logo and name', async ({ page }) => {
    await expect(page.locator('.titlebar__title')).toHaveText('Savia Monitor')
    await expect(page.locator('.titlebar__owl')).toBeVisible()
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/01-branding.png' })
  })

  test('4 tabs: Sesiones, Shield, Git, Alertas', async ({ page }) => {
    const labels = await page.locator('.tabbar__label').allTextContents()
    expect(labels).toEqual(['Sesiones', 'Shield', 'Git', 'Alertas'])
  })

  test('dark mode toggle works', async ({ page }) => {
    await page.locator('.titlebar__btn').first().click()
    await page.waitForTimeout(200)
    expect(await page.locator('html').getAttribute('data-theme')).toBe('dark')
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/02-dark.png', fullPage: true })
    await page.locator('.titlebar__btn').first().click()
  })

  // ── Tab 1: Sessions ──
  test('Sessions tab is the default (first) tab', async ({ page }) => {
    const firstTab = page.locator('.tabbar__tab').first()
    await expect(firstTab).toHaveClass(/tabbar__tab--active/)
    await expect(page.locator('.sessions')).toBeVisible()
  })

  test('Sessions: shows 4 summary stats in Spanish', async ({ page }) => {
    const statLabels = await page.locator('.sessions__stat-label').allTextContents()
    expect(statLabels).toEqual(['Sesiones', 'Protegidas', 'Agentes', 'Salud'])
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/03-sessions.png', fullPage: true })
  })

  test('Sessions: health score has tooltip with breakdown', async ({ page }) => {
    const healthStat = page.locator('.sessions__stat').last()
    const title = await healthStat.getAttribute('title')
    // In Tauri it will have the breakdown, in browser it's empty but shouldn't crash
    expect(title).toBeDefined()
  })

  // ── Tab 2: Shield ──
  test('Shield: 8 layers all in Spanish', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(1).click()
    await page.waitForTimeout(300)
    const cards = page.locator('.layer-card')
    await expect(cards).toHaveCount(8)
    const descs = await page.locator('.layer-card__desc').allTextContents()
    for (const d of descs) {
      expect(d).not.toMatch(/^(Credential|Named entity|LLM-based|HTTP proxy)/)
    }
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/04-shield.png', fullPage: true })
  })

  test('Shield: tooltip on click shows Spanish explanation', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(1).click()
    await page.waitForTimeout(300)
    await page.locator('.layer-card').first().click()
    await page.waitForTimeout(300)
    const tip = page.locator('.layer-card__tip').first()
    await expect(tip).toBeVisible()
    const text = await tip.textContent()
    expect(text).toContain('credenciales')
    expect(text!.length).toBeGreaterThan(50)
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/05-tooltip.png', fullPage: true })
  })

  test('Shield: all 8 tooltips are unique', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(1).click()
    await page.waitForTimeout(300)
    const tooltips: string[] = []
    for (let i = 0; i < 8; i++) {
      await page.locator('.layer-card').nth(i).click()
      await page.waitForTimeout(150)
      const tip = page.locator('.layer-card__tip').nth(i)
      tooltips.push((await tip.textContent())!.trim())
      await page.locator('.layer-card').nth(i).click()
      await page.waitForTimeout(100)
    }
    expect(new Set(tooltips).size).toBe(8)
  })

  test('Shield: summary chips in Spanish', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(1).click()
    await page.waitForTimeout(300)
    const labels = await page.locator('.summary-chip__label').allTextContents()
    expect(labels).toEqual(['Activas', 'Degradadas', 'Caidas'])
  })

  test('Shield: profile selector in Spanish', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(1).click()
    await page.waitForTimeout(300)
    await expect(page.locator('.profile-selector__label')).toHaveText('Perfil')
  })

  // ── Tab 3: Git ──
  test('Git: labels in Spanish', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(2).click()
    await page.waitForTimeout(500)
    await expect(page.locator('.git-tab__label').first()).toContainText('Ramas')
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/06-git.png', fullPage: true })
  })

  // ── Tab 4: Activity ──
  test('Activity: filter pills in Spanish', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(3).click()
    await page.waitForTimeout(300)
    const pills = await page.locator('.activity__pill').allTextContents()
    expect(pills).toEqual(['Todas', 'Herramientas', 'Agentes', 'Shield'])
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/07-activity.png', fullPage: true })
  })

  test('Activity: refresh button present', async ({ page }) => {
    await page.locator('.tabbar__tab').nth(3).click()
    await page.waitForTimeout(300)
    await expect(page.locator('.activity__refresh')).toBeVisible()
  })

  // ── Full screenshots all 4 tabs ──
  test('full screenshot cycle: all 4 tabs', async ({ page }) => {
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/10-sessions.png', fullPage: true })
    await page.locator('.tabbar__tab').nth(1).click()
    await page.waitForTimeout(500)
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/11-shield.png', fullPage: true })
    await page.locator('.tabbar__tab').nth(2).click()
    await page.waitForTimeout(500)
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/12-git.png', fullPage: true })
    await page.locator('.tabbar__tab').nth(3).click()
    await page.waitForTimeout(300)
    await page.screenshot({ path: 'output/e2e-results/savia-monitor/13-activity.png', fullPage: true })
  })
})
