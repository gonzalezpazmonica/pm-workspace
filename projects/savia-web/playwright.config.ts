import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  timeout: 30000,
  retries: 1,
  use: {
    baseURL: 'https://localhost:5173',
    ignoreHTTPSErrors: true,
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'output/e2e-report' }]],
  outputDir: 'output/e2e-results',
})
