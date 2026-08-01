import * as fs from 'node:fs';
import * as path from 'node:path';
import YAML from 'yaml';

interface PropertyDef {
  type: string;
  required?: boolean;
  vocabulary?: string[];
  pattern?: string;
  description?: string;
}

interface EntitySchema {
  type: string;
  label: string;
  description: string;
  properties: Record<string, PropertyDef>;
}

export interface ValidationError {
  field: string;
  value: unknown;
  rule: string;
}

export class SchemaRegistry {
  private schemas: Map<string, EntitySchema> = new Map();
  private schemaDir: string;

  constructor(schemaDir: string) {
    this.schemaDir = schemaDir;
    this.loadAll();
  }

  private loadAll(): void {
    if (!fs.existsSync(this.schemaDir)) return;
    const files = fs.readdirSync(this.schemaDir).filter(f => f.endsWith('.yaml') || f.endsWith('.yml'));
    for (const f of files) {
      try {
        const raw = fs.readFileSync(path.join(this.schemaDir, f), 'utf-8');
        const schema = YAML.parse(raw) as EntitySchema;
        if (schema?.type && schema?.properties) {
          this.schemas.set(schema.type, schema);
        }
      } catch {}
    }
  }

  getSchema(entityType: string): EntitySchema | undefined {
    return this.schemas.get(entityType);
  }

  listTypes(): string[] {
    return [...this.schemas.keys()];
  }

  getTypeInfo(entityType: string): { label: string; description: string; propertyCount: number } | undefined {
    const s = this.schemas.get(entityType);
    if (!s) return undefined;
    return { label: s.label, description: s.description, propertyCount: Object.keys(s.properties).length };
  }

  validate(entityType: string, properties: Record<string, unknown>): ValidationError[] {
    const schema = this.schemas.get(entityType);
    if (!schema) {
      const available = this.listTypes().join(', ');
      return [{ field: 'entity.type', value: entityType, rule: `Unknown entity type. Available: ${available}` }];
    }

    const errors: ValidationError[] = [];

    for (const [propName, propDef] of Object.entries(schema.properties)) {
      const value = properties[propName];

      if (propDef.required && (value === undefined || value === null || value === '')) {
        errors.push({ field: propName, value: value ?? null, rule: `Required property for ${entityType}` });
        continue;
      }

      if (value === undefined || value === null || value === '') continue;

      if (propDef.type === 'number' && typeof value !== 'number') {
        errors.push({ field: propName, value, rule: 'Must be a number' });
      }

      if (propDef.vocabulary && Array.isArray(propDef.vocabulary) && !propDef.vocabulary.includes(String(value))) {
        errors.push({ field: propName, value, rule: `Must be one of: ${propDef.vocabulary.join(', ')}` });
      }

      if (propDef.pattern) {
        try {
          const re = new RegExp(propDef.pattern);
          if (!re.test(String(value))) {
            errors.push({ field: propName, value, rule: `Must match pattern: ${propDef.pattern}` });
          }
        } catch {}
      }
    }

    return errors;
  }

  resolveAliases(name: string, frontmatter: Record<string, unknown>): string[] {
    const aliases = new Set<string>();
    if (typeof name === 'string' && name) aliases.add(name.toLowerCase());
    if (frontmatter.title && typeof frontmatter.title === 'string') aliases.add(frontmatter.title.toLowerCase());
    if (frontmatter.name && typeof frontmatter.name === 'string') aliases.add(frontmatter.name.toLowerCase());
    if (Array.isArray(frontmatter.aliases)) {
      for (const a of frontmatter.aliases) {
        if (typeof a === 'string') aliases.add(a.toLowerCase());
      }
    }
    return [...aliases];
  }
}
