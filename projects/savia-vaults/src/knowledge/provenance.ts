import { VaultStorage } from '../storage/index.js';
import { signContent, verifySignature } from '../security/index.js';
import type { VaultConfig } from '../types.js';

export interface Assertion {
  property: string;
  value: unknown;
  source: string;
  sourceType: 'primary' | 'derived' | 'secondary' | 'unverified';
  assertedAt: string;
  validFrom?: string;
  validUntil?: string;
  signature?: string;
}

export interface NumericObservation {
  value: number;
  unit: string;
  taxonomy: string;
  cadence: 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'annual' | 'once';
  assertedAt: string;
  validFrom?: string;
  validUntil?: string;
}

export interface ConflictReport {
  entity: string;
  property: string;
  assertions: Assertion[];
}

export class ProvenanceEngine {
  private storage: VaultStorage;
  private static readonly SOURCE_HIERARCHY: Record<string, number> = {
    primary: 4,
    derived: 3,
    secondary: 2,
    unverified: 1,
  };

  constructor(config: VaultConfig) {
    this.storage = new VaultStorage(config);
  }

  async extractAssertions(path: string): Promise<Assertion[]> {
    const assertions: Assertion[] = [];
    try {
      const note = await this.storage.read(path);
      const frontmatter = note.frontmatter;

      const defaults = {
        source: path,
        sourceType: (frontmatter.source_type as string) || 'unverified',
        assertedAt: frontmatter.created || new Date().toISOString(),
      };

      if (Array.isArray(frontmatter.assertions)) {
        for (const a of frontmatter.assertions as Record<string, unknown>[]) {
          assertions.push({
            property: a.property as string,
            value: a.value,
            source: (a.source as string) || defaults.source,
            sourceType: (a.sourceType as Assertion['sourceType']) || defaults.sourceType as Assertion['sourceType'],
            assertedAt: (a.assertedAt as string) || defaults.assertedAt,
            validFrom: a.validFrom as string | undefined,
            validUntil: a.validUntil as string | undefined,
            signature: a.signature as string | undefined,
          });
        }
      }

      if (Array.isArray(frontmatter.observations)) {
        for (const o of frontmatter.observations as Record<string, unknown>[]) {
          if (!o.value || !o.unit) {
            throw new Error(`Numeric observation in ${path} missing value or unit`);
          }
          assertions.push({
            property: o.property as string || 'observation',
            value: o.value,
            source: (o.source as string) || defaults.source,
            sourceType: (o.sourceType as Assertion['sourceType']) || defaults.sourceType as Assertion['sourceType'],
            assertedAt: (o.assertedAt as string) || defaults.assertedAt,
            validFrom: o.validFrom as string | undefined,
            validUntil: o.validUntil as string | undefined,
          });
        }
      }
    } catch {}
    return assertions;
  }

  findConflicts(entityId: string, assertions: Assertion[]): ConflictReport[] {
    const byProperty = new Map<string, Assertion[]>();
    for (const a of assertions) {
      const key = `${entityId}:${a.property}`;
      if (!byProperty.has(key)) byProperty.set(key, []);
      byProperty.get(key)!.push(a);
    }

    const conflicts: ConflictReport[] = [];
    for (const [key, group] of byProperty) {
      if (group.length < 2) continue;
      const values = new Set(group.map(a => JSON.stringify(a.value)));
      if (values.size > 1) {
        conflicts.push({
          entity: entityId,
          property: key.split(':')[1],
          assertions: group,
        });
      }
    }
    return conflicts;
  }

  resolveAuthority(assertions: Assertion[]): Assertion | ConflictReport | null {
    if (assertions.length === 0) return null;
    if (assertions.length === 1) return assertions[0];

    const conflicts = this.findConflicts(assertions[0].property, assertions);
    if (conflicts.length > 0) return conflicts[0];

    return assertions.sort((a, b) =>
      (ProvenanceEngine.SOURCE_HIERARCHY[b.sourceType] || 0) -
      (ProvenanceEngine.SOURCE_HIERARCHY[a.sourceType] || 0)
    )[0];
  }

  async signAssertion(assertion: Assertion): Promise<string> {
    const content = JSON.stringify({
      property: assertion.property,
      value: assertion.value,
      source: assertion.source,
      assertedAt: assertion.assertedAt,
    });
    return signContent(content);
  }

  verifyAssertion(assertion: Assertion): boolean {
    if (!assertion.signature) return false;
    const content = JSON.stringify({
      property: assertion.property,
      value: assertion.value,
      source: assertion.source,
      assertedAt: assertion.assertedAt,
    });
    return verifySignature(content, assertion.signature);
  }
}
