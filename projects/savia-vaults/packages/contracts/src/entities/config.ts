export interface VaultConfig {
  name: string;
  path: string;
  allowedExtensions: string[];
  deniedPaths: string[];
  maxDepth: number;
  maxFileSize: number;
  schemaDir?: string;
}

export interface DomeConfig {
  name: string;
  path: string;
  description?: string;
  confidentiality: 'N1' | 'N2' | 'N3' | 'N4a' | 'N4b';
  schemaDir?: string;
}
