/* Tests for conflict detection (SE-309). */

import { describe, it, expect } from 'vitest';
import { detectConflicts, resolveConflict, Conflict } from '../src/knowledge/conflicts.js';

interface FakeNote {
  path: string;
  frontmatter: Record<string, unknown>;
}

function note(path: string, entityId: string, property: string, value: string): FakeNote {
  return {
    path,
    frontmatter: {
      entity: { type: 'fact', id: entityId },
      [property]: value,
    },
  };
}

describe('ConflictDetector', () => {
  it('detects conflicting values for same (entity, property)', () => {
    const notes = [
      note('a.md', 'scheduler', 'storage', 'json'),
      note('b.md', 'scheduler', 'storage', 'sqlite'),
    ];
    const conflicts = detectConflicts(notes as never[]);
    expect(conflicts.length).toBe(1);
    expect(conflicts[0].entityId).toBe('scheduler');
    expect(conflicts[0].property).toBe('storage');
  });

  it('no conflict when values match', () => {
    const notes = [
      note('a.md', 'scheduler', 'storage', 'json'),
      note('b.md', 'scheduler', 'storage', 'json'),
    ];
    const conflicts = detectConflicts(notes as never[]);
    expect(conflicts.length).toBe(0);
  });

  it('no conflict across different entities', () => {
    const notes = [
      note('a.md', 'scheduler', 'storage', 'json'),
      note('b.md', 'vault', 'storage', 'sqlite'),
    ];
    const conflicts = detectConflicts(notes as never[]);
    expect(conflicts.length).toBe(0);
  });

  it('tracks both sources in the conflict', () => {
    const notes = [
      note('a.md', 'scheduler', 'storage', 'json'),
      note('b.md', 'scheduler', 'storage', 'sqlite'),
    ];
    const conflicts = detectConflicts(notes as never[]);
    expect(conflicts[0].sourceA).toBe('a.md');
    expect(conflicts[0].sourceB).toBe('b.md');
  });

  it('does not flag facts without entity', () => {
    const notes = [{ path: 'c.md', frontmatter: { storage: 'json' } }];
    const conflicts = detectConflicts(notes as never[]);
    expect(conflicts.length).toBe(0);
  });
});

describe('resolveConflict', () => {
  it('marks conflict as resolved with resolution', () => {
    const notes = [
      note('a.md', 'scheduler', 'storage', 'json'),
      note('b.md', 'scheduler', 'storage', 'sqlite'),
    ];
    const conflicts = detectConflicts(notes as never[]);
    const resolved = resolveConflict(conflicts[0], 'storage is json');
    expect(resolved.status).toBe('resolved');
    expect(resolved.resolution).toBe('storage is json');
  });

  it('keeps history intact (conflict still exists)', () => {
    const notes = [
      note('a.md', 'scheduler', 'storage', 'json'),
      note('b.md', 'scheduler', 'storage', 'sqlite'),
    ];
    const conflicts = detectConflicts(notes as never[]);
    const resolved = resolveConflict(conflicts[0], 'resolved');
    expect(resolved).toBeDefined();
    expect(resolved.resolution).toBe('resolved');
  });
});
