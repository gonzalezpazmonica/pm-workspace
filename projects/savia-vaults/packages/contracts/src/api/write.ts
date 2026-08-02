export interface VaultWriteParams {
  vault?: string;
  path: string;
  content: string;
  message?: string;
}

export interface VaultWriteResult {
  vault: string;
  path: string;
  contentHash: string;
  signature: string;
  timestamp: string;
}
