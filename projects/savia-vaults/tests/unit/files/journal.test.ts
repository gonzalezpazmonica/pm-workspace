// SE-418 — journal de operaciones (node:sqlite): operaciones pendientes con lease, idempotencia,
// outbox al menos una vez con reclamación atómica, receipts y reconstrucción si se corrompe.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { Journal } from '../../../src/files/journal.js';

describe('Journal', () => {
  let dir: string;
  let j: Journal;
  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-journal-'));
    j = Journal.open(dir).journal;
  });
  afterEach(() => { Journal.closeAll(); fs.rmSync(dir, { recursive: true, force: true }); });

  it('crea journal.db 0600 en WAL; reabrir devuelve el mismo estado', () => {
    expect(fs.statSync(path.join(dir, 'journal.db')).mode & 0o777).toBe(0o600);
    expect(j.pragma('journal_mode')).toBe('wal');
    expect(j.pragma('synchronous')).toBe(2); // FULL
    j.begin({ operationId: 'o_1', kind: 'put', leaseMs: 1000 });
    const again = Journal.open(dir);
    expect(again.created).toBe(false);
    expect(again.journal.get('o_1')?.status).toBe('pending');
  });

  it('begin/touch/commit: documentos de la operación, outbox y receipt en una transacción', () => {
    j.begin({ operationId: 'o_1', kind: 'put', leaseMs: 60_000 });
    j.touch('o_1', 'f_0000000000000001');
    j.touch('o_1', 'f_0000000000000001');
    expect(j.documents('o_1')).toEqual(['f_0000000000000001']);
    expect(j.pendingFor('f_0000000000000001')).toBe(true);
    j.commit('o_1', { commitSha: 'a'.repeat(40), receipt: { operationId: 'o_1' } as never, events: [{ event: 'rag-sync', payload: {} }] });
    expect(j.get('o_1')).toMatchObject({ status: 'committed', commitSha: 'a'.repeat(40) });
    expect(j.pendingFor('f_0000000000000001')).toBe(false);
    expect(j.receipt('o_1')).toEqual({ operationId: 'o_1' });
    expect(j.due().map((e) => e.event)).toEqual(['rag-sync']);
  });

  it('idempotencia: la misma clave devuelve la operación existente', () => {
    const a = j.begin({ operationId: 'o_1', kind: 'put', idemKeyHash: 'k', requestHash: 'r1', leaseMs: 1000 });
    expect(a.existing).toBeUndefined();
    const b = j.begin({ operationId: 'o_2', kind: 'put', idemKeyHash: 'k', requestHash: 'r2', leaseMs: 1000 });
    expect(b.existing?.operationId).toBe('o_1');
    expect(b.existing?.requestHash).toBe('r1');
    expect(j.get('o_2')).toBeUndefined();
  });

  it('stale: lease vencido o proceso muerto en esta máquina; los vivos no', () => {
    j.begin({ operationId: 'o_live', kind: 'put', leaseMs: 60_000 });
    j.begin({ operationId: 'o_old', kind: 'put', leaseMs: 60_000 });
    j.release('o_old'); // COMMIT_PENDING: se deja para el reconciliador
    expect(j.stalePending().map((r) => r.operationId)).toEqual(['o_old']);
    j.begin({ operationId: 'o_dead', kind: 'put', leaseMs: 60_000, pid: 2 ** 22 + 12345 });
    expect(j.stalePending().map((r) => r.operationId).sort()).toEqual(['o_dead', 'o_old']);
  });

  it('fail deja receipt y código de error, nunca texto libre', () => {
    j.begin({ operationId: 'o_1', kind: 'put', leaseMs: 1000 });
    j.fail('o_1', 'SCAN_REQUIRED', { operationId: 'o_1', status: 'failed' } as never);
    expect(j.get('o_1')).toMatchObject({ status: 'failed', errorCode: 'SCAN_REQUIRED' });
    expect(() => j.fail('o_1', 'texto libre con nombre.pdf', {} as never)).toThrow(/INVALID_INPUT/);
  });

  it('outbox: reclamación atómica con lease, reintento con retroceso y done', () => {
    j.begin({ operationId: 'o_1', kind: 'put', leaseMs: 1000 });
    j.commit('o_1', { receipt: {} as never, events: [{ event: 'extract', payload: { refs: [1] } }] });
    const [ev] = j.due();
    expect(ev.payload).toEqual({ refs: [1] });
    expect(j.claim(ev.id, 60_000)).toBe(true);
    expect(j.claim(ev.id, 60_000)).toBe(false); // otro consumidor no la reclama
    expect(j.due()).toEqual([]);
    j.retry(ev.id, 0);
    expect(j.due()[0].attempts).toBe(1);
    j.done(ev.id);
    expect(j.due()).toEqual([]);
  });

  it('corrupto ⇒ se aparta a journal.db.corrupt-* y se crea vacío (created=true)', () => {
    Journal.closeAll();
    fs.writeFileSync(path.join(dir, 'journal.db'), 'esto no es sqlite'.repeat(100));
    for (const s of ['-wal', '-shm']) fs.rmSync(path.join(dir, `journal.db${s}`), { force: true });
    const r = Journal.open(dir);
    expect(r.created).toBe(true);
    expect(fs.readdirSync(dir).some((f) => f.startsWith('journal.db.corrupt-'))).toBe(true);
    expect(r.journal.get('o_1')).toBeUndefined();
  });

  it('borrado en disco ⇒ reabre uno nuevo (no reutiliza el handle del fichero borrado)', () => {
    j.begin({ operationId: 'o_1', kind: 'put', leaseMs: 1000 });
    for (const s of ['', '-wal', '-shm']) fs.rmSync(path.join(dir, `journal.db${s}`), { force: true });
    const r = Journal.open(dir);
    expect(r.created).toBe(true);
    expect(r.journal.get('o_1')).toBeUndefined();
  });

  it('importCommitted reconstruye operaciones confirmadas desde el ledger', () => {
    j.importCommitted([{ operationId: 'o_9', kind: 'put', commitSha: 'c'.repeat(40), at: '2026-09-30T00:00:00.000Z', documents: ['f_0000000000000009'], idemKeyHash: 'k9' }]);
    expect(j.get('o_9')).toMatchObject({ status: 'committed', kind: 'put', commitSha: 'c'.repeat(40) });
    expect(j.begin({ operationId: 'o_10', kind: 'put', idemKeyHash: 'k9', leaseMs: 1 }).existing?.operationId).toBe('o_9');
    expect(j.list(10).map((r) => r.operationId)).toEqual(['o_9']);
  });
});
