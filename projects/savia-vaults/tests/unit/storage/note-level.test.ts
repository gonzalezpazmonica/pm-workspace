// SE-420 — una nota con `confidentiality` mayor que su cúpula no se sirve por ninguna vista
// (almacén, búsqueda, etiquetas, grafo, A2A); `write` la rechaza; sin nivel en la
// configuración (CLI local) todo sigue igual.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { VaultStorage } from '../../../src/storage/index.js';
import { SearchEngine } from '../../../src/search/index.js';
import { KnowledgeGraph } from '../../../src/knowledge/graph.js';
import { DomeRegistry, VaultInstance } from '../../../src/registry/domes.js';
import { A2AServer } from '../../../src/server/a2a.js';
import type { VaultConfig } from '../../../src/types.js';

const SECRET = 'garza-4471';
const hidden = `---\ntitle: Nota reservada\nconfidentiality: N4\ntags: [etiqueta-oculta]\n---\n# Reservada\n\nTexto ${SECRET} con [[publica]].\n`;
const visible = `---\ntitle: Pública\nconfidentiality: n2\ntags: [comun]\n---\n# Pública\n\nTexto normal que enlaza [[reservada]].\n`;

describe('SE-420 nivel por nota', () => {
  let root: string;
  let vault: string;
  let cfg: VaultConfig;
  let cache: string;

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-note-level-'));
    vault = path.join(root, 'D');
    fs.mkdirSync(vault);
    fs.writeFileSync(path.join(vault, 'reservada.md'), hidden);
    fs.writeFileSync(path.join(vault, 'publica.md'), visible);
    fs.writeFileSync(path.join(vault, 'sin-nivel.md'), '# Sin nivel\n\nnota corriente\n');
    cache = path.join(root, 'cache');
    process.env.SAVIA_SEARCH_CACHE = cache;
    cfg = { name: 'D', path: vault, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 1 << 20, confidentiality: 'N2' };
  });
  afterEach(() => { delete process.env.SAVIA_SEARCH_CACHE; fs.rmSync(root, { recursive: true, force: true }); });

  it('AC1: list/read/diff/log no la muestran; stats la cuenta aparte', async () => {
    const st = new VaultStorage(cfg);
    expect((await st.list()).sort()).toEqual(['publica.md', 'sin-nivel.md']);
    await expect(st.read('reservada.md')).rejects.toThrow(/Note not found/);
    await expect(st.diff('reservada.md')).rejects.toThrow(/Note not found/);
    await expect(st.log('reservada.md')).rejects.toThrow(/Note not found/);
    expect((await st.read('publica.md')).content).toContain('Texto normal');
    expect(await st.stats()).toMatchObject({ noteCount: 2, outOfLevel: 1 });
  });

  it('AC1: búsqueda, etiquetas y grafo no la incluyen', async () => {
    const se = new SearchEngine(cfg);
    se.buildIndex();
    expect(se.search({ query: SECRET })).toEqual([]);
    expect(se.search({ query: 'reservada' }).map((r) => r.path)).not.toContain('reservada.md');
    expect([...se.getTags().keys()]).not.toContain('etiqueta-oculta');
    const g = new KnowledgeGraph(cfg);
    const snap = await g.build();
    expect(JSON.stringify([...snap.nodes.values()].map((n) => n.path))).not.toContain('reservada.md');
  });

  it('AC3: write rechaza un nivel mayor que la cúpula y no sobrescribe una nota fuera de nivel', async () => {
    const st = new VaultStorage(cfg);
    await expect(st.write('nueva.md', hidden)).rejects.toThrow(/POLICY_DENIED/);
    expect(fs.existsSync(path.join(vault, 'nueva.md'))).toBe(false);
    await expect(st.write('reservada.md', '# pisada\n')).rejects.toThrow(/POLICY_DENIED/);
    expect(fs.readFileSync(path.join(vault, 'reservada.md'), 'utf-8')).toBe(hidden);
    await st.write('ok.md', '---\nconfidentiality: N2\n---\nbien\n');
    await st.write('ok2.md', 'sin frontmatter\n');
    expect((await st.list())).toEqual(expect.arrayContaining(['ok.md', 'ok2.md']));
  });

  it('AC5: sin nivel en la configuración (CLI local) todo sigue igual', async () => {
    const { confidentiality: _c, ...local } = cfg;
    const st = new VaultStorage(local);
    expect((await st.list()).sort()).toEqual(['publica.md', 'reservada.md', 'sin-nivel.md']);
    expect((await st.read('reservada.md')).content).toContain(SECRET);
    const se = new SearchEngine(local);
    se.buildIndex();
    expect(se.search({ query: SECRET }).map((r) => r.path)).toEqual(['reservada.md']);
  });

  it('AC6: reclasificar la cúpula a la baja invalida la caché de búsqueda', () => {
    const high = new SearchEngine({ ...cfg, confidentiality: 'N4' });
    high.buildIndex();
    expect(high.search({ query: SECRET }).map((r) => r.path)).toEqual(['reservada.md']);
    const low = new SearchEngine(cfg); // mismo vault y misma caché en disco, nivel N2
    low.buildIndex();
    expect(low.search({ query: SECRET })).toEqual([]);
  });

  it('una nota que pasa a estar fuera de nivel deja de servirse (caché por mtime)', async () => {
    const st = new VaultStorage(cfg);
    expect((await st.read('publica.md')).name).toBe('publica');
    const later = new Date(Date.now() + 2000);
    fs.writeFileSync(path.join(vault, 'publica.md'), visible.replace('confidentiality: n2', 'confidentiality: N3'));
    fs.utimesSync(path.join(vault, 'publica.md'), later, later);
    await expect(st.read('publica.md')).rejects.toThrow(/Note not found/);
  });

  it('AC1/AC2: la instancia de cúpula y A2A reciben el nivel del registro', async () => {
    const registry = path.join(root, 'domes.json');
    fs.writeFileSync(registry, JSON.stringify({ version: 1, defaultDome: 'D', domes: { D: { name: 'D', path: vault, description: '', confidentiality: 'N2' } } }));
    const reg = new DomeRegistry(registry);
    reg.load();
    const inst = new VaultInstance(reg.get('D')!);
    expect(inst.config.confidentiality).toBe('N2');
    await expect(inst.storage.read('reservada.md')).rejects.toThrow(/Note not found/);
    const a2a = new A2AServer({ ...cfg, name: 'solo', path: path.join(root, 'single') }, reg);
    await expect(a2a.readDome('D', 'reservada.md')).rejects.toThrow(/Note not found/);
    expect(a2a.searchAll({ query: SECRET }, 'D')).toEqual([]);
    expect(a2a.searchAll({ query: 'normal' }, 'D').map((r) => r.path)).toEqual(['publica.md']);
  });
});
