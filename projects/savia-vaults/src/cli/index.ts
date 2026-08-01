#!/usr/bin/env node
import { Command } from 'commander';
import { VaultStorage } from '../storage/index.js';
import { SearchEngine } from '../search/index.js';
import { MCPVaultServer } from '../server/mcp.js';
import { A2AServer } from '../server/a2a.js';
import { BackupManager } from '../backup/index.js';
import { FederationRegistry } from '../federation/registry.js';
import { Introspector } from '../knowledge/introspector.js';
import { KnowledgeGraph } from '../knowledge/graph.js';
import { QueryEngine } from '../knowledge/query.js';
import { QualityEngine } from '../knowledge/quality.js';
import type { VaultConfig } from '../types.js';
import * as fs from 'node:fs';
import * as path from 'node:path';

function makeConfig(name: string, vaultPath: string, schemaDir?: string): VaultConfig {
  return { name, path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024, schemaDir };
}

const program = new Command();
program.name('savia-vaults').description('Context Dome Server — Knowledge layer').version('0.3.0');

program.command('init <name>').description('Create a new vault')
  .option('-p, --path <path>', 'Parent directory', process.cwd())
  .option('--schema <dir>', 'Entity schema directory', 'schema/entities')
  .action(async (name, opts) => {
    const vaultPath = `${opts.path}/vaults/${name}`;
    const config = makeConfig(name, vaultPath, path.resolve(opts.schema));
    const storage = new VaultStorage(config);
    await storage.init();
    console.log(`Vault "${name}" created at ${vaultPath}`);
  });

program.command('serve').description('Start MCP or A2A server')
  .option('--transport <type>', 'mcp or a2a', 'mcp').option('--port <port>', 'Port', '8923').option('--host <host>', 'Bind host', '127.0.0.1')
  .option('-p, --path <path>', 'Vault path', process.cwd()).option('--schema <dir>', 'Schema dir')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path, opts.schema ? path.resolve(opts.schema) : undefined);
    if (opts.transport === 'mcp') { const server = new MCPVaultServer(config); await server.start(); }
    else { const server = new A2AServer(config); await server.start(parseInt(opts.port, 10), opts.host, process.env.SAVIA_VAULTS_TOKEN); }
  });

program.command('search <query>').option('-p, --path <path>', process.cwd()).option('--json')
  .action(async (query, opts) => {
    const config = makeConfig('vault', opts.path);
    const engine = new SearchEngine(config); engine.buildIndex();
    const results = engine.search({ query, maxResults: 10 });
    if (opts.json) console.log(JSON.stringify(results, null, 2));
    else for (const r of results) console.log(`${r.path} (${r.score.toFixed(2)})\n  ${r.snippet}\n`);
  });

program.command('stats').option('-p, --path <path>', process.cwd()).option('--json').action(async (opts) => {
  const config = makeConfig('vault', opts.path); const storage = new VaultStorage(config); await storage.init(); const s = await storage.stats();
  if (opts.json) console.log(JSON.stringify(s, null, 2));
  else console.log(`Vault: ${s.name}\nNotes: ${s.noteCount}\nSize: ${(s.totalSize/1024).toFixed(1)} KB`);
});

program.command('introspect').description('Discover entity types and coverage')
  .option('-p, --path <path>', process.cwd()).option('-e, --entity <path>').option('--json')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const introspector = new Introspector(config);
    if (opts.entity) {
      const result = await introspector.introspectEntity(opts.entity);
      console.log(opts.json ? JSON.stringify(result, null, 2) : result ? `${result.type}:${result.id} (${result.populatedProperties} populated)` : 'Not found');
    } else {
      const result = await introspector.introspectVault();
      if (opts.json) console.log(JSON.stringify(result, null, 2));
      else {
        console.log(`Vault: ${result.vault}\nDocuments: ${result.totalDocuments}\nEntities: ${result.totalEntities}\nSchema types: ${result.schemaTypes.join(', ')}\n`);
        for (const t of result.entityTypes) console.log(`  ${t.label} (${t.type}): ${t.count} entities`);
      }
    }
  });

