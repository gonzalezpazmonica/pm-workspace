// Drives the built UI against a running savia-space: pair → session → search/capture → select → prepare →
// inspector hash check → send → streamed answer with verified citations → export link.
// Usage: node e2e/ui.e2e.mjs <profile> <preset> <query> [query2]   (BIN and CHROME from env)
import { chromium } from 'playwright-core'
import { execFileSync } from 'node:child_process'

const [profile, preset, ...queries] = process.argv.slice(2)
const BIN = process.env.BIN ?? '../../target/release/savia-space'
const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome' })
const page = await browser.newPage()
const cspErrors = []
page.on('console', (m) => m.type() === 'error' && cspErrors.push(m.text()))
const step = (s) => console.log('·', s)

await page.goto('http://127.0.0.1:8737/')
await page.getByText('Emparejar este navegador').waitFor()
const code = execFileSync(BIN, ['pair'], { encoding: 'utf8' }).trim().split('\n').at(-1)
await page.getByLabel('Código de emparejamiento').fill(code)
await page.getByRole('button', { name: 'Emparejar' }).click()
step('paired')
await page.getByPlaceholder('Título de la sesión').fill(`UI ${preset} ${Date.now()}`)
await page.getByRole('button', { name: 'Crear' }).click()
await page.getByText('Sin fuentes seleccionadas').waitFor()
step('session created')
for (const q of queries) {
  await page.getByPlaceholder('Qué buscas en las cúpulas').fill(q)
  await page.getByRole('button', { name: 'Buscar' }).click()
  await page.locator('.sources .list li button:not([disabled])', { hasText: 'Capturar' }).first().click()
  await page.waitForTimeout(200)
}
await page.getByRole('button', { name: 'Guardar selección' }).click()
await page.locator('.sources ol li').first().waitFor()
step(`selection: ${await page.locator('.sources ol li').count()} sources`)
await page.getByLabel('Tarea').selectOption(preset)
await page.getByLabel('Modelo').selectOption(profile)
await page.getByRole('button', { name: 'Preparar' }).click()
await page.getByText('Hash verificado en el navegador').waitFor()
step('inspector: hash verified client-side')
await page.getByRole('button', { name: 'Enviar' }).click()
const final = page.locator('.runs li', { hasText: /Completada|Fallida|Cancelada|Interrumpida/ }).first()
await final.waitFor({ timeout: 300_000 })
step(`run: ${await final.innerText()}`)
const answer = page.locator('.msg.assistant').last()
console.log('validation:', await answer.locator('header').innerText())
console.log('text:', (await answer.locator('.text').innerText()).slice(0, 300))
await answer.locator('summary', { hasText: 'Citas' }).click().catch(() => {})
for (const c of await answer.locator('details li').allInnerTexts()) console.log('cite:', c.slice(0, 140))
console.log('export link:', await page.locator('.runs a').count())
await page.screenshot({ path: process.env.SHOT ?? 'e2e-shot.png', fullPage: true })
console.log('console errors:', cspErrors.length ? cspErrors : 'none')
await browser.close()
