// SE-410 S2 — semáforo, timeout y fan-out con resultados parciales (AC6)
import { describe, it, expect } from 'vitest';
import { Semaphore, withTimeout, fanOut, TimeoutError } from '../../../src/rag/parallel.js';

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

describe('Semaphore', () => {
  it('limita la concurrencia', async () => {
    const sem = new Semaphore(2);
    let running = 0;
    let peak = 0;
    await Promise.all(Array.from({ length: 6 }, () => sem.run(async () => {
      running++; peak = Math.max(peak, running);
      await sleep(10);
      running--;
    })));
    expect(peak).toBe(2);
  });

  it('libera el permiso aunque la tarea falle', async () => {
    const sem = new Semaphore(1);
    await expect(sem.run(async () => { throw new Error('x'); })).rejects.toThrow('x');
    await expect(sem.run(async () => 42)).resolves.toBe(42);
  });
});

describe('withTimeout', () => {
  it('rechaza con TimeoutError', async () => {
    await expect(withTimeout(sleep(200), 20)).rejects.toBeInstanceOf(TimeoutError);
    await expect(withTimeout(Promise.resolve(1), 20)).resolves.toBe(1);
  });
});

describe('fanOut', () => {
  it('devuelve parciales: ok, timeout y error por tarea', async () => {
    const res = await fanOut([
      { key: 'a', fn: async () => 'A' },
      { key: 'slow', fn: async () => { await sleep(300); return 'S'; } },
      { key: 'bad', fn: async () => { throw new Error('boom'); } },
    ], { concurrency: 3, timeoutMs: 50 });
    expect(res.get('a')).toEqual({ ok: true, value: 'A' });
    expect(res.get('slow')).toMatchObject({ ok: false, timeout: true });
    expect(res.get('bad')).toMatchObject({ ok: false, timeout: false, error: 'boom' });
  });

  it('ejecuta en paralelo (tiempo ≈ max, no suma)', async () => {
    const t0 = Date.now();
    await fanOut(Array.from({ length: 4 }, (_, i) => ({ key: String(i), fn: () => sleep(60) })), { concurrency: 4, timeoutMs: 1000 });
    expect(Date.now() - t0).toBeLessThan(200);
  });

  it('SE-412: la tarea recibe una señal que se aborta al vencer el timeout', async () => {
    let seen: AbortSignal | undefined;
    const res = await fanOut([{ key: 'slow', fn: async (signal) => { seen = signal; await sleep(120); return signal.aborted; } }], { concurrency: 1, timeoutMs: 30 });
    expect(res.get('slow')).toMatchObject({ ok: false, timeout: true });
    expect(seen?.aborted).toBe(true);
  });
});
