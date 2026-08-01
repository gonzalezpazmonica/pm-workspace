// CLI index.test.ts — SE-290 path/schema tests
import { describe, it, expect } from 'vitest';
import type { VaultConfig } from '../types.js';

function makeConfig(name: string, vaultPath: string, schemaDir?: string): VaultConfig {
  const config: VaultConfig = { name, path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024 };
  if (schemaDir) config.schemaDir = schemaDir;
  return config;
}

describe('CLI (SE-290)', () => {
  it('path is configurable', () => {
    expect(makeConfig('vault', 'vaults/SaviaLabs').path).toBe('vaults/SaviaLabs');
  });
  it('schemaDir is optional', () => {
    expect(makeConfig('vault', '/tmp').schemaDir).toBeUndefined();
  });
  it('schemaDir is wired when provided', () => {
    expect(makeConfig('vault', '/tmp', 'schema/').schemaDir).toBe('schema/');
  });
  it('defaults preserved', () => {
    const c = makeConfig('v', '/t');
    expect(c.maxDepth).toBe(10);
    expect(c.maxFileSize).toBe(10 * 1024 * 1024);
  });
});
