import type { FederatedDome, FederatedSearchResult } from './types.js';

export class A2AClient {
  async search(dome: FederatedDome, query: string, maxResults = 20): Promise<{ results: FederatedSearchResult[]; status: 'ok' | 'timeout' | 'error'; latencyMs: number }> {
    const start = Date.now();
    try {
      const ctrl = new AbortController(); const t = setTimeout(() => ctrl.abort(), dome.timeout);
      const url = new URL('/search', dome.url); url.searchParams.set('q', query); url.searchParams.set('maxResults', String(maxResults));
      const h: Record<string, string> = { 'Accept': 'application/json' }; if (dome.authToken) h['Authorization'] = `Bearer ${dome.authToken}`;
      const resp = await fetch(url.toString(), { headers: h, signal: ctrl.signal }); clearTimeout(t);
      if (!resp.ok) return { results: [], status: 'error', latencyMs: Date.now() - start };
      const data = await resp.json() as { results?: Array<{ path: string; score: number; snippet: string; tags?: string[] }> };
      return { results: (data.results || []).map(r => ({ path: r.path, score: r.score * dome.weight, snippet: r.snippet || '', tags: r.tags || [], source: dome.id, contentHash: this.hash(r.snippet || r.path) })), status: 'ok', latencyMs: Date.now() - start };
    } catch (e) { const ms = Date.now() - start; return { results: [], status: e instanceof Error && e.name === 'AbortError' ? 'timeout' : 'error', latencyMs: ms }; }
  }

  async healthCheck(dome: FederatedDome): Promise<{ healthy: boolean; latencyMs: number }> {
    const start = Date.now();
    try {
      const ctrl = new AbortController(); const t = setTimeout(() => ctrl.abort(), 2000);
      const h: Record<string, string> = { 'Accept': 'application/json' }; if (dome.authToken) h['Authorization'] = `Bearer ${dome.authToken}`;
      const resp = await fetch(`${dome.url}/health`, { headers: h, signal: ctrl.signal }); clearTimeout(t);
      return { healthy: resp.ok, latencyMs: Date.now() - start };
    } catch { return { healthy: false, latencyMs: Date.now() - start }; }
  }

  private hash(s: string): string { let h = 0; for (let i = 0; i < s.length; i++) { h = ((h << 5) - h) + s.charCodeAt(i); h = h & h; } return Math.abs(h).toString(16).padStart(8, '0'); }
}
