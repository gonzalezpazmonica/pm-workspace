// SE-410 — e2e MCP por stdio: vault_rag, vault_rag_status, vault_rag_sync con ACL
import { afterEach, describe, expect, it } from 'vitest';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { UserStore } from '../../src/auth/store.js';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

const folders: string[] = [];
afterEach(() => { for (const f of folders.splice(0)) fs.rmSync(f, { recursive: true, force: true }); });

const long = (s: string) => `${s}. `.repeat(12);
const text = (r: any) => (r.content as { text: string }[])[0].text;

async function start(withAuth: boolean) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-mcp-rag-'));
  folders.push(root);
  const domes: Record<string, unknown> = {};
  const content: Record<string, Record<string, string>> = {
    docs: { 'rules/merge.md': `# Merge\n\n${long('nunca merge sin permiso expreso de la operadora')}` },
    learn: { 'l/leccion.md': `# Lección\n\n${long('merge sin permiso rompe la confianza del equipo')}` },
    secret: { 's.md': `# Secreto\n\n${long('merge secreto del cliente')}` },
  };
  for (const [name, files] of Object.entries(content)) {
    const folder = path.join(root, name);
    for (const [p, c] of Object.entries(files)) {
      fs.mkdirSync(path.dirname(path.join(folder, p)), { recursive: true });
      fs.writeFileSync(path.join(folder, p), c);
    }
    domes[name] = { name, path: folder, description: '', confidentiality: name === 'secret' ? 'N4' : 'N2', rag: { enabled: true } };
  }
  const registry = path.join(root, 'domes.json');
  fs.writeFileSync(registry, JSON.stringify({ version: 1, defaultDome: 'docs', domes }));
  const env: Record<string, string> = {
    PATH: process.env.PATH || '', SAVIA_RAG_HOME: path.join(root, 'rag-home'), SAVIA_RAG_TEST_PROVIDER: 'hash',
  };
  if (withAuth) {
    const users = new UserStore(path.join(root, 'savia-vaults.users.json'));
    env.SAVIA_AUTH_TOKEN = users.createUser('reader-docs');
    users.setPermission('reader-docs', 'docs', 'reader');
    users.save();
  }
  const loader = pathToFileURL(path.resolve('node_modules/tsx/dist/loader.mjs')).href;
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: ['--import', loader, path.resolve('src/cli/index.ts'), 'serve', '--transport', 'mcp', '--domes', registry],
    cwd: root, env,
  });
  const client = new Client({ name: 'rag-e2e', version: '1' });
  await client.connect(transport);
  return { client, root };
}

describe('SE-410 MCP RAG', () => {
  it('expone las tres tools y busca en paralelo en varias cúpulas', async () => {
    const { client } = await start(false);
    try {
      const tools = (await client.listTools()).tools.map(t => t.name);
      expect(tools).toEqual(expect.arrayContaining(['vault_rag', 'vault_rag_status', 'vault_rag_sync']));

      const sync = await client.callTool({ name: 'vault_rag_sync', arguments: { dome: 'docs' } });
      expect(sync.isError).not.toBe(true);
      expect(JSON.parse(text(sync)).promoted).toBe(true);

      const res = await client.callTool({ name: 'vault_rag', arguments: { queries: ['merge sin permiso', 'confianza equipo'], domes: '*' } });
      expect(res.isError).not.toBe(true);
      const body = JSON.parse(text(res));
      expect(body.domes.map((d: any) => d.name).sort()).toEqual(['docs', 'learn']);
      expect(body.results).toHaveLength(2);
      expect(body.merged.length).toBeGreaterThan(0);
      expect(JSON.stringify(body)).not.toContain('secreto');

      const status = await client.callTool({ name: 'vault_rag_status', arguments: { domes: ['docs'] } });
      expect(JSON.parse(text(status))[0]).toMatchObject({ name: 'docs', pendingDocs: 0 });

      const bad = await client.callTool({ name: 'vault_rag', arguments: { queries: [] } });
      expect(bad.isError).toBe(true);
      expect(text(bad)).toContain('INVALID_INPUT');
    } finally {
      await client.close();
    }
  }, 30000);

  it('con auth: cúpula sin permiso figura denied y sync exige write', async () => {
    const { client } = await start(true);
    try {
      const res = await client.callTool({ name: 'vault_rag', arguments: { query: 'merge sin permiso', domes: ['docs', 'learn'] } });
      const body = JSON.parse(text(res));
      expect(body.domes.find((d: any) => d.name === 'learn').status).toBe('denied');
      expect(body.results[0].hits.every((h: any) => h.dome === 'docs')).toBe(true);
      expect(body.results[0].hits.length).toBeGreaterThan(0);

      const sync = await client.callTool({ name: 'vault_rag_sync', arguments: { dome: 'docs' } });
      expect(sync.isError).toBe(true);
    } finally {
      await client.close();
    }
  }, 30000);

  it('vault_write programa sync con debounce (disparador de escritura)', async () => {
    const { client } = await start(false);
    try {
      await client.callTool({ name: 'vault_rag_sync', arguments: { dome: 'docs' } });
      await client.callTool({ name: 'vault_write', arguments: { vault: 'docs', path: 'rules/nueva.md', content: `# Nueva\n\n${long('regla nueva sobre despliegues nocturnos')}`, message: 'test' } });
      await new Promise(r => setTimeout(r, 3500));
      const status = await client.callTool({ name: 'vault_rag_status', arguments: { domes: ['docs'] } });
      expect(JSON.parse(text(status))[0].pendingDocs).toBe(0);
    } finally {
      await client.close();
    }
  }, 30000);
});
