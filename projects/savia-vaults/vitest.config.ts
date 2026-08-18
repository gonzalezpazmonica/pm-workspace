import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      thresholds: {
        statements: 80,
        branches: 75,
        functions: 80,
        lines: 80,
      },
      include: ['src/**/*.ts'],
      exclude: ['src/cli/**'],
    },
    testTimeout: 10000,
    // Git-backed fixtures can exceed 5s on Windows under filesystem contention.
    hookTimeout: 30000,
  },
});
