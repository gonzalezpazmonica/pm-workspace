import * as fs from 'node:fs';
import * as path from 'node:path';

export interface AuditEntry {
  ts: string;
  username: string;
  dome: string;
  action: 'read' | 'write' | 'admin';
  tool?: string;
  result: 'allowed' | 'denied';
  reason?: string;
  ip?: string;
}

export interface AuditFilter {
  username?: string;
  dome?: string;
  action?: string;
  result?: string;
  tool?: string;
  since?: string;
  until?: string;
  last?: number;
}

export interface AuditStats {
  total: number;
  allowed: number;
  denied: number;
  byUser: Record<string, number>;
  byDome: Record<string, number>;
  byAction: Record<string, number>;
  periodDays: number;
}

function formatDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseDate(s: string): Date {
  return new Date(s + 'T00:00:00Z');
}

export class AuditLogger {
  private logDir: string;
  private currentDate: string;

  constructor(logDir?: string) {
    this.logDir = logDir || process.cwd();
    this.currentDate = formatDate(new Date());
  }

  record(entry: Omit<AuditEntry, 'ts'>): void {
    const ts = new Date().toISOString();
    const full: AuditEntry = { ts, ...entry };
    const line = JSON.stringify(full);

    const today = formatDate(new Date());
    if (today !== this.currentDate) {
      this.currentDate = today;
    }

    const filePath = path.join(this.logDir, `savia-vaults.audit-${this.currentDate}.jsonl`);
    try {
      const dir = path.dirname(filePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.appendFileSync(filePath, line + '\n');
    } catch {
      process.stderr.write(`[AuditLogger] WARNING: failed to write audit entry: ${line}\n`);
    }
  }

  query(filters: AuditFilter): AuditEntry[] {
    const results: AuditEntry[] = [];
    const files = this.getLogFiles(filters.since, filters.until);

    for (const file of files) {
      if (!fs.existsSync(file)) continue;
      const content = fs.readFileSync(file, 'utf-8');
      const lines = content.split('\n').filter(l => l.trim());

      for (const line of lines) {
        try {
          const entry: AuditEntry = JSON.parse(line);
          if (filters.username && entry.username !== filters.username) continue;
          if (filters.dome && entry.dome !== filters.dome) continue;
          if (filters.action && entry.action !== filters.action) continue;
          if (filters.result && entry.result !== filters.result) continue;
          if (filters.tool && entry.tool !== filters.tool) continue;
          results.push(entry);
        } catch {
          process.stderr.write(`[AuditLogger] WARNING: malformed JSON line in ${file}\n`);
        }
      }
    }

    if (filters.last && filters.last > 0) {
      return results.slice(-filters.last);
    }
    return results;
  }

  stats(filters: { since?: string; until?: string }): AuditStats {
    const entries = this.query(filters);
    const stats: AuditStats = {
      total: entries.length,
      allowed: 0,
      denied: 0,
      byUser: {},
      byDome: {},
      byAction: {},
      periodDays: 0,
    };

    for (const e of entries) {
      if (e.result === 'allowed') stats.allowed++;
      else stats.denied++;

      stats.byUser[e.username] = (stats.byUser[e.username] || 0) + 1;
      stats.byDome[e.dome] = (stats.byDome[e.dome] || 0) + 1;
      stats.byAction[e.action] = (stats.byAction[e.action] || 0) + 1;
    }

    if (filters.since && filters.until) {
      const start = parseDate(filters.since);
      const end = parseDate(filters.until);
      stats.periodDays = Math.max(1, Math.ceil((end.getTime() - start.getTime()) / 86400000));
    }

    return stats;
  }

  close(): void {
    this.currentDate = '';
  }

  private getLogFiles(since?: string, until?: string): string[] {
    const files: string[] = [];
    if (!fs.existsSync(this.logDir)) return files;

    const allFiles = fs.readdirSync(this.logDir)
      .filter(f => f.startsWith('savia-vaults.audit-') && f.endsWith('.jsonl'))
      .sort();

    for (const file of allFiles) {
      const match = file.match(/savia-vaults\.audit-(\d{4}-\d{2}-\d{2})\.jsonl/);
      if (!match) continue;
      const fileDate = match[1];

      if (since && fileDate < since) continue;
      if (until && fileDate > until) continue;
      files.push(path.join(this.logDir, file));
    }

    return files;
  }
}
