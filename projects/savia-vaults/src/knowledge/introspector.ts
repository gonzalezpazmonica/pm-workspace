import { SchemaRegistry } from '../schema/registry.js';
import { SearchEngine } from '../search/index.js';
import { VaultStorage } from '../storage/index.js';
import type { VaultConfig } from '../types.js';

interface TypeCoverage {
  type: string;
  label: string;
  count: number;
  properties: Record<string, { populated: number; total: number; coverage: number }>;
}

interface VaultIntrospection {
  vault: string;
  entityTypes: TypeCoverage[];
  totalDocuments: number;
  totalEntities: number;
  schemaTypes: string[];
  lastIndexed: string;
}

interface EntityIntrospection {
  path: string;
  type: string;
  id: string;
  populatedProperties: Record<string, unknown>;
  missingProperties: string[];
  aliasCount: number;
}

export class Introspector {
  private registry: SchemaRegistry;
  private search: SearchEngine;
  private storage: VaultStorage;

  constructor(config: VaultConfig) {
    this.registry = new SchemaRegistry(config.schemaDir || '');
    this.search = new SearchEngine(config);
    this.storage = new VaultStorage(config);
  }

  async introspectVault(): Promise<VaultIntrospection> {
    this.search.buildIndex();
    const files = await this.storage.list();
    const entities: { path: string; type: string; frontmatter: Record<string, unknown> }[] = [];

    for (const f of files) {
      try {
        const note = await this.storage.read(f);
        if (note.frontmatter.entity && typeof note.frontmatter.entity === 'object') {
          const entity = note.frontmatter.entity as Record<string, unknown>;
          entities.push({ path: f, type: entity.type as string || 'unknown', frontmatter: note.frontmatter });
        }
      } catch {}
    }

    const typeMap = new Map<string, { label: string; count: number; props: Map<string, number> }>();
    const schemaTypes = this.registry.listTypes();

    for (const e of entities) {
      let entry = typeMap.get(e.type);
      if (!entry) {
        const info = this.registry.getTypeInfo(e.type);
        entry = { label: info?.label || e.type, count: 0, props: new Map() };
        typeMap.set(e.type, entry);
      }
      entry.count++;
      for (const key of Object.keys(e.frontmatter)) {
        if (e.frontmatter[key] !== undefined && e.frontmatter[key] !== '' && key !== 'entity') {
          entry.props.set(key, (entry.props.get(key) || 0) + 1);
        }
      }
    }

    const typeCoverages: TypeCoverage[] = [];
    for (const [type, entry] of typeMap) {
      const schema = this.registry.getSchema(type);
      const properties: Record<string, { populated: number; total: number; coverage: number }> = {};
      if (schema) {
        for (const [propName] of Object.entries(schema.properties)) {
          const populated = entry.props.get(propName) || 0;
          properties[propName] = {
            populated,
            total: entry.count,
            coverage: entry.count > 0 ? Math.round((populated / entry.count) * 100) : 0,
          };
        }
      }
      typeCoverages.push({ type, label: entry.label, count: entry.count, properties });
    }

    return {
      vault: this.storage['config']?.name || 'unknown',
      entityTypes: typeCoverages,
      totalDocuments: files.length,
      totalEntities: entities.length,
      schemaTypes,
      lastIndexed: new Date().toISOString(),
    };
  }

  async introspectEntity(path: string): Promise<EntityIntrospection | null> {
    try {
      const note = await this.storage.read(path);
      const entity = note.frontmatter.entity as Record<string, unknown> | undefined;
      if (!entity || !entity.type) return null;

      const schema = this.registry.getSchema(entity.type as string);
      const populatedProperties: Record<string, unknown> = {};
      const missingProperties: string[] = [];

      if (schema) {
        for (const [propName, propDef] of Object.entries(schema.properties)) {
          const value = note.frontmatter[propName];
          if (value !== undefined && value !== null && value !== '') {
            populatedProperties[propName] = value;
          } else if (propDef.required) {
            missingProperties.push(propName);
          }
        }
      }

      const aliases = this.registry.resolveAliases(
        (entity.id as string) || note.name,
        note.frontmatter
      );

      return {
        path,
        type: entity.type as string,
        id: (entity.id as string) || note.name,
        populatedProperties,
        missingProperties,
        aliasCount: aliases.length,
      };
    } catch {
      return null;
    }
  }
}
