// SE-410 S1 — chunker markdown
import { describe, it, expect } from 'vitest';
import { chunkMarkdown, parseNote, CHUNKER_VERSION } from '../../../src/rag/chunker.js';

const opts = { chunkChars: 1200, overlap: 0.15 };
const para = (n: number, word = 'lorem') => Array.from({ length: n }, (_, i) => `${word}${i}`).join(' ');

describe('parseNote', () => {
  it('extrae metadatos de frescura del frontmatter', () => {
    const raw = '---\ntitle: Regla X\nstatus: Deprecated\nvalid_until: 2026-01-01\nsuperseded_by: rules/y.md\nmodified: 2026-05-02\n---\n# Otro\ncuerpo';
    const { meta, body } = parseNote('rules/x.md', raw);
    expect(meta).toEqual({ title: 'Regla X', status: 'deprecated', validUntil: '2026-01-01', supersededBy: 'rules/y.md', modified: '2026-05-02' });
    expect(body.startsWith('# Otro')).toBe(true);
  });

  it('usa H1 o nombre de fichero como título y mtime como modified', () => {
    const mtime = new Date('2026-09-01T00:00:00Z');
    expect(parseNote('a/b.md', '# Hola\ntexto', mtime).meta.title).toBe('Hola');
    const m = parseNote('a/nota-sin-titulo.md', 'texto', mtime).meta;
    expect(m.title).toBe('nota-sin-titulo');
    expect(m.modified).toBe(mtime.toISOString());
  });

  it('tolera frontmatter inválido', () => {
    const { meta, body } = parseNote('x.md', '---\n: [bad\n---\ncuerpo');
    expect(meta.title).toBe('x');
    expect(body).toBe('cuerpo');
  });
});

describe('chunkMarkdown', () => {
  it('versión de chunker declarada', () => {
    expect(CHUNKER_VERSION).toMatch(/^md-/);
  });

  it('corta por encabezados con cabecera contextual título › h2 › h3', () => {
    const raw = `# Doc\n\n## Alfa\n${para(60, 'alfa')}\n\n### Sub\n${para(60, 'sub')}\n\n## Beta\n${para(60, 'beta')}`;
    const chunks = chunkMarkdown('d.md', raw, opts);
    expect(chunks.map(c => c.heading)).toEqual(['Doc › Alfa', 'Doc › Alfa › Sub', 'Doc › Beta']);
    expect(chunks[1].embedText.startsWith('Doc › Alfa › Sub\n\n')).toBe(true);
    expect(chunks.map(c => c.id)).toEqual(['d.md#0', 'd.md#1', 'd.md#2']);
  });

  it('fusiona secciones cortas con la siguiente', () => {
    const raw = `# Doc\n\n## Corta\nuna línea\n\n## Larga\n${para(60)}`;
    const chunks = chunkMarkdown('d.md', raw, opts);
    expect(chunks).toHaveLength(1);
    expect(chunks[0].heading).toBe('Doc › Corta');
    expect(chunks[0].text).toContain('Larga');
  });

  it('parte secciones largas en ventanas ≤ max con solape', () => {
    const long = Array.from({ length: 40 }, (_, i) => `Frase número ${i} con algo de contenido para rellenar.`).join(' ');
    const chunks = chunkMarkdown('d.md', `# Doc\n\n${long}${long}`, { chunkChars: 600, overlap: 0.15, maxChars: 800 });
    expect(chunks.length).toBeGreaterThan(2);
    for (const c of chunks) expect(c.text.length).toBeLessThanOrEqual(800);
    // solape: el final de un chunk reaparece al inicio del siguiente
    const tail = chunks[0].text.slice(-40);
    expect(chunks[1].text.includes(tail.trim().split(' ').slice(-3).join(' '))).toBe(true);
  });

  it('no trata # dentro de bloques de código como encabezado', () => {
    const raw = `# Doc\n\n## Código\n\`\`\`bash\n# comentario\necho hola\n\`\`\`\n${para(50)}`;
    const chunks = chunkMarkdown('d.md', raw, opts);
    expect(chunks).toHaveLength(1);
    expect(chunks[0].heading).toBe('Doc › Código');
    expect(chunks[0].text).toContain('# comentario');
  });

  it('documento vacío no produce chunks', () => {
    expect(chunkMarkdown('e.md', '---\ntitle: x\n---\n', opts)).toEqual([]);
  });

  it('propaga metadatos a cada chunk', () => {
    const chunks = chunkMarkdown('d.md', `---\nstatus: superseded\n---\n# T\n${para(80)}`, opts);
    expect(chunks.every(c => c.meta.status === 'superseded')).toBe(true);
  });
});
