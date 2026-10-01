// SE-422 — protocolo tus 1.0 (https://tus.io/protocols/resumable-upload) sobre FilesService:
// núcleo + creation + creation-with-upload + termination + expiration + checksum (sha256).
// Sin estado en memoria: offset, longitud y caducidad viven en el journal de la cúpula.
import type { IncomingMessage, ServerResponse } from 'node:http';
import { FilesError } from '../files/types.js';
import type { FilesService, PutResult } from '../files/service.js';
import type { UploadMeta } from '../files/uploads.js';
import type { ScopedToken } from './grants.js';

export const TUS_VERSION = '1.0.0';
export const TUS_EXTENSIONS = 'creation,creation-with-upload,termination,expiration,checksum';
const OFFSET_CT = 'application/offset+octet-stream';
const META_KEYS = new Set(['filename', 'name', 'filetype', 'tags', 'confidentiality', 'replaces', 'idempotencyKey']);

export interface TusContext {
  svc: FilesService;
  dome: string;
  username: string;
  grant?: ScopedToken;
  maxBytes: number;
  expiresInMs?: number;
  /** Ruta base de las subidas (para Location), p. ej. /v1/files/<cúpula>/uploads */
  base: string;
  /** Justo antes de crear, ya validado todo (consume la autorización acotada de un solo uso). */
  beforeCreate?: () => Promise<void>;
  /** SE-423 AC3: envuelve el cuerpo de un PATCH para revalidar al usuario mientras llegan bytes. */
  fence?: (source: AsyncIterable<Uint8Array>) => AsyncIterable<Uint8Array>;
}

/** `Upload-Metadata`: pares `clave valor-base64` separados por comas. Claves desconocidas se ignoran. */
export function parseMetadata(header: string | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (!header) return out;
  if (header.length > 16 * 1024) throw new FilesError('INVALID_INPUT', 'Upload-Metadata demasiado grande');
  for (const pair of header.split(',')) {
    const [key, value, extra] = pair.trim().split(' ');
    if (!key || extra !== undefined || !/^[A-Za-z0-9_-]{1,64}$/.test(key)) throw new FilesError('INVALID_INPUT', 'Upload-Metadata mal formado');
    if (!META_KEYS.has(key) || value === undefined) continue;
    out[key] = Buffer.from(value, 'base64').toString('utf-8');
  }
  return out;
}

/** `Upload-Checksum: sha256 <base64>`. */
export function parseChecksum(header: string | undefined): { algorithm: 'sha256'; digest: Buffer } | undefined {
  if (header === undefined) return undefined;
  const [algo, value] = header.trim().split(' ');
  if (algo !== 'sha256') throw new FilesError('INVALID_INPUT', `Upload-Checksum: algoritmo no soportado (${String(algo).slice(0, 16)}); usa sha256`);
  const digest = Buffer.from(value ?? '', 'base64');
  if (digest.length !== 32) throw new FilesError('INVALID_INPUT', 'Upload-Checksum: digest sha256 no válido');
  return { algorithm: 'sha256', digest };
}

const intHeader = (v: string | string[] | undefined, name: string): number => {
  const s = Array.isArray(v) ? v[0] : v;
  if (s === undefined || !/^\d{1,16}$/.test(s)) throw new FilesError('INVALID_INPUT', `${name} debe ser un entero ≥ 0`);
  const n = Number(s);
  if (!Number.isSafeInteger(n)) throw new FilesError('INVALID_INPUT', `${name} demasiado grande`);
  return n;
};

const isOffsetBody = (req: IncomingMessage) => String(req.headers['content-type'] ?? '').split(';')[0].trim() === OFFSET_CT;

function common(res: ServerResponse): void {
  res.setHeader('Tus-Resumable', TUS_VERSION);
  res.setHeader('Cache-Control', 'no-store');
}

function completion(res: ServerResponse, r?: PutResult): void {
  if (!r) return;
  res.setHeader('Savia-Document-Id', r.documentId);
  if (r.operationId) res.setHeader('Savia-Operation-Id', r.operationId);
  res.setHeader('Savia-Status', r.status);
}

export function tusOptions(res: ServerResponse, maxBytes: number): void {
  res.statusCode = 204;
  res.setHeader('Tus-Resumable', TUS_VERSION);
  res.setHeader('Tus-Version', TUS_VERSION);
  res.setHeader('Tus-Extension', TUS_EXTENSIONS);
  res.setHeader('Tus-Max-Size', String(maxBytes));
  res.setHeader('Tus-Checksum-Algorithm', 'sha256');
  res.end();
}

/** Todas las peticiones tus salvo OPTIONS deben declarar la versión (412 si no). */
export function checkVersion(req: IncomingMessage, res: ServerResponse): boolean {
  if (req.headers['tus-resumable'] === TUS_VERSION) return true;
  res.statusCode = 412;
  res.setHeader('Tus-Version', TUS_VERSION);
  res.end();
  return false;
}

