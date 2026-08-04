// okf-export.ts — Export a SaviaVaults dome as an OKF v0.1 bundle

import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import type { VaultStorage } from '../storage/index.js';
import {
  validateOkfFrontmatter,
  convertWikiLinksToMarkdown,
  inferOkfType,
  serializeOkfNote,
  parseOkfFrontmatter,
} from './okf.js';

export interface OkfExportOptions {
  includeIndexFiles?: boolean;
  includeLogFiles?: boolean;
}

export async function exportOkfBundle(
  storage: VaultStorage,
  outputDir: string,
  opts: OkfExportOptions = {},
): Promise<{ exported: number; skipped: string[] }> {
  const notes = await storage.list();
  const skipped: string[] = [];
  let exported = 0;

  await fs.mkdir(outputDir, { recursive: true });

  for (const notePath of notes) {
    const baseName = notePath.split('/').pop() || '';
    if (baseName === 'index.md' || baseName === 'log.md') {
      if (!opts.includeIndexFiles && baseName === 'index.md') continue;
      if (!opts.includeLogFiles && baseName === 'log.md') continue;
    }

    const note = await storage.read(notePath).catch(() => null);
    if (!note) continue;

    // Robust frontmatter handling: VaultStorage.parseFrontmatter falls back to
    // {frontmatter: {}, content: raw} when YAML.js can't parse the block (e.g.
    // a title containing ':' breaks flow mapping detection). In that case the
    // frontmatter is still inside note.content — re-extract it.
    let fm = { ...note.frontmatter } as Record<string, unknown>;
    let body = note.content;
    if (Object.keys(fm).length === 0 && body.startsWith('---')) {
      const parsed = parseOkfFrontmatter(body);
      fm = parsed.frontmatter;
      body = parsed.content;
    }

    const convertedContent = convertWikiLinksToMarkdown(body);

    if (fm.timestamp === undefined || fm.timestamp === null) {
      fm.timestamp = note.modified;
    }
    if (!fm.type) {
      fm.type = inferOkfType(notePath, fm);
      skipped.push(`${notePath}: type inferido como '${fm.type}'`);
    }

    const report = validateOkfFrontmatter(fm, notePath);
    if (!report.conformant) {
      skipped.push(`${notePath}: ${report.violations.join('; ')}`);
      continue;
    }

    const destPath = path.join(outputDir, notePath);
    await fs.mkdir(path.dirname(destPath), { recursive: true });
    await fs.writeFile(destPath, serializeOkfNote(fm, convertedContent), 'utf-8');
    exported++;
  }

  return { exported, skipped };
}
