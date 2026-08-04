// okf-import.ts — Import an OKF v0.1 bundle into a SaviaVaults dome

import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import type { VaultStorage } from '../storage/index.js';
import {
  validateOkfFrontmatter,
  convertMarkdownLinksToWikiLinks,
  serializeOkfNote,
  parseOkfFrontmatter,
} from './okf.js';

export interface OkfImportOptions {
  sourceDir: string;
  stripPrefix?: string;
  validateFirst?: boolean;
  force?: boolean;
}

export async function importOkfBundle(
  storage: VaultStorage,
  opts: OkfImportOptions,
): Promise<{ imported: number; rejected: string[] }> {
  const rejected: string[] = [];
  let imported = 0;

  let files: string[];
  try {
    files = await walkDir(opts.sourceDir);
  } catch {
    return { imported, rejected: ['source dir not readable'] };
  }

  for (const relPath of files) {
    const baseName = relPath.split('/').pop() || '';
    if (baseName === 'index.md' || baseName === 'log.md') continue;

    const raw = await fs.readFile(path.join(opts.sourceDir, relPath), 'utf-8');
    const { frontmatter, content } = parseOkfFrontmatter(raw);

    const report = validateOkfFrontmatter(frontmatter, relPath);
    if (opts.validateFirst !== false && !report.conformant) {
      rejected.push(`${relPath}: ${report.violations.join('; ')}`);
      continue;
    }

    let destPath = relPath;
    if (opts.stripPrefix && relPath.startsWith(opts.stripPrefix)) {
      destPath = relPath.slice(opts.stripPrefix.length);
    }

    const existing = await storage.read(destPath).catch(() => null);
    if (existing && !opts.force) {
      rejected.push(`${relPath}: already exists (use --force to overwrite)`);
      continue;
    }

    const converted = convertMarkdownLinksToWikiLinks(content);
    const noteContent = serializeOkfNote(frontmatter, converted);
    await storage.write(destPath, noteContent);
    imported++;
  }

  return { imported, rejected };
}

async function walkDir(dir: string): Promise<string[]> {
  const results: string[] = [];
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const e of entries) {
    const rel = e.name;
    if (e.isDirectory()) {
      const sub = await walkDir(path.join(dir, rel));
      for (const s of sub) results.push(path.join(rel, s));
    } else if (e.isFile() && rel.endsWith('.md')) {
      results.push(rel);
    }
  }
  return results.sort();
}
