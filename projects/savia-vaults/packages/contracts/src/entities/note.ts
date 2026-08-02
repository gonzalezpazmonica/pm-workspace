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

export interface Receipt {
  vault: string;
  path: string;
  contentHash: string;
  signature: string;
  timestamp: string;
}

export interface CommitEntry {
  hash: string;
  date: string;
  message: string;
}
