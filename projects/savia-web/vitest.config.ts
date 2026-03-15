import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  define: {
    __APP_VERSION__: JSON.stringify('0.1.0-test'),
  },
  test: {
    environment: 'happy-dom',
    globals: true,
    setupFiles: ['src/__tests__/setup.ts'],
    exclude: ['node_modules/**', 'dist/**', 'e2e/**'],
    coverage: {
      provider: 'v8',
      thresholds: {
        lines: 80,
        functions: 70,
        branches: 70,
        statements: 80,
      },
      exclude: [
        'node_modules/**',
        'dist/**',
        'src/main.ts',
        'src/router/**',
        'src/styles/**',
        'src/types/**',
        'src/components/charts/**',
        'src/App.vue',
        'vite-env.d.ts',
        'vitest.config.ts',
        'vite.config.ts',
      ],
    },
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
})