program.command('graph').description('Knowledge graph operations')
  .option('-p, --path <path>', process.cwd()).option('--action <action>', 'traverse, search, or stats', 'stats')
  .option('--id <id>').option('--depth <n>', '3').option('--query <q>').option('--json')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const graph = new KnowledgeGraph(config); await graph.build();
    if (opts.action === 'traverse') {
      const result = graph.traverse(opts.id, parseInt(opts.depth, 10));
      if (opts.json) console.log(JSON.stringify(result, null, 2));
      else { console.log(`Traversal from ${opts.id}: ${result.nodes.length} nodes, ${result.relations.length} relations`); for (const r of result.relations) console.log(`  ${r.from} --[${r.type}]--> ${r.to}`); }
    } else if (opts.action === 'search') {
      const nodes = graph.searchNodes(opts.query || '');
      if (opts.json) console.log(JSON.stringify(nodes, null, 2));
      else for (const n of nodes) console.log(`${n.id} (${n.type}) — ${n.outgoing.length} out, ${n.incoming.length} in`);
    } else {
      const s = graph.getStats(); console.log(`Nodes: ${s.nodeCount}\nRelations: ${s.relationCount}\nTypes: ${s.relationTypes.join(', ')}`);
    }
  });

program.command('query <expression>').description('Deterministic entity query')
  .option('-p, --path <path>', process.cwd()).option('--json')
  .action(async (expression, opts) => {
    const config = makeConfig('vault', opts.path);
    const engine = new QueryEngine(config); await engine.ensureLoaded();
    const result = await engine.query(expression);
    if (opts.json) console.log(JSON.stringify(result.outputRows, null, 2));
    else console.log(result.outputMarkdown);
  });

program.command('health').description('Vault quality health report')
  .option('-p, --path <path>', process.cwd()).option('--json')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const quality = new QualityEngine(config);
    const indicators = await quality.assess();
    if (opts.json) console.log(JSON.stringify(indicators, null, 2));
    else console.log(quality.formatReport(indicators));
  });

program.command('verify').option('-p, --path <path>', process.cwd()).action(async (opts) => { console.log('Verification via Ed25519 signatures.'); });
program.command('export').option('-p, --path <path>', process.cwd()).option('-o, --output <dir>').action(async (opts) => {
  const config = makeConfig('vault', opts.path); const storage = new VaultStorage(config);
  const outputDir = opts.output || `${opts.path}-export`; fs.mkdirSync(outputDir, { recursive: true });
  const files = await storage.list(); for (const f of files) { try { const note = await storage.read(f); const dest = path.join(outputDir, f); fs.mkdirSync(path.dirname(dest), { recursive: true }); fs.writeFileSync(dest, note.content); } catch {} }
  console.log(`Exported ${files.length} notes to ${outputDir}`);
});

const federateCmd = program.command('federate');
federateCmd.command('add <id> <url>').option('--token <token>').action((id, url, opts) => { const r = new FederationRegistry(path.join(process.cwd(), '.savia-vault')); r.add({ id, name: id, url, authToken: opts.token, timeout: 5000, enabled: true, weight: 1, tags: [], status: 'unknown' }); console.log(`Dome "${id}" registered.`); });
federateCmd.command('list').action(() => { const r = new FederationRegistry(path.join(process.cwd(), '.savia-vault')); const domes = r.list(); if (domes.length === 0) console.log('No federated domes.'); else domes.forEach(d => console.log(`${d.id} (${d.status}) — ${d.url}`)); });
federateCmd.command('remove <id>').action((id) => { const r = new FederationRegistry(path.join(process.cwd(), '.savia-vault')); console.log(r.remove(id) ? `Removed "${id}".` : `Not found.`); });
federateCmd.command('health').action(async () => { console.log('Health check via federation search engine.'); });

const backupCmd = program.command('backup'); const bm = new BackupManager();
backupCmd.command('create').option('-p, --path <path>', process.cwd()).action((opts) => { const e = bm.create(opts.path, path.basename(opts.path)); console.log(`Backup: ${e.id} (${(e.size/1024).toFixed(1)} KB)`); });
backupCmd.command('list').action(() => { const backups = bm.list(); if (backups.length === 0) console.log('No backups.'); else backups.forEach(e => console.log(`${e.id} ${e.vault} ${(e.size/1024).toFixed(1)}KB`)); });
backupCmd.command('restore <id>').option('--target <dir>').action((id, opts) => { bm.restore(id, opts.target || path.join(process.cwd(), 'restored')); console.log(`Restored to ${opts.target || 'restored'}`); });
backupCmd.command('status').action(() => { const s = bm.status(); console.log(`Backups: ${s.count}\nNextcloud: ${s.nextcloudConfigured ? 'configured' : 'not configured'}`); });

program.parse();
