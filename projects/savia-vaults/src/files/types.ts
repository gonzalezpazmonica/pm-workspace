// SE-413 — Savia Files: tipos del almacén de ficheros y de la extracción con localizador

export type ExtractionStatus = 'PENDING' | 'READY' | 'PARTIAL' | 'FAILED' | 'ARCHIVE_ONLY' | 'QUARANTINED';

export interface ExtractionInfo {
  status: ExtractionStatus;
  method: string;
  units: number;
  extracted: number;
  skipped: { reason: string; count: number }[];
  error?: string;
}

export interface FileRevision {
  id: string;
  sha256: string;
  size: number;
  mime: string;
  type: FileType;
  createdAt: string;
  extraction: ExtractionInfo;
}

export type Confidentiality = 'N1' | 'N2' | 'N3' | 'N4';

export interface FileDocument {
  id: string;
  name: string;
  tags: string[];
  confidentiality?: Confidentiality;
  createdAt: string;
  updatedAt: string;
  currentRevision: string;
  revisions: FileRevision[];
}

export type Locator =
  | { type: 'page'; page: number }
  | { type: 'slide'; slide: number }
  | { type: 'element'; index: number }
  | { type: 'cell'; sheet: string; cell: string }
  | { type: 'lines'; from: number; to: number }
  | { type: 'row'; row: number }
  | { type: 'key'; path: string };

export interface ExtractUnit {
  locator: Locator;
  kind: string;
  text: string;
  formula?: string;
}

export interface Extraction {
  units: ExtractUnit[];
}

/** Bloque opcional `files` de una cúpula en savia-vaults.domes.json (desactivado por defecto). */
export interface FilesDomeConfig {
  enabled?: boolean;
  scan?: 'auto' | 'required' | 'off';
}

export type FileType = 'pdf' | 'docx' | 'pptx' | 'xlsx' | 'txt' | 'md' | 'csv' | 'json' | 'unknown';

export interface FilesLimits {
  maxBytes: number;
  maxDocuments: number;
  extractTimeoutMs: number;
  maxTransferBytes: number;
}

export type FilesErrorCode =
  | 'NOT_FOUND' | 'INVALID_INPUT' | 'TOO_LARGE' | 'LIMIT' | 'LOCKED'
  | 'INTEGRITY' | 'POLICY_DENIED' | 'UNSAFE_HOME' | 'SCAN_REQUIRED' | 'DISABLED';

export class FilesError extends Error {
  constructor(public readonly code: FilesErrorCode, message: string) {
    super(`${code}: ${message}`);
    this.name = 'FilesError';
  }
}
