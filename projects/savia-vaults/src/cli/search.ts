// SE-412 — CLI de `vault_search`. Módulo separado para que `savia-vaults search`
// no cargue el servidor MCP/A2A (arranque en frío).
import { Command } from 'commander';
import { SearchEngine, defaultSearchCacheDir } from '../search/index.js';
import type { VaultConfig } from '../types.js';

function makeConfig(name: string, vaultPath: string): VaultConfig {
  return { name, path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024 };
}

const program = new Command();
program.name('savia-vaults');

program.command('search <query>').description('Search the vault')
  .option('-p, --path <path>', 'Vault path', process.cwd()).option('--json', 'JSON output', false)
  .option('--enrich', 'SE-330: enriquecer con score del grafo', false)
  .action(async (query, opts) => {
    const config = makeConfig('vault', opts.path);
    // SE-412: caché persistente del índice para no reconstruirlo en cada proceso.
    const engine = new SearchEngine(config, { cacheDir: defaultSearchCacheDir() });
    engine.buildIndex();
    const results = opts.enrich
      ? await engine.searchEnrichedAsync({ query, maxResults: 10, enrich: true })
      : engine.search({ query, maxResults: 10 });
    if (opts.json) { console.log(JSON.stringify(results, null, 2)); }
    else { for (const r of results as { path: string; score: number; snippet: string }[]) { console.log(`${r.path} (score: ${r.score.toFixed(2)})`); console.log(`  ${r.snippet}\n`); } }
  });


program.parse();
