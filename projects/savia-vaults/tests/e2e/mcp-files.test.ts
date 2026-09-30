// SE-413 — e2e MCP por stdio: vault_files (put/list/get/text/download/delete) + vault_rag con ACL
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

const text = (r: any) => (r.content as { text: string }[])[0].text;
const b64 = (s: string) => Buffer.from(s).toString('base64');

async function start(withAuth: boolean) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-mcp-files-'));
  folders.push(root);
  const domes: Record<string, unknown> = {};
  for (const name of ['docs', 'other']) {
    const folder = path.join(root, name);
    fs.mkdirSync(folder);
    fs.writeFileSync(path.join(folder, 'n.md'), `# ${name}\n\nnota de ${name}\n`);
    domes[name] = { name, path: folder, description: '', confidentiality: 'N2', rag: { enabled: true }, files: { enabled: true, scan: 'off' } };
  }
  const registry = path.join(root, 'domes.json');
  fs.writeFileSync(registry, JSON.stringify({ version: 1, defaultDome: 'docs', domes }));
  const env: Record<string, string> = {
    PATH: process.env.PATH || '', SAVIA_RAG_HOME: path.join(root, 'rag-home'), SAVIA_RAG_TEST_PROVIDER: 'hash',
    SAVIA_FILES_HOME: path.join(root, 'files-home'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root,
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
  const client = new Client({ name: 'files-e2e', version: '1' });
  await client.connect(transport);
  return { client, root };
}

describe('SE-413 MCP vault_files', () => {
  it('ciclo completo: put → list → text → vault_rag cita el fichero → download → delete', async () => {
    const { client } = await start(false);
    try {
      expect((await client.listTools()).tools.map((t) => t.name)).toContain('vault_files');
      const call = (args: Record<string, unknown>) => client.callTool({ name: 'vault_files', arguments: { dome: 'docs', ...args } });

      const put = await call({ action: 'put', name: 'inventario.csv', contentBase64: b64('equipo,sala\nservidor ámbar,sala norte\n') });
      expect(put.isError).not.toBe(true);
      const doc = JSON.parse(text(put));
      expect(doc).toMatchObject({ name: 'inventario.csv', status: 'READY', extracted: 1 });

      const list = JSON.parse(text(await call({ action: 'list' })));
      expect(list.documents.map((d: any) => d.id)).toEqual([doc.documentId]);
      expect(list.corrupt).toBe(0);

      const t = JSON.parse(text(await call({ action: 'text', id: doc.documentId, locator: { type: 'row', row: 2 } })));
      expect(t.units[0].text).toBe('equipo: servidor ámbar | sala: sala norte');

      const rag = JSON.parse(text(await client.callTool({ name: 'vault_rag', arguments: { query: 'servidor ámbar sala norte', domes: ['docs'], mode: 'bm25' } })));
      const hit = rag.results[0].hits.find((h: any) => h.source);
      expect(hit.source).toMatchObject({ kind: 'file', documentId: doc.documentId, locator: { type: 'row', row: 2 } });

      const dl = JSON.parse(text(await call({ action: 'download', id: doc.documentId })));
      expect(Buffer.from(dl.contentBase64, 'base64').toString()).toBe('equipo,sala\nservidor ámbar,sala norte\n');
      expect(dl.sha256).toBe(doc.sha256);

      expect(JSON.parse(text(await call({ action: 'delete', id: doc.documentId })))).toMatchObject({
        deleted: doc.documentId, revisions: 1, receipt: { kind: 'delete', status: 'committed' },
      });
      const gone = await call({ action: 'get', id: doc.documentId });
      expect(gone.isError).toBe(true);
      expect(text(gone)).toContain('NOT_FOUND');

      const bad = await call({ action: 'put', name: '../x.txt', contentBase64: b64('x') });
      expect(bad.isError).toBe(true);
      expect(text(bad)).toContain('INVALID_INPUT');
      const unknown = await call({ action: 'explode' });
      expect(unknown.isError).toBe(true);
    } finally {
      await client.close();
    }
  }, 60000);

  it('AC6: con token de lectura sobre docs, put se rechaza y otra cúpula no devuelve datos', async () => {
    const { client } = await start(true);
    try {
      const put = await client.callTool({ name: 'vault_files', arguments: { action: 'put', dome: 'docs', name: 'a.txt', contentBase64: b64('x') } });
      expect(put.isError).toBe(true);
      const list = await client.callTool({ name: 'vault_files', arguments: { action: 'list', dome: 'docs' } });
      expect(list.isError).not.toBe(true);
      const other = await client.callTool({ name: 'vault_files', arguments: { action: 'list', dome: 'other' } });
      expect(other.isError).toBe(true);
      // SE-416 AC7: instalar software exige rol admin; consultar el estado no.
      const setup = await client.callTool({ name: 'vault_files', arguments: { action: 'setup', components: ['antivirus'] } });
      expect(setup.isError).toBe(true);
      const status = await client.callTool({ name: 'vault_files', arguments: { action: 'status' } });
      expect(status.isError).not.toBe(true);
      expect(JSON.parse(text(status)).summary.length).toBeGreaterThan(0);
    } finally {
      await client.close();
    }
  }, 60000);
});
