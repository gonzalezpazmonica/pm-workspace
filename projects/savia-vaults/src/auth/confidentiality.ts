import type { ConfidentialityLevel, DomeInfo } from '../registry/domes.js';

export interface ConfidentialityAudit {
  dome: string;
  level: ConfidentialityLevel;
  description: string;
  active: boolean;
}

export class ConfidentialityGuard {
  static audit(domes: DomeInfo[]): ConfidentialityAudit[] {
    return domes
      .sort((a, b) => {
        const order: Record<string, number> = { N4: 4, N3: 3, N2: 2, N1: 1 };
        return (order[b.confidentiality] || 0) - (order[a.confidentiality] || 0);
      })
      .map(d => ({
        dome: d.name,
        level: d.confidentiality,
        description: d.description,
        active: d.active,
      }));
  }

  static formatAudit(audits: ConfidentialityAudit[]): string {
    const lines = ['Dome Confidentiality Audit', '═'.repeat(60)];
    for (const a of audits) {
      const icon = a.level === 'N4' ? '🔴' : a.level === 'N3' ? '🟠' : a.level === 'N2' ? '🟡' : '🟢';
      const status = a.active ? 'active' : 'inactive';
      lines.push(`  ${icon} ${a.dome.padEnd(20)} [${a.level}] ${status.padEnd(10)} ${a.description}`);
    }
    return lines.join('\n');
  }
}
