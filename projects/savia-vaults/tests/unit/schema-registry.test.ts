import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { SchemaRegistry } from '../../src/schema/registry.js';

describe('SchemaRegistry', () => {
  let tmpDir: string;
  let registry: SchemaRegistry;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-schema-test-'));
    fs.writeFileSync(path.join(tmpDir, 'person.yaml'), [
      'type: person',
      'label: Persona',
      'properties:',
      '  name:',
      '    type: string',
      '    required: true',
      '  role:',
      '    type: string',
      '    vocabulary: [dev, lead, architect]',
      '  email:',
      '    type: string',
      '    pattern: "^[^@]+@[^@]+$"',
    ].join('\n'));

    fs.writeFileSync(path.join(tmpDir, 'project.yaml'), [
      'type: project',
      'label: Proyecto',
      'properties:',
      '  name:',
      '    type: string',
      '    required: true',
      '  status:',
      '    type: string',
      '    vocabulary: [active, completed, archived]',
    ].join('\n'));

    registry = new SchemaRegistry(tmpDir);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('loads entity schemas from directory', () => {
    expect(registry.listTypes()).toContain('person');
    expect(registry.listTypes()).toContain('project');
  });

  it('validates required properties', () => {
    const errors = registry.validate('person', {});
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].field).toBe('name');
  });

  it('passes valid entity', () => {
    const errors = registry.validate('person', { name: 'Alice' });
    expect(errors.length).toBe(0);
  });

  it('rejects invalid vocabulary value', () => {
    const errors = registry.validate('person', { name: 'Alice', role: 'invalid-role' });
    expect(errors.some(e => e.field === 'role')).toBe(true);
  });

  it('accepts valid vocabulary value', () => {
    const errors = registry.validate('person', { name: 'Alice', role: 'dev' });
    expect(errors.length).toBe(0);
  });

  it('validates pattern', () => {
    const errors = registry.validate('person', { name: 'Alice', email: 'not-an-email' });
    expect(errors.some(e => e.field === 'email')).toBe(true);
  });

  it('rejects unknown entity type', () => {
    const errors = registry.validate('nonexistent', {});
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].field).toBe('entity.type');
  });

  it('provides type info', () => {
    const info = registry.getTypeInfo('person');
    expect(info).toBeDefined();
    expect(info!.label).toBe('Persona');
    expect(info!.propertyCount).toBeGreaterThan(0);
  });

  it('resolves aliases from frontmatter', () => {
    const aliases = registry.resolveAliases('Alice', { title: 'Alice Smith', aliases: ['A. Smith', 'AS'] });
    expect(aliases).toContain('alice');
    expect(aliases).toContain('alice smith');
    expect(aliases).toContain('a. smith');
  });

  it('documents without entity type pass through', () => {
    const info = registry.getTypeInfo('nonexistent');
    expect(info).toBeUndefined();
  });
});
