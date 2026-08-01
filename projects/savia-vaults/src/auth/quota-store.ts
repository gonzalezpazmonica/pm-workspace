import * as fs from 'node:fs';
import * as path from 'node:path';

export interface QuotaConfig {
  requestsPerMinute: number;
  requestsPerHour: number;
  requestsPerDay: number;
}

export interface QuotaStatus {
  allowed: boolean;
  warning?: string;
  remaining?: { minute: number; hour: number; day: number };
}

interface QuotaCountersEntry {
  window: number;
  count: number;
}

interface UserQuotaData {
  config: QuotaConfig;
  counters: {
    minute: QuotaCountersEntry;
    hour: QuotaCountersEntry;
    day: QuotaCountersEntry;
  };
}

interface QuotasFile {
  version: number;
  users: Record<string, UserQuotaData>;
}

const DEFAULT_CONFIG: QuotaConfig = {
  requestsPerMinute: 60,
  requestsPerHour: 1000,
  requestsPerDay: 5000,
};

const WARNING_THRESHOLD = 0.8;

export class QuotaExceededError extends Error {
  username: string;
  window: 'minute' | 'hour' | 'day';
  limit: number;
  current: number;

  constructor(username: string, window: 'minute' | 'hour' | 'day', limit: number, current: number) {
    super(`Quota exceeded for "${username}": ${current}/${limit} on ${window} window`);
    this.name = 'QuotaExceededError';
    this.username = username;
    this.window = window;
    this.limit = limit;
    this.current = current;
  }
}

function getWindow(windowMs: number): number {
  return Math.floor(Date.now() / windowMs);
}

export class UserQuotaStore {
  private filePath: string;
  private quotas: Map<string, UserQuotaData> = new Map();
  private persistTimer: ReturnType<typeof setInterval> | null = null;

  constructor(filePath?: string) {
    this.filePath = filePath || 'savia-vaults.quotas.json';
  }

  isActive(): boolean {
    return this.quotas.size > 0;
  }

  check(username: string): QuotaStatus {
    const data = this.getOrCreate(username);
    const now = Date.now();
    let warning: string | undefined;

    const windows = [
      { key: 'minute' as const, ms: 60000, limit: data.config.requestsPerMinute },
      { key: 'hour' as const, ms: 3600000, limit: data.config.requestsPerHour },
      { key: 'day' as const, ms: 86400000, limit: data.config.requestsPerDay },
    ];

    const remaining: { minute: number; hour: number; day: number } = { minute: 0, hour: 0, day: 0 };

    for (const w of windows) {
      const currentWindow = getWindow(w.ms);
      const counter = data.counters[w.key];

      if (counter.window !== currentWindow) {
        counter.window = currentWindow;
        counter.count = 0;
      }

      if (w.limit === 0) {
        remaining[w.key] = Infinity;
        continue;
      }

      remaining[w.key] = w.limit - counter.count;

      if (counter.count >= w.limit) {
        return { allowed: false, remaining };
      }

      if (counter.count >= w.limit * WARNING_THRESHOLD) {
        warning = `User "${username}" at ${Math.round((counter.count / w.limit) * 100)}% of ${w.key} quota (${counter.count}/${w.limit})`;
      }
    }

    return { allowed: true, warning, remaining };
  }

  record(username: string): void {
    const data = this.getOrCreate(username);
    const now = Date.now();

    const windows = [
      { key: 'minute' as const, ms: 60000 },
      { key: 'hour' as const, ms: 3600000 },
      { key: 'day' as const, ms: 86400000 },
    ];

    for (const w of windows) {
      const currentWindow = getWindow(w.ms);
      const counter = data.counters[w.key];

      if (counter.window !== currentWindow) {
        counter.window = currentWindow;
        counter.count = 0;
      }

      counter.count++;
    }
  }

  persist(): void {
    const data: QuotasFile = { version: 1, users: {} };
    for (const [username, qd] of this.quotas) {
      data.users[username] = qd;
    }

    try {
      const dir = path.dirname(this.filePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(this.filePath, JSON.stringify(data, null, 2) + '\n');
    } catch {
      process.stderr.write(`[QuotaStore] WARNING: failed to persist quotas to ${this.filePath}\n`);
    }
  }

  load(): void {
    if (!fs.existsSync(this.filePath)) return;

    try {
      const raw = fs.readFileSync(this.filePath, 'utf-8');
      const data: QuotasFile = JSON.parse(raw);

      this.quotas.clear();
      for (const [username, qd] of Object.entries(data.users)) {
        this.quotas.set(username, qd);
      }
    } catch {
      process.stderr.write(`[QuotaStore] WARNING: failed to load quotas from ${this.filePath}\n`);
    }
  }

  getConfig(username: string): QuotaConfig {
    const data = this.quotas.get(username);
    if (!data) return { ...DEFAULT_CONFIG };
    return { ...data.config };
  }

  setConfig(username: string, config: Partial<QuotaConfig>): void {
    const data = this.getOrCreate(username);
    if (config.requestsPerMinute !== undefined) data.config.requestsPerMinute = config.requestsPerMinute;
    if (config.requestsPerHour !== undefined) data.config.requestsPerHour = config.requestsPerHour;
    if (config.requestsPerDay !== undefined) data.config.requestsPerDay = config.requestsPerDay;
  }

  resetCounters(username: string): void {
    const data = this.quotas.get(username);
    if (!data) return;

    const now = Date.now();
    data.counters.minute = { window: getWindow(60000), count: 0 };
    data.counters.hour = { window: getWindow(3600000), count: 0 };
    data.counters.day = { window: getWindow(86400000), count: 0 };
  }

  startAutoPersist(intervalMs: number = 60000): void {
    if (this.persistTimer) return;
    this.persistTimer = setInterval(() => this.persist(), intervalMs);
  }

  stopAutoPersist(): void {
    if (this.persistTimer) {
      clearInterval(this.persistTimer);
      this.persistTimer = null;
    }
  }

  close(): void {
    this.stopAutoPersist();
    this.persist();
  }

  private getOrCreate(username: string): UserQuotaData {
    let data = this.quotas.get(username);
    if (!data) {
      const now = Date.now();
      data = {
        config: { ...DEFAULT_CONFIG },
        counters: {
          minute: { window: getWindow(60000), count: 0 },
          hour: { window: getWindow(3600000), count: 0 },
          day: { window: getWindow(86400000), count: 0 },
        },
      };
      this.quotas.set(username, data);
    }
    return data;
  }
}
