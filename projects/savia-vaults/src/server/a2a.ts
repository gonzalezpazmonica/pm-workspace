import * as http from 'node:http';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { VaultStorage } from '../storage/index.js';
import { SearchEngine } from '../search/index.js';
import { RateLimiter } from './ratelimit.js';
import { Introspector } from '../knowledge/introspector.js';
import { KnowledgeGraph } from '../knowledge/graph.js';
import { QueryEngine } from '../knowledge/query.js';
import { QualityEngine } from '../knowledge/quality.js';
import type { VaultConfig } from '../types.js';

export class A2AServer {
  private config: VaultConfig;
  private storage: VaultStorage;
  private search: SearchEngine;
  private limiter: RateLimiter;
  private startTime: number;
  private introspector: Introspector;
  private graph: KnowledgeGraph;
  private queryEngine: QueryEngine;
  private quality: QualityEngine;
  private graphBuilt = false;

  constructor(config: VaultConfig) {
    this.config = config;
    this.storage = new VaultStorage(config);
    this.search = new SearchEngine(config);
    this.limiter = new RateLimiter(100);
    this.startTime = Date.now();
    this.introspector = new Introspector(config);
    this.graph = new KnowledgeGraph(config);
    this.queryEngine = new QueryEngine(config);
    this.quality = new QualityEngine(config);
    this.initVault();
  }

  private initVault(): void {
    const vp = this.config.path;
    fs.mkdirSync(vp, { recursive: true });
    if (!fs.existsSync(path.join(vp, 'INDEX.md'))) fs.writeFileSync(path.join(vp, 'INDEX.md'), `# ${this.config.name}\n\n`);
    if (!fs.existsSync(path.join(vp, 'MAP.md'))) fs.writeFileSync(path.join(vp, 'MAP.md'), `# ${this.config.name} — Routing Map\n\n`);
  }

  private async ensureGraph(): Promise<void> {
    if (!this.graphBuilt) { await this.graph.build(); this.graphBuilt = true; }
  }

  async start(port: number, host = '127.0.0.1', authToken?: string): Promise<void> {
    const server = http.createServer(async (req, res) => {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Access-Control-Allow-Origin', '*');
      const clientIp = req.socket.remoteAddress || 'unknown';
      if (!this.limiter.allow(clientIp)) { res.writeHead(429); res.end(JSON.stringify({ error: 'Rate limit exceeded' })); return; }
      if (authToken) {
        const auth = req.headers.authorization;
        if (!auth || auth !== `Bearer ${authToken}`) { res.writeHead(401); res.end(JSON.stringify({ error: 'Unauthorized' })); return; }
      }
      try {
        const url = new URL(req.url || '/', `http://${host}:${port}`);
        const p = url.pathname;
        if (p === '/health') {
          res.writeHead(200); res.end(JSON.stringify({ status: 'ok', uptime: Math.floor((Date.now() - this.startTime) / 1000), vault: this.config.name }));
        } else if (p === '/search') {
          this.search.buildIndex();
          const results = this.search.search({ query: url.searchParams.get('q') || '', maxResults: parseInt(url.searchParams.get('maxResults') || '10', 10) });
          res.writeHead(200); res.end(JSON.stringify({ results }));
        } else if (p.startsWith('/context/')) {
          const note = await this.storage.read(p.replace('/context/', '').split('/').slice(1).join('/'));
          res.writeHead(200); res.end(JSON.stringify(note));
        } else if (p === '/stats') {
          const stats = await this.storage.stats();
          res.writeHead(200); res.end(JSON.stringify(stats));
        } else if (p === '/introspect') {
          const entityPath = url.searchParams.get('entity');
          if (entityPath) {
            const result = await this.introspector.introspectEntity(entityPath);
            res.writeHead(200); res.end(JSON.stringify(result));
          } else {
            const result = await this.introspector.introspectVault();
            res.writeHead(200); res.end(JSON.stringify(result));
          }
        } else if (p === '/graph') {
          await this.ensureGraph();
          const action = url.searchParams.get('action') || 'stats';
          if (action === 'traverse') {
            const result = this.graph.traverse(url.searchParams.get('id') || '', parseInt(url.searchParams.get('depth') || '3', 10));
            res.writeHead(200); res.end(JSON.stringify(result));
          } else if (action === 'search') {
            const nodes = this.graph.searchNodes(url.searchParams.get('q') || '');
            res.writeHead(200); res.end(JSON.stringify(nodes.map(n => ({ id: n.id, type: n.type, path: n.path }))));
          } else {
            res.writeHead(200); res.end(JSON.stringify(this.graph.getStats()));
          }
        } else if (p === '/query') {
          await this.ensureGraph();
          await this.queryEngine.ensureLoaded();
          const result = await this.queryEngine.query(url.searchParams.get('q') || '');
          res.writeHead(200); res.end(JSON.stringify({ markdown: result.outputMarkdown, rows: result.outputRows }));
        } else if (p === '/health-report') {
          const indicators = await this.quality.assess();
          res.writeHead(200); res.end(JSON.stringify(indicators));
        } else if (p === '/share' && req.method === 'POST') {
          let body = '';
          req.on('data', chunk => body += chunk);
          req.on('end', async () => {
            try {
              const { path: notePath, content } = JSON.parse(body);
              const receipt = await this.storage.write(notePath, content);
              res.writeHead(200); res.end(JSON.stringify(receipt));
            } catch { res.writeHead(400); res.end(JSON.stringify({ error: 'Invalid request' })); }
          });
          return;
        } else {
          res.writeHead(404); res.end(JSON.stringify({ error: 'Not found' }));
        }
      } catch (e: unknown) {
        res.writeHead(500); res.end(JSON.stringify({ error: e instanceof Error ? e.message : String(e) }));
      }
    });
    await new Promise<void>((resolve) => server.listen(port, host, resolve));
    if (host === '0.0.0.0') console.warn('WARNING: Server bound to 0.0.0.0.');
    console.error(`A2A server listening on http://${host}:${port}`);
  }
}
