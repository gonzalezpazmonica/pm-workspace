import * as http from 'node:http';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { VaultStorage } from '../storage/index.js';
import { SearchEngine } from '../search/index.js';
import { RateLimiter } from './ratelimit.js';
import type { VaultConfig } from '../types.js';

export class A2AServer {
  private config: VaultConfig;
  private storage: VaultStorage;
  private search: SearchEngine;
  private limiter: RateLimiter;
  private startTime: number;

  constructor(config: VaultConfig) {
    this.config = config;
    this.storage = new VaultStorage(config);
    this.search = new SearchEngine(config);
    this.limiter = new RateLimiter(100);
    this.startTime = Date.now();
    this.initVault();
  }

  private initVault(): void {
    const vp = this.config.path;
    fs.mkdirSync(vp, { recursive: true });
    if (!fs.existsSync(path.join(vp, 'INDEX.md'))) {
      fs.writeFileSync(path.join(vp, 'INDEX.md'), `# ${this.config.name}\n\n`);
    }
    if (!fs.existsSync(path.join(vp, 'MAP.md'))) {
      fs.writeFileSync(path.join(vp, 'MAP.md'), `# ${this.config.name} — Routing Map\n\n`);
    }
  }

  async start(port: number, host = '127.0.0.1', authToken?: string): Promise<void> {
    const server = http.createServer(async (req, res) => {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Access-Control-Allow-Origin', '*');

      const clientIp = req.socket.remoteAddress || 'unknown';
      if (!this.limiter.allow(clientIp)) {
        res.writeHead(429);
        res.end(JSON.stringify({ error: 'Rate limit exceeded' }));
        return;
      }

      if (authToken) {
        const auth = req.headers.authorization;
        if (!auth || auth !== `Bearer ${authToken}`) {
          res.writeHead(401);
          res.end(JSON.stringify({ error: 'Unauthorized' }));
          return;
        }
      }

      try {
        const url = new URL(req.url || '/', `http://${host}:${port}`);
        const p = url.pathname;

        if (p === '/health') {
          res.writeHead(200);
          res.end(JSON.stringify({
            status: 'ok',
            uptime: Math.floor((Date.now() - this.startTime) / 1000),
            vault: this.config.name,
          }));
        } else if (p === '/search') {
          const q = url.searchParams.get('q') || '';
          const max = parseInt(url.searchParams.get('maxResults') || '10', 10);
          this.search.buildIndex();
          const results = this.search.search({ query: q, maxResults: max });
          res.writeHead(200);
          res.end(JSON.stringify({ results }));
        } else if (p.startsWith('/context/')) {
          const parts = p.replace('/context/', '').split('/');
          const notePath = parts.slice(1).join('/');
          const note = await this.storage.read(notePath);
          res.writeHead(200);
          res.end(JSON.stringify({ path: note.path, name: note.name, frontmatter: note.frontmatter, tags: note.tags, content: note.content }));
        } else if (p === '/stats') {
          const stats = await this.storage.stats();
          res.writeHead(200);
          res.end(JSON.stringify(stats));
        } else if (p === '/share' && req.method === 'POST') {
          let body = '';
          req.on('data', chunk => body += chunk);
          req.on('end', async () => {
            try {
              const { path: notePath, content } = JSON.parse(body);
              const receipt = await this.storage.write(notePath, content);
              res.writeHead(200);
              res.end(JSON.stringify(receipt));
            } catch {
              res.writeHead(400);
              res.end(JSON.stringify({ error: 'Invalid request' }));
            }
          });
          return;
        } else {
          res.writeHead(404);
          res.end(JSON.stringify({ error: 'Not found' }));
        }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        res.writeHead(500);
        res.end(JSON.stringify({ error: msg }));
      }
    });

    await new Promise<void>((resolve) => server.listen(port, host, resolve));
    if (host === '0.0.0.0') {
      console.warn('WARNING: Server bound to 0.0.0.0 — accessible from network.');
    }
    console.error(`A2A server listening on http://${host}:${port}`);
  }
}
