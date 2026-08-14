// Core types for SaviaVaults

export interface VaultConfig {
  name: string;
  path: string;
  allowedExtensions: string[];
  deniedPaths: string[];
  maxDepth: number;
  maxFileSize: number;
  schemaDir?: string;
}

export interface Frontmatter {
  title?: string;
  tags?: string[];
  created?: string;
  modified?: string;
  [key: string]: unknown;
}

export interface Note {
  path: string;
  name: string;
  frontmatter: Frontmatter;
  tags: string[];
  content: string;
  created: string;
  modified: string;
}

export interface SearchQuery {
  query: string;
  maxResults?: number;
  pathPrefix?: string;
  /** SE-330: enriquecer con score del grafo (context enrichment). */
  enrich?: boolean;
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

export interface CommitEntry {
  hash: string;
  date: string;
  message: string;
}

export interface Receipt {
  vault: string;
  path: string;
  contentHash: string;
  signature: string;
  timestamp: string;
}
