export interface SearchQuery {
  query: string;
  maxResults?: number;
  pathPrefix?: string;
}

export interface SearchResult {
  path: string;
  score: number;
  snippet: string;
  tags: string[];
}

export interface VaultStats {
  name: string;
  noteCount: number;
  totalSize: number;
  commitCount?: number;
}

export interface HealthReport {
  computed: string;
  coverage: Record<string, { populated: number; total: number; coverage: number }>;
  provenance: { assertionsWithSource: number };
  health: { expiredAssertions: number; openConflicts: number; orphanEntities: number; pendingRelations: number };
  freshness: { avgDaysSinceAssertion: number };
}
