/** SE-410 — Paralelismo acotado con timeout por tarea y resultados parciales. */

export class TimeoutError extends Error {
  constructor(ms: number) {
    super(`timeout tras ${ms} ms`);
    this.name = 'TimeoutError';
  }
}

export class Semaphore {
  private available: number;
  private readonly waiters: (() => void)[] = [];

  constructor(permits: number) {
    this.available = Math.max(1, Math.floor(permits));
  }

  private async acquire(): Promise<void> {
    if (this.available > 0) {
      this.available--;
      return;
    }
    await new Promise<void>(resolve => this.waiters.push(resolve));
  }

  private release(): void {
    const next = this.waiters.shift();
    if (next) next();
    else this.available++;
  }

  async run<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }
}

export function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new TimeoutError(ms)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

export type TaskResult<T> = { ok: true; value: T } | { ok: false; timeout: boolean; error: string };

export async function fanOut<T>(
  tasks: { key: string; fn: () => Promise<T> }[],
  opts: { concurrency: number; timeoutMs: number },
): Promise<Map<string, TaskResult<T>>> {
  const sem = new Semaphore(opts.concurrency);
  const out = new Map<string, TaskResult<T>>();
  await Promise.all(tasks.map(t => sem.run(async () => {
    try {
      out.set(t.key, { ok: true, value: await withTimeout(t.fn(), opts.timeoutMs) });
    } catch (e) {
      out.set(t.key, { ok: false, timeout: e instanceof TimeoutError, error: e instanceof Error ? e.message : String(e) });
    }
  })));
  return out;
}
