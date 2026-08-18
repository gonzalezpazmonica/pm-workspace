// okf-conformance.ts — Check a vault for OKF v0.1 conformance

import * as fs from 'node:fs';
import * as path from 'node:path';
import type { VaultStorage } from '../storage/index.js';
import { validateOkfFrontmatter, parseOkfFrontmatter, type OkfConformanceReport } from './okf.js';

export async function checkOkfConformance(
  storage: VaultStorage,
  vaultPath?: string,
): Promise<OkfConformanceReport> {
  const notes = await storage.list();
  const violations: string[] = [];
  const warnings: string[] = [];

  for (const notePath of notes) {
    const baseName = path.posix.basename(notePath.replace(/\\/g, '/'));
    if (baseName === 'index.md' || baseName === 'log.md') continue;

    // Read raw file directly and use the robust parser. VaultStorage.read
    // depends on YAML.js which fails on legacy frontmatter (e.g. a title
    // containing ':' breaks flow-mapping detection), returning an empty
    // frontmatter and losing the type field.
    const fullPath = vaultPath ? path.join(vaultPath, notePath) : notePath;
    let raw: string;
    try {
      raw = fs.readFileSync(fullPath, 'utf-8');
    } catch {
      violations.push(`[${notePath}] unreadable file`);
      continue;
    }

    const { frontmatter } = parseOkfFrontmatter(raw);
    const report = validateOkfFrontmatter(frontmatter, notePath);
    violations.push(...report.violations);
    warnings.push(...report.warnings);
  }

  return {
    conformant: violations.length === 0,
    violations,
    warnings,
    noteCount: notes.length,
    checkedAt: new Date().toISOString(),
  };
}
