export interface VaultReadParams {
  vault?: string;
  path: string;
}

export interface VaultReadResult {
  path: string;
  name: string;
  frontmatter: Record<string, unknown>;
  tags: string[];
  content: string;
}
