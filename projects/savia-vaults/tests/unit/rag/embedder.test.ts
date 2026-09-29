// SE-410 S1 — embedders
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import * as http from 'node:http';
import type { AddressInfo } from 'node:net';
import { HashEmbedder, OllamaEmbedder, promptProfile, cosine } from '../../../src/rag/embedder.js';
import { RagError } from '../../../src/rag/types.js';

describe('HashEmbedder', () => {
  const e = new HashEmbedder(64);

  it('es determinista y normalizado', async () => {
    const [a] = await e.embed(['política de embeddings'], 'doc');
    const [b] = await e.embed(['política de embeddings'], 'doc');
    expect([...a]).toEqual([...b]);
    expect(Math.abs(cosine(a, a) - 1)).toBeLessThan(1e-6);
  });

  it('textos que comparten tokens son más parecidos', async () => {
    const [q, near, far] = await e.embed(['merge sin permiso', 'nunca merge sin permiso expreso', 'receta de tortilla'], 'doc');
    expect(cosine(q, near)).toBeGreaterThan(cosine(q, far));
  });

  it('contrato con provider hash', async () => {
    const c = await e.contract();
    expect(c.provider).toBe('hash');
    expect(c.dims).toBe(64);
  });
});

describe('promptProfile', () => {
  it('Qwen3 usa instrucción de consulta; bge-m3 no', () => {
    expect(promptProfile('qwen3-embedding:0.6b').queryPrefix).toMatch(/^Instruct:/);
    expect(promptProfile('bge-m3').queryPrefix).toBe('');
  });
});

describe('OllamaEmbedder (servidor falso local)', () => {
  let server: http.Server;
  let url: string;
  const calls: { path: string; body: any }[] = [];

  beforeAll(async () => {
    server = http.createServer((req, res) => {
      let data = '';
      req.on('data', (c) => { data += c; });
      req.on('end', () => {
        const body = data ? JSON.parse(data) : undefined;
        calls.push({ path: req.url || '', body });
        res.setHeader('content-type', 'application/json');
        if (req.url === '/api/tags') {
          res.end(JSON.stringify({ models: [{ name: 'fake-embed:latest', digest: 'abc123def456' }] }));
        } else if (req.url === '/api/embed') {
          const input: string[] = Array.isArray(body.input) ? body.input : [body.input];
          res.end(JSON.stringify({ embeddings: input.map((t) => [t.length, 1, 0]) }));
        } else {
          res.statusCode = 404; res.end('{}');
        }
      });
    });
    await new Promise<void>((r) => server.listen(0, '127.0.0.1', () => r()));
    url = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });
  afterAll(() => new Promise<void>((r) => server.close(() => r())));

  it('resuelve contrato con digest y dims reales', async () => {
    const e = new OllamaEmbedder({ baseUrl: url, model: 'fake-embed' });
    const c = await e.contract();
    expect(c.provider).toBe('ollama');
    expect(c.modelDigest).toBe('abc123def456');
    expect(c.dims).toBe(3);
  });

  it('embebe por lotes, normaliza y aplica prefijo de consulta', async () => {
    calls.length = 0;
    const e = new OllamaEmbedder({ baseUrl: url, model: 'fake-embed', batchSize: 2, queryPrefix: 'Q: ' });
    const v = await e.embed(['a', 'bb', 'ccc'], 'query');
    expect(v).toHaveLength(3);
    const embedCalls = calls.filter(c => c.path === '/api/embed');
    expect(embedCalls).toHaveLength(2);
    expect(embedCalls[0].body.input).toEqual(['Q: a', 'Q: bb']);
    for (const x of v) expect(Math.abs(cosine(x, x) - 1)).toBeLessThan(1e-6);
  });

  it('modelo ausente o servidor caído → EMBEDDER_UNAVAILABLE', async () => {
    await expect(new OllamaEmbedder({ baseUrl: url, model: 'no-existe' }).contract()).rejects.toBeInstanceOf(RagError);
    const dead = new OllamaEmbedder({ baseUrl: 'http://127.0.0.1:9', model: 'x', timeoutMs: 500 });
    await expect(dead.embed(['a'], 'doc')).rejects.toMatchObject({ code: 'EMBEDDER_UNAVAILABLE' });
  });
});
