import { describe, it, expect } from 'vitest';
import type { Entity, EntityType, IntrospectResult } from '../../../packages/contracts/src/entities/entity.js';

describe('Entity types (compile-time)', () => {
  it('Entity type works', () => {
    const e: Entity = { type: 'document', id: 'd1', label: 'Doc', count: 10, properties: { title: { populated: 10, total: 10, coverage: 100 } } };
    expect(e.type).toBe('document');
  });

  it('EntityType union covers 11 types', () => {
    const types: EntityType[] = ['document', 'hypothesis', 'protocol', 'decision', 'system', 'person', 'project', 'experiment', 'result', 'event', 'organization'];
    expect(types).toHaveLength(11);
  });
});
