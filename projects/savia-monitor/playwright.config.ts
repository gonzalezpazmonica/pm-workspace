import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  outputDir: './output/e2e-results/savia-monitor',
  timeout: 15000,
  use: {
    baseURL: 'http://localhost:1420',
    screenshot: 'only-on-failure',
    locale: 'es-ES',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
})
