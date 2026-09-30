// SE-413 — Savia Files: tipos del almacén de ficheros y de la extracción con localizador

export type ExtractionStatus = 'PENDING' | 'READY' | 'PARTIAL' | 'FAILED' | 'ARCHIVE_ONLY' | 'QUARANTINED';

export interface ExtractionInfo {
  status: ExtractionStatus;
  method: string;
  units: number;
  extracted: number;
  skipped: { reason: string; count: number }[];
  error?: string;
  /** SE-414: SHA-256 del JSON de extracción; se verifica al leerla. */
  digest?: string;
}

/** SE-415: codificación de los ficheros de texto (se decodifica al extraer; la descarga es el original). */
export type TextEncoding = 'utf-8' | 'windows-1252';

export interface FileRevision {
  id: string;
  sha256: string;
  size: number;
  mime: string;
  type: FileType;
  encoding?: TextEncoding;
  /** SE-417: original y extracción cifrados con la DEK de esta revisión. */
  enc?: 1;
  /** SE-418: SHA-256 del blob cifrado (lo que referencia el ledger en cúpulas cifradas). */
  blobHash?: string;
  createdAt: string;
  extraction: ExtractionInfo;
}

export type Confidentiality = 'N1' | 'N2' | 'N3' | 'N4';

/** SE-419: listas que restringen el acceso a un documento (null o ausente = hereda de la cúpula). */
export interface DocumentAcl {
  readers?: string[] | null;
  writers?: string[] | null;
}

export interface FileDocument {
  id: string;
  name: string;
  tags: string[];
  confidentiality?: Confidentiality;
  /** SE-419 */
  acl?: DocumentAcl;
  /** SE-419: sube con cada cambio de política (control de concurrencia). */
  policyVersion?: number;
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
  /** SE-417: cifrar la cúpula (N3/N4 siempre, aunque falte o sea false). */
  encryption?: boolean;
  /** SE-421: límite de tamaño de fichero en esta cúpula (no puede superar el global). */
  maxBytes?: number;
}

export type FileType = 'pdf' | 'docx' | 'pptx' | 'xlsx' | 'txt' | 'md' | 'csv' | 'json' | 'unknown';

export interface FilesLimits {
  maxBytes: number;
  maxDocuments: number;
  extractTimeoutMs: number;
  maxTransferBytes: number;
  /** SE-414: suma máxima descomprimida declarada de un OOXML antes de lanzar el worker. */
  maxUnzippedBytes: number;
  /** SE-421: tamaño máximo que se extrae (texto); por encima, ARCHIVE_ONLY con too-large-to-extract. */
  maxExtractBytes: number;
  lockWaitMs: number;
}

export type FilesErrorCode =
  | 'NOT_FOUND' | 'INVALID_INPUT' | 'TOO_LARGE' | 'LIMIT' | 'LOCKED'
  | 'INTEGRITY' | 'POLICY_DENIED' | 'UNSAFE_HOME' | 'SCAN_REQUIRED' | 'DISABLED' | 'UNSUPPORTED' | 'KEY_MISSING'
  | 'COMMIT_PENDING' | 'IDEMPOTENCY_CONFLICT' | 'CONFLICT';

export class FilesError extends Error {
  constructor(public readonly code: FilesErrorCode, message: string) {
    super(`${code}: ${message}`);
    this.name = 'FilesError';
  }
}