export async function tusCreate(req: IncomingMessage, res: ServerResponse, ctx: TusContext): Promise<void> {
  if (req.headers['upload-defer-length'] !== undefined) throw new FilesError('INVALID_INPUT', 'Upload-Defer-Length no está soportado');
  const length = intHeader(req.headers['upload-length'], 'Upload-Length');
  const limit = Math.min(ctx.maxBytes, ctx.grant?.maxBytes ?? Infinity);
  if (length > limit) throw new FilesError('TOO_LARGE', `Upload-Length ${length} > máximo ${limit}`);
  const m = parseMetadata(req.headers['upload-metadata'] as string | undefined);
  const g = ctx.grant;
  const tags = g?.tags ?? (m.tags ? m.tags.split(',').map((t) => t.trim()).filter(Boolean) : undefined);
  const confidentiality = g?.confidentiality ?? m.confidentiality;
  const replaces = g?.replaces ?? m.replaces;
  // Lo que fija la autorización acotada manda sobre los metadatos del cliente.
  const meta: UploadMeta = {
    name: g?.name ?? m.filename ?? m.name ?? '',
    ...(tags ? { tags } : {}),
    ...(confidentiality ? { confidentiality } : {}),
    ...(replaces ? { replaces } : {}),
    ...(m.idempotencyKey ? { idempotencyKey: m.idempotencyKey } : {}),
    ...(g ? { grant: g.jti } : {}),
  };
  if (!meta.name) throw new FilesError('INVALID_INPUT', 'falta el nombre del fichero (Upload-Metadata filename)');
  await ctx.beforeCreate?.();
  const { uploadId, expiresAt } = await ctx.svc.createUpload({ dome: ctx.dome, length, meta, owner: ctx.username, expiresInMs: ctx.expiresInMs });
  common(res);
  res.setHeader('Location', `${ctx.base}/${uploadId}`);
  res.setHeader('Upload-Expires', new Date(expiresAt).toUTCString());
  // creation-with-upload: el cuerpo, si lo hay, es el primer trozo. Una subida vacía se completa ya.
  const withBody = isOffsetBody(req) && Number(req.headers['content-length'] ?? 1) !== 0;
  if (withBody || length === 0) {
    const r = withBody
      ? await ctx.svc.appendUpload({ dome: ctx.dome, uploadId, offset: 0, source: req, owner: ctx.username, checksum: parseChecksum(req.headers['upload-checksum'] as string | undefined) })
      : { offset: 0, complete: true, result: await ctx.svc.completeUpload({ dome: ctx.dome, uploadId }) };
    res.setHeader('Upload-Offset', String(r.offset));
    completion(res, r.result);
  }
  res.statusCode = 201;
  res.end();
}

export async function tusHead(res: ServerResponse, ctx: TusContext, uploadId: string): Promise<void> {
  const info = await ctx.svc.uploadInfo({ dome: ctx.dome, uploadId, owner: ctx.username });
  if (info.status === 'expired' || (info.status === 'receiving' && info.expiresAt <= Date.now())) {
    throw new FilesError('EXPIRED', `la subida ${uploadId} caducó`);
  }
  if (info.status === 'failed') throw new FilesError('NOT_FOUND', `la subida ${uploadId} falló (${info.errorCode ?? 'error'})`);
  common(res);
  res.setHeader('Upload-Offset', String(info.offset));
  res.setHeader('Upload-Length', String(info.length));
  res.setHeader('Upload-Expires', new Date(info.expiresAt).toUTCString());
  res.statusCode = 200;
  res.end();
}

export async function tusPatch(req: IncomingMessage, res: ServerResponse, ctx: TusContext, uploadId: string): Promise<void> {
  if (!isOffsetBody(req)) {
    common(res);
    res.statusCode = 415;
    res.end();
    return;
  }
  const offset = intHeader(req.headers['upload-offset'], 'Upload-Offset');
  const checksum = parseChecksum(req.headers['upload-checksum'] as string | undefined);
  const r = await ctx.svc.appendUpload({ dome: ctx.dome, uploadId, offset, source: ctx.fence ? ctx.fence(req) : req, owner: ctx.username, checksum });
  common(res);
  res.setHeader('Upload-Offset', String(r.offset));
  if (!r.complete) {
    const info = await ctx.svc.uploadInfo({ dome: ctx.dome, uploadId, owner: ctx.username });
    res.setHeader('Upload-Expires', new Date(info.expiresAt).toUTCString());
  }
  completion(res, r.result);
  res.statusCode = 204;
  res.end();
}

export async function tusDelete(res: ServerResponse, ctx: TusContext, uploadId: string): Promise<void> {
  await ctx.svc.terminateUpload({ dome: ctx.dome, uploadId, owner: ctx.username });
  common(res);
  res.statusCode = 204;
  res.end();
}
