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
import { DomeRegistry } from '../registry/domes.js';
import { UserStore, ConfidentialityGuard, AuditLogger, UserQuotaStore } from '../auth/index.js';
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
  .option('-p, --path <path>', 'Vault path (legacy single-dome)', process.cwd())
  .option('--domes <file>', 'Domes registry file', 'savia-vaults.domes.json')
  .action(async (opts) => {
    const authToken = process.env.SAVIA_VAULTS_TOKEN;

    let domeReg: DomeRegistry | undefined;
    let userStore: UserStore | undefined;

    const domesFile = path.resolve(opts.domes);
    if (fs.existsSync(domesFile)) {
      domeReg = new DomeRegistry(domesFile);
      try {
        domeReg.load();
        console.error(`[serve] Multi-dome mode: ${domeReg.listActive().length} domes loaded from ${domesFile}`);
      } catch (e) {
        console.error(`[serve] WARNING: failed to load domes from ${domesFile}: ${e instanceof Error ? e.message : e}`);
        console.error('[serve] Falling back to single-dome legacy mode.');
        domeReg = undefined;
      }
    }

    if (!domeReg) {
      console.error(`[serve] Legacy single-dome mode: ${opts.path}`);
    }

    const config = makeConfig('vault', opts.path);

    if (domeReg) {
      const defaultDome = domeReg.listActive()[0];
      if (defaultDome?.schemaDir) {
        config.schemaDir = defaultDome.schemaDir;
        console.error(`[serve] Knowledge layer enabled: schemaDir=${config.schemaDir}`);
      }

      const usersFile = 'savia-vaults.users.json';
      if (fs.existsSync(usersFile)) {
        userStore = new UserStore(usersFile);
        try { userStore.load(); console.error('[serve] Auth enabled: users loaded'); } catch {}
      }
    }

    if (opts.transport === 'mcp') {
      const server = new MCPVaultServer(config, domeReg, userStore);
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

// OKF interop commands (SE-307)
program.command('okf-conformance').description('Check vault conformance with Open Knowledge Format v0.1')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const storage = new VaultStorage(config);
    const { checkOkfConformance } = await import('../knowledge/okf-conformance.js');
    const report = await checkOkfConformance(storage);
    console.log(`OKF Conformance: ${report.conformant ? 'CONFORMANT' : 'NON-CONFORMANT'} (${report.noteCount} notes)`);
    for (const v of report.violations) console.log(`  VIOLATION: ${v}`);
    for (const w of report.warnings) console.log(`  warning: ${w}`);
    if (!report.conformant) process.exit(1);
  });

program.command('okf-export').description('Export vault as OKF v0.1 bundle')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .option('-o, --output <dir>', 'Output directory')
  .option('--no-index', 'Skip index.md files')
  .option('--no-log', 'Skip log.md files')
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    const storage = new VaultStorage(config);
    const outputDir = opts.output || `${opts.path}-okf-export`;
    const { exportOkfBundle } = await import('../knowledge/okf-export.js');
    const result = await exportOkfBundle(storage, outputDir, {
      includeIndexFiles: opts.index !== false,
      includeLogFiles: opts.log !== false,
    });
    console.log(`Exported ${result.exported} notes to ${outputDir}`);
    for (const s of result.skipped) console.log(`  skipped: ${s}`);
  });

