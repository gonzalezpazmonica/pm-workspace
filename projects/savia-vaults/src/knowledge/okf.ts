// okf.ts — Open Knowledge Format (OKF v0.1) interop layer
// Reference: Google Cloud "Introducing the Open Knowledge Format" (2026-06-12)
// Spec: SE-307 — OKF Adapter para SaviaVaults

export interface OkfFrontmatter {
  type?: string;
  title?: string;
  description?: string;
  resource?: string;
  tags?: string[];
  timestamp?: string;
}

export interface OkfConformanceReport {
  conformant: boolean;
  violations: string[];
  warnings: string[];
  noteCount: number;
  checkedAt: string;
}

export const OKF_REQUIRED_FIELDS = ['type'] as const;
export const OKF_OPTIONAL_FIELDS = ['title', 'description', 'resource', 'tags', 'timestamp'] as const;
export const OKF_RESERVED_FILENAMES = ['index.md', 'log.md'] as const;

export function validateOkfFrontmatter(
  fm: Record<string, unknown>,
  notePath: string,
): OkfConformanceReport {
  const violations: string[] = [];
  const warnings: string[] = [];

  const baseName = notePath.split('/').pop() || '';
  const isReserved = (OKF_RESERVED_FILENAMES as readonly string[]).includes(baseName);

  if (!isReserved) {
    if (!fm.type || typeof fm.type !== 'string' || fm.type.trim() === '') {
      violations.push(`[${notePath}] missing required field: type`);
    }
  }

  if (fm.timestamp !== undefined && fm.timestamp !== null) {
    if (typeof fm.timestamp !== 'string' || isNaN(Date.parse(fm.timestamp))) {
      violations.push(`[${notePath}] invalid timestamp: ${String(fm.timestamp)}`);
    }
  }

  const known = new Set([...OKF_REQUIRED_FIELDS, ...OKF_OPTIONAL_FIELDS]);
  const unknownFields = Object.keys(fm).filter(k => !known.has(k));
  for (const u of unknownFields) {
    warnings.push(`[${notePath}] non-OKF field present: ${u}`);
  }

  if (isReserved) {
    warnings.push(`[${notePath}] reserved filename used; ${baseName} has special meaning in OKF`);
  }

  return {
    conformant: violations.length === 0,
    violations,
    warnings,
    noteCount: 0,
    checkedAt: new Date().toISOString(),
  };
}

export function convertWikiLinksToMarkdown(content: string): string {
  return content.replace(
    /\[\[([^\]]+)\]\]/g,
    (_, inner: string) => {
      const parts = inner.split('|');
      const target = (parts[0] ?? inner).trim();
      const label = (parts[1] ?? target).trim();
      const mdPath = target.replace(/\.md$/, '') + '.md';
      return `[${label}](${mdPath})`;
    },
  );
}

export function convertMarkdownLinksToWikiLinks(content: string): string {
  return content.replace(
    /\[([^\]]+)\]\(([^)]+)\.md\)/g,
    (_, label: string, target: string) => `[[${target}|${label}]]`,
  );
}

export function inferOkfType(notePath: string, fm: Record<string, unknown>): string {
  const base = notePath.split('/').pop() || '';
  const tags = Array.isArray(fm.tags) ? fm.tags.map(String) : [];
  const fullPath = notePath.toLowerCase();

  if (tags.some(t => t.toLowerCase() === 'metric')) return 'Metric';
  if (base.includes('table') || base.includes('_db')) return 'BigQuery Table';
  if (fullPath.includes('runbook')) return 'Runbook';
  if (fullPath.includes('/api/') || base.includes('api')) return 'API';
  if (fullPath.includes('/metric/')) return 'Metric';
  return 'Concept';
}

export function serializeOkfNote(fm: Record<string, unknown>, content: string): string {
  const fmLines = Object.entries(fm)
    .filter(([k]) => k !== 'created' && k !== 'modified')
    .map(([k, v]) => {
      if (Array.isArray(v)) return `${k}: [${v.map(String).join(', ')}]`;
      if (typeof v === 'string') return `${k}: ${v}`;
      if (typeof v === 'boolean') return `${k}: ${v}`;
      if (typeof v === 'number') return `${k}: ${v}`;
      return `${k}: ${JSON.stringify(v)}`;
    });
  return `---\n${fmLines.join('\n')}\n---\n\n${content}`;
}

export function parseOkfFrontmatter(raw: string): { frontmatter: Record<string, unknown>; content: string } {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content: raw };
  return { frontmatter: {}, content: raw };
}
