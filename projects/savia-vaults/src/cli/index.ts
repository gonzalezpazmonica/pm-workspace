#!/usr/bin/env node
import { getAINotice } from '../compliance/transparency.js';
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

function makeConfig(name: string, vaultPath: string): VaultConfig {
  return { name, path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024 };
}

const program = new Command();
program.name('savia-vaults').description('Context Dome Server — MCP + A2A server for AI agent knowledge vaults').version('0.2.0');

program.command('init <name>').description('Create a new vault')
  .option('-p, --path <path>', 'Parent directory', process.cwd())
  .action(async (name, opts) => {
    const vaultPath = `${opts.path}/vaults/${name}`;
    const config = makeConfig(name, vaultPath);
    const storage = new VaultStorage(config);
    await storage.init();
    console.log(`Vault "${name}" created at ${vaultPath}`);
    console.log(`Next: savia-vaults serve --transport mcp --path ${vaultPath}`);
  });

program.command('serve').description('Start MCP or A2A server')
  .option('--transport <type>', 'mcp or a2a', 'mcp')
  .option('--port <port>', 'Port for A2A', '8923')
  .option('--host <host>', 'Bind host', '127.0.0.1')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const authToken = process.env.SAVIA_VAULTS_TOKEN;
    if (opts.transport === 'mcp') {
      const server = new MCPVaultServer(config);
      await server.start();
    } else if (opts.transport === 'a2a') {
      const server = new A2AServer(config);
      await server.start(parseInt(opts.port, 10), opts.host, authToken);
    }
  });

program.command('search <query>').description('Search the vault')
  .option('-p, --path <path>', 'Vault path', process.cwd()).option('--json', 'JSON output', false)
  .action(async (query, opts) => {
    const config = makeConfig('vault', opts.path);
    const engine = new SearchEngine(config);
    engine.buildIndex();
    const results = engine.search({ query, maxResults: 10 });
    if (opts.json) { console.log(JSON.stringify(results, null, 2)); }
    else { for (const r of results) { console.log(`${r.path} (score: ${r.score.toFixed(2)})`); console.log(`  ${r.snippet}\n`); } }
  });

program.command('stats').description('Show vault statistics')
  .option('-p, --path <path>', 'Vault path', process.cwd()).option('--json', 'JSON output', false)
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const storage = new VaultStorage(config); await storage.init();
    const stats = await storage.stats();
    if (opts.json) { console.log(JSON.stringify(stats, null, 2)); }
    else { console.log(`Vault: ${stats.name}\nNotes: ${stats.noteCount}\nSize:  ${(stats.totalSize / 1024).toFixed(1)} KB`); if (stats.commitCount) console.log(`Commits: ${stats.commitCount}`); }
  });

program.command('introspect').description('Discover entity types and coverage')
  .option('-p, --path <path>', process.cwd()).option('-e, --entity <path>').option('--json')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const introspector = new Introspector(config);
    if (opts.entity) {
      const result = await introspector.introspectEntity(opts.entity);
      console.log(opts.json ? JSON.stringify(result, null, 2) : result ? `${result.type}:${result.id}` : 'Not found');
    } else {
      const result = await introspector.introspectVault();
      if (opts.json) console.log(JSON.stringify(result, null, 2));
      else { console.log(`Documents: ${result.totalDocuments}\nEntities: ${result.totalEntities}`); for (const t of result.entityTypes) console.log(`  ${t.label}: ${t.count}`); }
    }
  });

program.command('graph').description('Knowledge graph operations')
  .option('-p, --path <path>', process.cwd()).option('--action <action>', 'stats')
  .option('--id <id>').option('--depth <n>', '3').option('--query <q>').option('--json')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const graph = new KnowledgeGraph(config); await graph.build();
    if (opts.action === 'traverse') {
      const result = graph.traverse(opts.id, parseInt(opts.depth, 10));
      if (opts.json) console.log(JSON.stringify(result, null, 2));
      else { console.log(`${result.nodes.length} nodes, ${result.relations.length} relations`); for (const r of result.relations) console.log(`  ${r.from} --[${r.type}]--> ${r.to}`); }
    } else if (opts.action === 'search') {
      const nodes = graph.searchNodes(opts.query || '');
      for (const n of nodes) console.log(`${n.id} (${n.type}) — ${n.outgoing.length} out, ${n.incoming.length} in`);
    } else { const s = graph.getStats(); console.log(`Nodes: ${s.nodeCount}\nRelations: ${s.relationCount}`); }
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

program.command('health-report').description('Vault quality health report')
  .option('-p, --path <path>', process.cwd()).option('--json')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const quality = new QualityEngine(config);
    const indicators = await quality.assess();
    if (opts.json) console.log(JSON.stringify(indicators, null, 2));
    else console.log(quality.formatReport(indicators));
  });

