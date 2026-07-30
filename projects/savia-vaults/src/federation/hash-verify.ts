// Content hash verification for federated results (SE-283 Slice 5)
import type { FederatedSearchResult } from './types.js';

export function hashContent(content: string): string {
  let hash = 0;
  for (let i = 0; i < content.length; i++) { hash = ((hash << 5) - hash) + content.charCodeAt(i); hash = hash & hash; }
  return Math.abs(hash).toString(16).padStart(8, '0');
}

export function verifyContentHash(result: FederatedSearchResult): boolean {
  if (!result.snippet) return false;
  return hashContent(result.snippet) === result.contentHash;
}

export function filterTamperedResults(results: FederatedSearchResult[]): FederatedSearchResult[] {
  return results.filter(r => verifyContentHash(r));
}
