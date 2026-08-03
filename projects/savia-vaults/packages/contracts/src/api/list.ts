export interface VaultListParams {
  vault?: string;
  path?: string;
}

export interface VaultListItem {
  path: string;
  type: 'file' | 'directory';
}
