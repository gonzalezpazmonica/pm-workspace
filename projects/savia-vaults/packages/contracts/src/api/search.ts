export interface VaultSearchParams {
  vault?: string;
  query: string;
  maxResults?: number;
  pathPrefix?: string;
}

export interface VaultSearchResultItem {
  path: string;
  score: number;
  snippet: string;
  tags: string[];
}
