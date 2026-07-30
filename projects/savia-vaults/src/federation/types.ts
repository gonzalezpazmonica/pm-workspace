// Federation types for SaviaVaults
export interface FederatedDome {
  id: string; name: string; url: string; authToken?: string;
  timeout: number; enabled: boolean; weight: number; tags: string[];
  lastHealthCheck?: string; status: 'healthy' | 'degraded' | 'unhealthy' | 'unknown';
}
export interface FederationConfig {
  domes: FederatedDome[]; localTimeout: number; maxTotalResults: number;
  dedupByContent: boolean; cacheTtlMs: number;
}
export interface FederatedSearchResult {
  path: string; score: number; snippet: string; tags: string[];
  source: string; contentHash: string;
}
export interface FederatedSearchResponse {
  results: FederatedSearchResult[];
  sources: Array<{ id: string; name: string; status: 'ok' | 'timeout' | 'error' | 'skipped'; count: number; latencyMs: number }>;
  totalMs: number;
}
