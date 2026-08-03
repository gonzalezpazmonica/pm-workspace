export type EntityType =
  | 'document' | 'hypothesis' | 'protocol' | 'decision'
  | 'system' | 'person' | 'project' | 'experiment'
  | 'result' | 'event' | 'organization';

export interface Entity {
  type: EntityType;
  id: string;
  label: string;
  count: number;
  properties: Record<string, EntityProperty>;
}

export interface EntityProperty {
  populated: number;
  total: number;
  coverage: number;
}

export interface IntrospectResult {
  vault: string;
  entityTypes: Entity[];
  totalDocuments: number;
  totalEntities: number;
  schemaTypes: string[];
  lastIndexed: string;
}
