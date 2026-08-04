// okf-conformance.ts — Check a vault for OKF v0.1 conformance

import type { VaultStorage } from '../storage/index.js';
import { validateOkfFrontmatter, type OkfConformanceReport } from './okf.js';

export async function checkOkfConformance(
  storage: VaultStorage,
): Promise<OkfConformanceReport> {
  const notes = await storage.list();
  const violations: string[] = [];
  const warnings: string[] = [];

  for (const notePath of notes) {
    const baseName = notePath.split('/').pop() || '';
    if (baseName === 'index.md' || baseName === 'log.md') continue;

    const note = await storage.read(notePath).catch(() => null);
    if (!note) continue;

    const report = validateOkfFrontmatter(note.frontmatter as Record<string, unknown>, notePath);
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
