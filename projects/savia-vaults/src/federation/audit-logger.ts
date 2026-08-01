// Federation Audit Logger — JSONL audit trail for federated queries (SE-283 Slice 3)
import * as fs from 'node:fs'; import * as path from 'node:path';

export class FederationAuditLogger {
  private dir: string; private maxSize: number;
  constructor(dir: string, maxSize = 10 * 1024 * 1024) { this.dir = dir; this.maxSize = maxSize; fs.mkdirSync(dir, { recursive: true }); }

  private currentFile(): string {
    const base = `federation-audit-${new Date().toISOString().slice(0,10)}`;
    const files = fs.readdirSync(this.dir).filter(f => f.startsWith('federation-audit-') && f.endsWith('.jsonl')).sort();
    if (files.length === 0) return path.join(this.dir, `${base}.jsonl`);
    const last = path.join(this.dir, files[files.length - 1]);
    try { if (fs.statSync(last).size < this.maxSize) return last; } catch {}
    const sameDay = files.filter(f => f.startsWith(base));
    return path.join(this.dir, `${base}-${sameDay.length + 1}.jsonl`);
  }

  private write(entry: Record<string, unknown>): void {
    const file = this.currentFile();
    fs.appendFileSync(file, JSON.stringify({ ts: new Date().toISOString(), ...entry }) + '\n');
  }

  logQuery(dome: string, query: string, status: string, results: number, latencyMs: number): void {
    this.write({ event: 'federated_query', dome, query, status, results, latency_ms: latencyMs });
  }

  logRotation(dome: string): void {
    this.write({ event: 'token_rotation', dome });
  }
}
