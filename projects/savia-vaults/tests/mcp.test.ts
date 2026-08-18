import { describe, it, expect } from 'vitest';

describe('MCP server module loads', () => {
  // Dynamic ESM resolution can exceed the default timeout on WSL-mounted NTFS.
  it('exports MCPVaultServer class without syntax errors', async () => {
    const mod = await import('../src/server/mcp.js');
    expect(typeof mod.MCPVaultServer).toBe('function');
  }, 30_000);
});