program.command('verify')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const storage = new VaultStorage(config); await storage.init();
    const files = await storage.list();
    let ok = 0, fail = 0;
    for (const f of files) {
      try {
        const note = await storage.read(f);
        const content = fs.readFileSync(path.join(opts.path, f), 'utf-8');
        const { verifySignature } = await import('../security/index.js');
        if (verifySignature(content, note.frontmatter._signature as string || '')) ok++; else { fail++; console.log(`  FAIL: ${f}`); }
      } catch { fail++; }
    }
    console.log(`Verified ${files.length} notes: ${ok} OK, ${fail} FAIL`);
  });

program.command('export').description('Export vault to portable format')
  .option('-p, --path <path>', 'Vault path', process.cwd()).option('-o, --output <dir>', 'Output directory')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const storage = new VaultStorage(config);
    const outputDir = opts.output || `${opts.path}-export`;
    fs.mkdirSync(outputDir, { recursive: true });
    const files = await storage.list();
    for (const f of files) {
      try { const note = await storage.read(f); const dest = path.join(outputDir, f); fs.mkdirSync(path.dirname(dest), { recursive: true }); fs.writeFileSync(dest, note.content); }
      catch (e) { console.error(`Failed to export ${f}: ${e instanceof Error ? e.message : e}`); }
    }
    console.log(`Exported ${files.length} notes to ${outputDir}`);
  });

// Federate commands
const federateCmd = program.command('federate').description('Manage federated domes');
federateCmd.command('add <id> <url>').description('Register a remote dome')
  .option('--token <token>', 'Auth token').option('--weight <n>', 'Weight', '1.0').option('--tags <tags>', 'Comma-separated tags', '')
  .action((id, url, opts) => {
    const registry = new FederationRegistry(path.join(process.cwd(), '.savia-vault'));
    registry.add({ id, name: id, url, authToken: opts.token, timeout: 5000, enabled: true, weight: parseFloat(opts.weight), tags: opts.tags ? opts.tags.split(',') : [], status: 'unknown' });
    console.log(`Dome "${id}" registered at ${url}`);
  });
federateCmd.command('list').description('List federated domes').action(() => {
  const registry = new FederationRegistry(path.join(process.cwd(), '.savia-vault'));
  const domes = registry.list();
  domes.length ? domes.forEach(d => console.log(`${d.id} (${d.status}) — ${d.url}`)) : console.log('No federated domes.');
});
federateCmd.command('remove <id>').description('Remove a dome').action((id) => {
  const registry = new FederationRegistry(path.join(process.cwd(), '.savia-vault'));
  console.log(registry.remove(id) ? `Removed "${id}".` : `Dome "${id}" not found.`);
});
federateCmd.command('health').description('Check health of all domes').action(async () => {
  const { FederatedSearchEngine } = await import('../federation/search.js');
  const { SearchEngine: SE } = await import('../search/index.js');
  const config = makeConfig('vault', process.cwd());
  const local = new SE(config);
  local.buildIndex();
  const registry = new FederationRegistry(path.join(process.cwd(), '.savia-vault'));
  const engine = new FederatedSearchEngine(local, registry);
  const results = await engine.healthCheckAll();
  results.forEach(r => console.log(`${r.id}: ${r.healthy ? 'healthy' : 'unhealthy'} (${r.latencyMs}ms)`));
});

// Backup commands
const backupCmd = program.command('backup').description('Manage vault backups');
const bm = new BackupManager();
backupCmd.command('create').description('Create a backup').option('-p, --path <path>', 'Vault path', process.cwd())
  .action((opts) => {
    const entry = bm.create(opts.path, path.basename(opts.path));
    console.log(`Backup created: ${entry.id}`);
    console.log(`  Size: ${(entry.size / 1024).toFixed(1)} KB`);
    console.log(`  File: ${entry.file}`);
  });
backupCmd.command('list').description('List backups').action(() => {
  const entries = bm.list();
  entries.length ? entries.forEach(e => console.log(`${e.id}  ${e.vault}  ${(e.size / 1024).toFixed(1)} KB  ${e.timestamp}`)) : console.log('No backups found.');
});
backupCmd.command('restore <id>').description('Restore a backup').option('--target <dir>', 'Target directory')
  .action((id, opts) => {
    const target = opts.target || path.join(process.cwd(), 'restored');
    bm.restore(id, target);
    console.log(`Restored ${id} to ${target}`);
  });
backupCmd.command('status').description('Backup system status').action(() => {
  const s = bm.status();
  console.log(`Backups: ${s.count} in ${s.backupsDir}`);
  console.log(`Nextcloud: ${s.nextcloudConfigured ? 'configured' : 'not configured'}`);
});

program.parse();
