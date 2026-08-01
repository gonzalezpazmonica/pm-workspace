#!/usr/bin/env node
import { Command } from 'commander';
import { VaultStorage } from '../storage/index.js';
import { SearchEngine } from '../search/index.js';
import type { VaultConfig } from '../types.js';

const program = new Command();

program
  .name('savia-vaults')
  .description('Context Dome Server — MCP + A2A server for AI agent knowledge vaults')
  .version('0.1.0');

program
  .command('init <name>')
  .description('Create a new vault')
  .option('-p, --path <path>', 'Vault directory', process.cwd())
  .action(async (name, opts) => {
    const vaultPath = `${opts.path}/vaults/${name}`;
    const config: VaultConfig = {
      name,
      path: vaultPath,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 10 * 1024 * 1024,
    };
    const storage = new VaultStorage(config);
    await storage.init();
    console.log(`Vault "${name}" created at ${vaultPath}`);
    console.log('Next: savia-vaults serve --transport mcp --path', vaultPath);
  });

program
  .command('serve')
  .description('Start MCP or A2A server')
  .option('--transport <type>', 'mcp or a2a', 'mcp')
  .option('--port <port>', 'Port for A2A', '8923')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .action(async (opts) => {
    console.log(`Server starting (transport: ${opts.transport})...`);
    console.log('Not yet implemented — see SE-286 S4');
  });

program
  .command('search <query>')
  .description('Search the vault')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .option('--json', 'JSON output', false)
  .action(async (query, opts) => {
    const config: VaultConfig = {
      name: 'vault',
      path: opts.path,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 10 * 1024 * 1024,
    };
    const engine = new SearchEngine(config);
    engine.buildIndex();
    const results = engine.search({ query, maxResults: 10 });
    if (opts.json) {
      console.log(JSON.stringify(results, null, 2));
    } else {
      for (const r of results) {
        console.log(`${r.path} (score: ${r.score.toFixed(2)})`);
        console.log(`  ${r.snippet}`);
        console.log();
      }
    }
  });

program
  .command('stats')
  .description('Show vault statistics')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .option('--json', 'JSON output', false)
  .action(async (opts) => {
    const config: VaultConfig = {
      name: 'vault',
      path: opts.path,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 10 * 1024 * 1024,
    };
    const storage = new VaultStorage(config);
    await storage.init();
    const stats = await storage.stats();
    if (opts.json) {
      console.log(JSON.stringify(stats, null, 2));
    } else {
      console.log(`Vault: ${stats.name}`);
      console.log(`Notes: ${stats.noteCount}`);
      console.log(`Size:  ${(stats.totalSize / 1024).toFixed(1)} KB`);
      if (stats.commitCount) console.log(`Commits: ${stats.commitCount}`);
    }
  });

program
  .command('verify')
  .description('Verify vault integrity')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .action(async (opts) => {
    console.log('Verification not yet implemented — see SE-286 S3');
  });

program
  .command('export')
  .description('Export vault to portable format')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .option('-o, --output <dir>', 'Output directory')
  .action(async (opts) => {
    console.log('Export not yet implemented — see SE-286 S6');
  });

program.parse();