program.command('okf-import').description('Import an OKF v0.1 bundle into the vault')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .option('-s, --source <dir>', 'Source bundle directory', '')
  .option('--strip-prefix <prefix>', 'Strip path prefix from imported notes', '')
  .option('--force', 'Overwrite existing notes', false)
  .action(async (opts) => {
    if (!opts.source) { console.error('ERROR: --source is required'); process.exit(1); }
    const config = makeConfig('vault', opts.path);
    const storage = new VaultStorage(config);
    const { importOkfBundle } = await import('../knowledge/okf-import.js');
    const result = await importOkfBundle(storage, {
      sourceDir: opts.source,
      stripPrefix: opts.stripPrefix || undefined,
      force: opts.force,
    });
    console.log(`Imported ${result.imported} notes`);
    for (const r of result.rejected) console.log(`  rejected: ${r}`);
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

// ── User management commands (SE-291 S6) ──
const userCmd = program.command('user').description('Manage users and permissions');

userCmd.command('create <username>').description('Create a new user and generate token')
  .action((username) => {
    const store = new UserStore();
    try { store.load(); } catch {}
    try {
      const token = store.createUser(username);
      store.save();
      console.log('═'.repeat(70));
      console.log(`User "${username}" created.`);
      console.log(`Token:  ${token}`);
      console.log('═'.repeat(70));
      console.log('SAVE THIS TOKEN. It will not be shown again.');
      console.log('Configure it in your MCP client as SAVIA_AUTH_TOKEN.');
    } catch (e) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

userCmd.command('delete <username>').description('Delete a user')
  .action((username) => {
    const store = new UserStore();
    store.load();
    try {
      store.deleteUser(username);
      store.save();
      console.log(`User "${username}" deleted.`);
    } catch (e) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

userCmd.command('list').description('List all users')
  .option('--json', 'JSON output')
  .action((opts) => {
    const store = new UserStore();
    store.load();
    const users = store.listUsers();
    if (users.length === 0) { console.log('No users configured.'); return; }
    if (opts.json) {
      const safe = users.map(u => ({ username: u.username, createdAt: u.createdAt, domeCount: Object.keys(u.permissions).length }));
      console.log(JSON.stringify(safe, null, 2));
    } else {
      for (const u of users) {
        const domes = Object.keys(u.permissions).join(', ') || '(none)';
        console.log(`  ${u.username}  [${Object.keys(u.permissions).length} domes]  ${domes}`);
      }
    }
  });

userCmd.command('token <username>').description('Show or regenerate user token')
  .option('--regenerate', 'Generate new token (invalidates old)')
  .action((username, opts) => {
    const store = new UserStore();
    store.load();
    try {
      if (opts.regenerate) {
        const token = store.regenerateToken(username);
        store.save();
        console.log('═'.repeat(70));
        console.log(`New token for "${username}":`);
        console.log(`Token:  ${token}`);
        console.log('═'.repeat(70));
        console.log('Old token is now INVALID. Update your MCP client config.');
      } else {
        console.log(`Use --regenerate to generate a new token for "${username}".`);
        console.log('The current token cannot be displayed (only its hash is stored).');
      }
    } catch (e) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

userCmd.command('grant <username> <dome> <role>').description('Grant role to user on a dome')
  .action((username, dome, role) => {
    if (!['admin', 'writer', 'reader'].includes(role)) {
      console.error('Role must be admin, writer, or reader.');
      process.exit(1);
    }
    const store = new UserStore();
    store.load();
    try {
      store.setPermission(username, dome, role as 'admin' | 'writer' | 'reader');
      store.save();
      console.log(`Granted ${role} on "${dome}" to ${username}.`);
    } catch (e) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

userCmd.command('revoke <username> <dome>').description('Revoke user access to a dome')
  .action((username, dome) => {
    const store = new UserStore();
    store.load();
    try {
      store.removePermission(username, dome);
      store.save();
      console.log(`Revoked access to "${dome}" from ${username}.`);
    } catch (e) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

userCmd.command('permissions <username>').description('List permissions for a user')
  .option('--json', 'JSON output')
  .action((username, opts) => {
    const store = new UserStore();
    store.load();
    try {
      const perms = store.getPermissions(username);
      const entries = Object.entries(perms);
      if (entries.length === 0) { console.log(`No permissions for "${username}".`); return; }
      if (opts.json) {
        console.log(JSON.stringify(entries.map(([dome, p]) => ({ dome, role: p.role })), null, 2));
      } else {
        console.log(`Permissions for ${username}:`);
        for (const [dome, p] of entries) {
          console.log(`  ${dome}: ${p.role}`);
        }
      }
    } catch (e) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });


// ── Dome management commands (SE-291 S3) ──
const domeCmd = program.command('dome').description('Manage context domes');

domeCmd.command('create <name>').description('Create a new dome')
  .option('--path <dir>', 'Dome directory path')
  .option('--description <text>', 'Dome description', '')
  .option('--confidentiality <level>', 'N1|N2|N3|N4', 'N2')
  .action((name, opts) => {
    const registry = new DomeRegistry();
    const domePath = opts.path || path.join(process.cwd(), 'vaults', name);
    fs.mkdirSync(domePath, { recursive: true });

    try {
      registry.load();
    } catch {
    }

    try {
      registry.add({
        name,
        path: domePath,
        description: opts.description,
        confidentiality: opts.confidentiality,
        active: true,
      });
      registry.save();
      console.log(`Dome "${name}" created at ${domePath}`);
      if (!registry.defaultDome) {
        registry.setDefault(name);
        console.log(`  Set as default dome`);
      }
    } catch (e: unknown) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

domeCmd.command('list').description('List registered domes')
  .option('--json', 'JSON output')
  .action((opts) => {
    const registry = new DomeRegistry();
    try { registry.load(); } catch { console.log('No domes registered.'); return; }
    const domes = registry.list();
    if (domes.length === 0) { console.log('No domes registered.'); return; }
    if (opts.json) {
      console.log(JSON.stringify(domes.map(d => ({ name: d.name, path: d.path, description: d.description, confidentiality: d.confidentiality, active: d.active })), null, 2));
    } else {
      console.log(`Domes (default: ${registry.defaultDome}):`);
      for (const d of domes) {
        console.log(`  ${d.active ? '●' : '○'} ${d.name}  [${d.confidentiality}]  ${d.path}${d.name === registry.defaultDome ? '  ← default' : ''}`);
      }
    }
  });

domeCmd.command('info <name>').description('Show dome details')
  .option('--json', 'JSON output')
  .action((name, opts) => {
    const registry = new DomeRegistry();
    registry.load();
    const dome = registry.get(name);
    if (!dome) { console.error(`Dome "${name}" not found.`); process.exit(1); }
    if (opts.json) {
      console.log(JSON.stringify({ name: dome.name, path: dome.path, description: dome.description, confidentiality: dome.confidentiality, active: dome.active, schemaDir: dome.schemaDir, isDefault: name === registry.defaultDome }, null, 2));
    } else {
      console.log(`Name: ${dome.name}`);
      console.log(`Path: ${dome.path}`);
      console.log(`Description: ${dome.description || '(none)'}`);
      console.log(`Confidentiality: ${dome.confidentiality}`);
      console.log(`Active: ${dome.active ? 'yes' : 'no'}`);
      console.log(`Default: ${name === registry.defaultDome ? 'yes' : 'no'}`);
    }
  });

domeCmd.command('delete <name>').description('Remove dome from registry')
  .option('--force', 'Also delete dome files from disk')
  .action((name, opts) => {
    const registry = new DomeRegistry();
    registry.load();
    const dome = registry.get(name);
    if (!dome) { console.error(`Dome "${name}" not found.`); process.exit(1); }
    try {
      registry.remove(name);
      registry.save();
      console.log(`Dome "${name}" removed from registry.`);
      if (opts.force && dome.active) {
        fs.rmSync(dome.path, { recursive: true, force: true });
        console.log(`  Files deleted: ${dome.path}`);
      }
    } catch (e: unknown) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });

domeCmd.command('set-default <name>').description('Set default dome')
  .action((name) => {
    const registry = new DomeRegistry();
    registry.load();
    try {
      registry.setDefault(name);
      console.log(`Default dome set to "${name}".`);
    } catch (e: unknown) {
      console.error(`Error: ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  });


// ── Confidentiality commands (SE-291 S7) ──
const confCmd = program.command('confidentiality').description('Manage dome confidentiality levels');

confCmd.command('set <level>').description('Set confidentiality level for a dome')
  .option('--dome <name>', 'Dome name')
  .action((level, opts) => {
    if (!['N1', 'N2', 'N3', 'N4'].includes(level)) {
      console.error('Level must be N1, N2, N3, or N4.');
      process.exit(1);
    }
    const registry = new DomeRegistry();
    registry.load();
    const domeName = opts.dome || registry.getDefaultName();
    const dome = registry.get(domeName);
    if (!dome) { console.error(`Dome "${domeName}" not found.`); process.exit(1); }
    dome.confidentiality = level as 'N1'|'N2'|'N3'|'N4';
    registry.save();
    console.log(`Confidentiality for "${domeName}" set to ${level}.`);
  });

confCmd.command('get').description('Get confidentiality level for a dome')
  .option('--dome <name>', 'Dome name')
  .action((opts) => {
    const registry = new DomeRegistry();
    registry.load();
    const domeName = opts.dome || registry.getDefaultName();
    const dome = registry.get(domeName);
    if (!dome) { console.error(`Dome "${domeName}" not found.`); process.exit(1); }
    console.log(`${dome.name}: ${dome.confidentiality}`);
  });

confCmd.command('audit').description('Audit confidentiality across all domes')
  .action(() => {
    const registry = new DomeRegistry();
    registry.load();
    const audit = ConfidentialityGuard.audit(registry.list());
    console.log(ConfidentialityGuard.formatAudit(audit));
  });


// ── Audit commands (SE-293 S2) ──
const auditCmd = program.command('audit').description('Query access audit logs');

auditCmd.command('show').description('Show audit entries')
  .option('--username <name>', 'Filter by username')
  .option('--dome <name>', 'Filter by dome')
  .option('--action <action>', 'Filter by action (read|write|admin)')
  .option('--result <result>', 'Filter by result (allowed|denied)')
  .option('--since <date>', 'From date (YYYY-MM-DD)')
  .option('--until <date>', 'To date (YYYY-MM-DD)')
  .option('--last <N>', 'Last N entries (default 50)')
  .option('--json', 'JSON output')
  .action((opts: any) => {
    const logger = new AuditLogger();
    const entries = logger.query({
      username: opts.username,
      dome: opts.dome,
      action: opts.action,
      result: opts.result,
      since: opts.since,
      until: opts.until,
      last: opts.last ? parseInt(opts.last, 10) : 50,
    });
    if (opts.json) {
      console.log(JSON.stringify(entries, null, 2));
    } else {
      if (entries.length === 0) { console.log('No audit entries found.'); return; }
      for (const e of entries) {
        const icon = e.result === 'allowed' ? 'OK' : 'NO';
        console.log(`[${e.ts.slice(0,19)}] ${icon} ${e.username.padEnd(12)} ${e.dome.padEnd(16)} ${e.action.padEnd(6)} ${e.reason || ''}`);
      }
    }
  });

auditCmd.command('stats').description('Show audit statistics')
  .option('--since <date>', 'From date (YYYY-MM-DD)')
  .option('--until <date>', 'To date (YYYY-MM-DD)')
  .option('--json', 'JSON output')
  .action((opts: any) => {
    const logger = new AuditLogger();
    const stats = logger.stats({ since: opts.since, until: opts.until });
    if (opts.json) {
      console.log(JSON.stringify(stats, null, 2));
    } else {
      console.log('Audit Summary');
      console.log('='.repeat(60));
      console.log(`Total: ${stats.total} accesses (${stats.allowed} allowed, ${stats.denied} denied)`);
      console.log('');
      if (Object.keys(stats.byUser).length > 0) {
        console.log('By user:');
        for (const [u, c] of Object.entries(stats.byUser)) {
          console.log(`  ${u}: ${c}`);
        }
        console.log('');
      }
      if (Object.keys(stats.byDome).length > 0) {
        console.log('By dome:');
        for (const [d, c] of Object.entries(stats.byDome)) {
          console.log(`  ${d}: ${c}`);
        }
        console.log('');
      }
      if (Object.keys(stats.byAction).length > 0) {
        console.log('By action:');
        for (const [a, c] of Object.entries(stats.byAction)) {
          console.log(`  ${a}: ${c}`);
        }
      }
    }
  });


// ── Quota commands (SE-293 S4) ──
userCmd.command('quota <username>').description('Show or configure user quotas')
  .option('--set-rpm <N>', 'Set requests per minute')
  .option('--set-rph <N>', 'Set requests per hour')
  .option('--set-rpd <N>', 'Set requests per day')
  .option('--reset', 'Reset counters to zero')
  .option('--json', 'JSON output')
  .action((username: string, opts: any) => {
    const store = new UserQuotaStore();
    store.load();

    if (opts.reset) {
      store.resetCounters(username);
      console.log(`Quota counters reset for "${username}".`);
      return;
    }

    if (opts.setRpm || opts.setRph || opts.setRpd) {
      const config: Record<string, number> = {};
      if (opts.setRpm) config.requestsPerMinute = parseInt(opts.setRpm, 10);
      if (opts.setRph) config.requestsPerHour = parseInt(opts.setRph, 10);
      if (opts.setRpd) config.requestsPerDay = parseInt(opts.setRpd, 10);
      store.setConfig(username, config);
      store.persist();
      console.log(`Quotas updated for "${username}".`);
    }

    const config = store.getConfig(username);
    const status = store.check(username);

    if (opts.json) {
      console.log(JSON.stringify({ username, config, remaining: status.remaining }, null, 2));
    } else {
      console.log(`Quotas for ${username}:`);
      console.log(`  Requests per minute:  ${config.requestsPerMinute === 0 ? 'unlimited' : String(config.requestsPerMinute)}`);
      console.log(`  Requests per hour:    ${config.requestsPerHour === 0 ? 'unlimited' : String(config.requestsPerHour)}`);
      console.log(`  Requests per day:     ${config.requestsPerDay === 0 ? 'unlimited' : String(config.requestsPerDay)}`);
      if (status.warning) console.log(`  WARNING: ${status.warning}`);
    }
  });


program.parse();
