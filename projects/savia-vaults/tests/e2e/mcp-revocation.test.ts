// SE-424 H3 — un proceso MCP ya abierto aplica en la siguiente llamada los cambios del fichero de
// usuarios: revocar, conceder, regenerar el token o borrar el fichero (que no vuelve al modo local).
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { UserStore } from '../../src/auth/store.js';

const cli = path.resolve('node_modules/tsx/dist/cli.mjs');
const source = path.resolve('src/cli/index.ts');

describe('SE-424 H3: revocación en caliente en MCP (stdio real)', () => {
  let tmp: string;
  let client: Client;
  let usersFile: string;
  let token: string;

  const call = async (name: string, args: Record<string, unknown>) => {
    const r = await client.callTool({ name, arguments: args });
    const text = (r.content as { text: string }[])[0]?.text ?? '';
    return r.isError ? `DENEGADO ${text}` : 'PERMITIDO';
  };
  const edit = (fn: (s: UserStore) => void) => {
    const s = new UserStore(usersFile);
    s.load();
    fn(s);
    s.save();
  };

  beforeEach(async () => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-mcp-revoke-'));
    fs.mkdirSync(path.join(tmp, 'P'));
    fs.writeFileSync(path.join(tmp, 'P', 'nota.md'), '# Nota\npalabra-clave\n');
    fs.writeFileSync(path.join(tmp, 'domes.json'), JSON.stringify({ version: 1, defaultDome: 'P', domes: {
      P: { name: 'P', path: path.join(tmp, 'P'), description: '', confidentiality: 'N2' },
    } }));
    usersFile = path.join(tmp, 'savia-vaults.users.json');
    const s = new UserStore(usersFile);
    token = s.createUser('ana');
    s.setPermission('ana', 'P', 'reader');
    s.save();
    const transport = new StdioClientTransport({
      command: process.execPath,
      args: [cli, source, 'serve', '--transport', 'mcp', '--domes', path.join(tmp, 'domes.json')],
      cwd: tmp,
      env: { ...process.env, HOME: tmp, SAVIA_AUTH_TOKEN: token } as Record<string, string>,
      stderr: 'ignore',
    });
    client = new Client({ name: 'se424-h3', version: '1.0.0' });
    await client.connect(transport);
  }, 30_000);

  afterEach(async () => {
    await client.close();
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('AC3: revoke, grant, regenerar token y borrar el fichero se aplican sin reiniciar', async () => {
    expect(await call('vault_list', { vault: 'P' })).toBe('PERMITIDO');

    edit((s) => s.removePermission('ana', 'P'));
    expect(await call('vault_list', { vault: 'P' })).toMatch(/^DENEGADO/);
    expect(await call('vault_search', { query: 'palabra-clave', vault: 'P' })).toMatch(/^DENEGADO/);

    edit((s) => s.setPermission('ana', 'P', 'reader'));
    expect(await call('vault_list', { vault: 'P' })).toBe('PERMITIDO');

    edit((s) => { s.regenerateToken('ana'); });
    expect(await call('vault_list', { vault: 'P' })).toMatch(/^DENEGADO .*Invalid or expired token/);

    // Sin fichero de usuarios, un servidor que arrancó con usuarios no pasa a modo local (todo permitido).
    fs.renameSync(usersFile, `${usersFile}.fuera`);
    expect(await call('vault_list', { vault: 'P' })).toMatch(/^DENEGADO/);
  }, 60_000);
});
