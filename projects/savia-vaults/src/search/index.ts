import * as fs from 'node:fs';
import * as path from 'node:path';
import MiniSearch from 'minisearch';
import type { VaultConfig, SearchQuery, SearchResult } from '../types.js';

interface IndexedDoc {
  id: string;
  path: string;
  title: string;
  content: string;
  tags: string[];
}

export class SearchEngine {
  private config: VaultConfig;
  private engine: MiniSearch<IndexedDoc>;
  private _built = false;
  private _fingerprint = '';

  constructor(config: VaultConfig) {
    this.config = config;
    this.engine = new MiniSearch<IndexedDoc>({
      fields: ['title', 'content', 'tags'],
      storeFields: ['path', 'title', 'tags', 'content'],
      searchOptions: {
        boost: { title: 2 },
        prefix: true,
        fuzzy: 0.2,
      },
    });
  }

  /**
   * Build (or refresh) the in-memory index.
   * SE-310: el indice se reconstruye SOLO si cambia (fingerprint por mtime+count),
   * no en cada request — evita el cuelgue con vaults grandes o node_modules.
   */
  buildIndex(force = false): void {
    const fingerprint = this.fingerprint();
    if (!force && this._built && fingerprint === this._fingerprint) return;
    this._fingerprint = fingerprint;
    this._built = true;
    this.engine.removeAll();
    const files = this.listFiles();
    for (const f of files) {
      const fullPath = path.join(this.config.path, f);
      try {
        const raw = fs.readFileSync(fullPath, 'utf-8');
        const { title, content, tags } = this.parseNote(raw);
        this.engine.add({
          id: f,
          path: f,
          title,
          content,
          tags,
        });
      } catch {
        // skip files that can't be read
      }
    }
  }

  /** Fingerprint determinista del vault: max(mtime) + count de ficheros. */
  private fingerprint(): string {
    let newest = 0;
    let count = 0;
    const files = this.listFiles();
    for (const f of files) {
      count += 1;
      try {
        const st = fs.statSync(path.join(this.config.path, f));
        if (st.mtimeMs > newest) newest = st.mtimeMs;
      } catch { /* ignore */ }
    }
    return `${count}:${Math.round(newest)}`;
  }

  search(query: SearchQuery): SearchResult[] {
    const rawResults = this.engine.search(query.query, {});
    const maxResults = query.maxResults || 20;

    return rawResults
      .filter((r) => {
        const p = (r as unknown as { path: string }).path;
        if (query.pathPrefix) {
          return p.startsWith(query.pathPrefix);
        }
        return true;
      })
      .slice(0, maxResults)
      .map((r) => {
        const doc = r as unknown as { path: string; score: number; title: string; content: string; tags: string[] };
        return {
          path: doc.path,
          score: doc.score,
          snippet: this.makeSnippet(doc.content, query.query, 120),
          tags: doc.tags || [],
        };
      });
  }

  getTags(): Map<string, number> {
    const tagCounts = new Map<string, number>();
    const files = this.listFiles();

    for (const f of files) {
      const fullPath = path.join(this.config.path, f);
      try {
        const raw = fs.readFileSync(fullPath, 'utf-8');
        const { tags } = this.parseNote(raw);
        for (const tag of tags) {
          tagCounts.set(tag, (tagCounts.get(tag) || 0) + 1);
        }
      } catch {}
    }

    return new Map([...tagCounts.entries()].sort((a, b) => b[1] - a[1]));
  }

  private listFiles(): string[] {
    const results: string[] = [];
    this.walk(this.config.path, '', results);
    return results;
  }

  private walk(base: string, relative: string, results: string[]): void {
    const full = path.join(base, relative);
    if (!fs.existsSync(full)) return;

    const entries = fs.readdirSync(full, { withFileTypes: true });
    for (const e of entries) {
      const relPath = relative ? `${relative}/${e.name}` : e.name;
      if (e.isDirectory()) {
        if (['.git', '.trash', '.savia-vault'].includes(e.name)) continue;
        this.walk(base, relPath, results);
      } else if (e.isFile()) {
        results.push(relPath);
      }
    }
  }

  private parseNote(raw: string): { title: string; content: string; tags: string[] } {
    const tags = new Set<string>();

    const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
    let title = '';
    let content = raw;

    if (match) {
      const frontmatterBlock = match[1];
      content = match[2].trim();

      const titleMatch = frontmatterBlock.match(/title:\s*(.+)/);
      if (titleMatch) title = titleMatch[1].trim();

      const tagsMatch = frontmatterBlock.match(/tags:\s*\[(.+?)\]/);
      if (tagsMatch) {
        for (const t of tagsMatch[1].split(',')) {
          tags.add(t.trim().toLowerCase());
        }
      }
    }

    if (!title) {
      const h1Match = content.match(/^#\s+(.+)/m);
      if (h1Match) title = h1Match[1];
    }

    const inlineTags = content.match(/#([\w-]+)/g);
    if (inlineTags) {
      for (const t of inlineTags) {
        tags.add(t.slice(1).toLowerCase());
      }
    }

    return { title, content, tags: [...tags] };
  }

  private makeSnippet(content: string, query: string, maxLen: number): string {
    const words = query.toLowerCase().split(/\s+/);
    let bestIdx = 0;

    for (const w of words) {
      const idx = content.toLowerCase().indexOf(w);
      if (idx >= 0) {
        bestIdx = Math.max(0, idx - 40);
        break;
      }
    }

    let snippet = content.slice(bestIdx, bestIdx + maxLen);
    if (bestIdx > 0) snippet = '...' + snippet;
    if (content.length > bestIdx + maxLen) snippet = snippet + '...';
    return snippet;
  }
}
