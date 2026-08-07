/* Conflict detection for SaviaVaults (SE-309).
 *
 * Detects contradictory facts: same (entity, property) with different values.
 * Never silently overwrites — each conflict is flagged with both sources.
 * Adopted from the graph-native accountability conflict detection pattern.
 */

import { randomUUID } from 'node:crypto';

export type ConflictSeverity = 'info' | 'warning' | 'critical';
export type ConflictStatus = 'open' | 'resolved';

export interface Conflict {
  id: string;
  entityId: string;
  property: string;
  valueA: string;
  valueB: string;
  sourceA: string;
  sourceB: string;
  severity: ConflictSeverity;
  status: ConflictStatus;
  resolution?: string;
}

interface NoteLike {
  path: string;
  frontmatter: Record<string, unknown>;
}

function extractEntity(fm: Record<string, unknown>): { id: string } | null {
  const entity = fm.entity as Record<string, unknown> | undefined;
  if (!entity || typeof entity !== 'object') return null;
  const id = entity.id;
  return id ? { id: String(id) } : null;
}

function extractFacts(fm: Record<string, unknown>): Array<{ property: string; value: string }> {
  const facts: Array<{ property: string; value: string }> = [];
  for (const [k, v] of Object.entries(fm)) {
    if (k === 'entity' || k === 'tags' || k === 'confidentiality' || k === 'title') continue;
    if (v === undefined || v === null) continue;
    facts.push({ property: k, value: String(v) });
  }
  return facts;
}

export function detectConflicts(notes: NoteLike[]): Conflict[] {
  // Map: `${entityId}:${property}` → list of {value, source}
  const index = new Map<string, Array<{ value: string; source: string }>>();
  const conflicts: Conflict[] = [];

  for (const n of notes) {
    const entity = extractEntity(n.frontmatter);
    if (!entity) continue;
    const facts = extractFacts(n.frontmatter);
    for (const fact of facts) {
      const key = `${entity.id}:${fact.property}`;
      const entry = index.get(key) ?? [];
      const existing = entry.find(e => e.value === fact.value);
      if (existing) {
        entry.push({ value: fact.value, source: n.path });
        index.set(key, entry);
        continue;
      }
      // Different value for same (entity, property) → conflict
      const first = entry[0];
      if (first) {
        conflicts.push({
          id: randomUUID(),
          entityId: entity.id,
          property: fact.property,
          valueA: first.value,
          valueB: fact.value,
          sourceA: first.source,
          sourceB: n.path,
          severity: 'warning',
          status: 'open',
        });
      }
      entry.push({ value: fact.value, source: n.path });
      index.set(key, entry);
    }
  }

  return conflicts;
}

export function resolveConflict(conflict: Conflict, resolution: string): Conflict {
  return {
    ...conflict,
    status: 'resolved',
    resolution,
  };
}
