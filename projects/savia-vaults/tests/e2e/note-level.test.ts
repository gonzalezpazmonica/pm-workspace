// SE-420 — e2e MCP stdio: una nota N4 en una cúpula N2 no sale por vault_read, vault_list,
// vault_search, vault_tags, backlinks ni vault_rag; vault_write la rechaza; vault_stats la cuenta.
import { afterEach, describe, expect, it } from 'vitest';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

const folders: string[] = [];
afterEach(() => { for (const f of folders.splice(0)) fs.rmSync(f, { recursive: true, force: true }); });
const text = (r: any) => (r.content as { text: string }[])[0].text;
const SECRET = 'garceta-9083';

describe('SE-420 MCP nivel por nota', () => {
  it('la nota fuera de nivel no se sirve por ninguna herramienta y no se puede escribir', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-mcp-note-level-'));
    folders.push(root);
    const vault = path.join(root, 'D');
    fs.mkdirSync(vault);
    fs.writeFileSync(path.join(vault, 'reservada.md'), `---\nconfidentiality: N4\ntags: [etiqueta-oculta]\n---\n# Reservada\n\nTexto ${SECRET} que enlaza [[publica]].\n`);
    fs.writeFileSync(path.join(vault, 'publica.md'), '---\ntags: [comun]\n---\n# Publica\n\nNota abierta.\n');
    const registry = path.join(root, 'domes.json');
    fs.writeFileSync(registry, JSON.stringify({ version: 1, defaultDome: 'D', domes: {
      D: { name: 'D', path: vault, description: '', confidentiality: 'N2', rag: { enabled: true } },
    } }));
    const transport = new StdioClientTransport({
      command: process.execPath,
      args: ['--import', pathToFileURL(path.resolve('node_modules/tsx/dist/loader.mjs')).href, path.resolve('src/cli/index.ts'), 'serve', '--transport', 'mcp', '--domes', registry],
      cwd: root,
      env: { PATH: process.env.PATH || '', HOME: root, SAVIA_RAG_HOME: path.join(root, 'rag'), SAVIA_RAG_TEST_PROVIDER: 'hash', SAVIA_SEARCH_CACHE: path.join(root, 'sc') },
    });
    const client = new Client({ name: 'note-level-e2e', version: '1' });
    await client.connect(transport);
    try {
      const call = (name: string, args: Record<string, unknown> = {}) => client.callTool({ name, arguments: args });
      const read = await call('vault_read', { path: 'reservada.md' });
      expect(read.isError).toBe(true);
      expect(text(read)).toMatch(/Note not found/);
      expect(JSON.parse(text(await call('vault_list')))).not.toContain('reservada.md');
      expect(text(await call('vault_search', { query: SECRET }))).not.toContain('reservada');
      expect(text(await call('vault_tags'))).not.toContain('etiqueta-oculta');
      const pub = JSON.parse(text(await call('vault_read', { path: 'publica.md' })));
      expect(JSON.stringify(pub)).not.toContain(SECRET); // backlinks sin contexto de la oculta
      const rag = JSON.parse(text(await call('vault_rag', { query: SECRET, mode: 'bm25', fields: 'full' })));
      expect(JSON.stringify(rag.results[0].hits)).not.toContain(SECRET); // la respuesta repite la consulta; los hits no
      expect(JSON.parse(text(await call('vault_stats')))).toMatchObject({ noteCount: 1, outOfLevel: 1 });
      const w = await call('vault_write', { path: 'nueva.md', content: `---\nconfidentiality: N3\n---\n${SECRET}\n` });
      expect(w.isError).toBe(true);
      expect(text(w)).toMatch(/POLICY_DENIED/);
      expect(fs.existsSync(path.join(vault, 'nueva.md'))).toBe(false);
    } finally {
      await client.close();
    }
  }, 60_000);
});
