// SE-419 — permisos por documento de Savia Files. El nivel del documento (o el de la cúpula) se
// aplica con la misma tabla de roles que las cúpulas; las listas readers/writers solo restringen
// (null o ausente = hereda, [] = nadie salvo admin; writers implica lectura). Sin principal
// (servidor local sin usuarios) todo está permitido. Ser autor no da permisos.
import { FilesError, type Confidentiality, type DocumentAcl, type FileDocument } from './types.js';

export type Role = 'reader' | 'writer' | 'admin';
export interface Principal {
  username: string;
  role: Role;
  /** SE-423 AC7: las listas guardan `sub:<subjectId>`; un renombrado no cambia el acceso. */
  subjectId?: string;
  credentialId?: string;
  /** Nombres anteriores: siguen valiendo en listas antiguas que citan por nombre. */
  aliases?: string[];
}

/** Resolución nombre ↔ Subject para fijar y mostrar listas (sin usuarios: ausente). */
export interface SubjectResolver {
  idOf(username: string): string | undefined;
  nameOf(subjectId: string): string | undefined;
}

export const SUBJECT_PREFIX = 'sub:';
const SUBJECT_RE = /^sub:[0-9a-f-]{36}$/;

/** Entradas de lista que identifican al principal: nombre, alias y `sub:<subjectId>`. */
function identities(p: Principal): string[] {
  return [p.username, ...(p.aliases ?? []), ...(p.subjectId ? [SUBJECT_PREFIX + p.subjectId] : [])];
}
const listed = (list: string[], p: Principal) => identities(p).some((id) => list.includes(id));

const ROLE_LEVEL: Record<Role, number> = { reader: 1, writer: 2, admin: 3 };
const READ_MIN: Record<Confidentiality, Role> = { N1: 'reader', N2: 'reader', N3: 'writer', N4: 'admin' };
const WRITE_MIN: Record<Confidentiality, Role> = { N1: 'writer', N2: 'writer', N3: 'writer', N4: 'admin' };
const LEVELS: Confidentiality[] = ['N1', 'N2', 'N3', 'N4'];
const USERNAME_RE = /^[A-Za-z0-9._-]{1,64}$/;
const MAX_LIST = 256;

const levelOf = (doc: FileDocument, domeLevel: string): Confidentiality =>
  (doc.confidentiality ?? (LEVELS.includes(domeLevel as Confidentiality) ? domeLevel : 'N4')) as Confidentiality;
const atLeast = (p: Principal, min: Role) => (ROLE_LEVEL[p.role] ?? 0) >= ROLE_LEVEL[min];

export function canRead(p: Principal | undefined, doc: FileDocument, domeLevel: string): boolean {
  if (!p || p.role === 'admin') return true;
  if (!atLeast(p, READ_MIN[levelOf(doc, domeLevel)])) return false;
  const { readers, writers } = doc.acl ?? {};
  if (readers === null || readers === undefined) return true;
  return listed(readers, p) || listed(writers ?? [], p);
}

export function canWrite(p: Principal | undefined, doc: FileDocument, domeLevel: string): boolean {
  if (!p || p.role === 'admin') return true;
  if (!atLeast(p, WRITE_MIN[levelOf(doc, domeLevel)])) return false;
  const writers = doc.acl?.writers;
  return writers === null || writers === undefined || listed(writers, p);
}

/** Crear un documento a un nivel exige poder escribir ese nivel. */
export function canCreateAt(p: Principal | undefined, level: string): boolean {
  if (!p || p.role === 'admin') return true;
  return LEVELS.includes(level as Confidentiality) && atLeast(p, WRITE_MIN[level as Confidentiality]);
}

/** Lectura del documento o NOT_FOUND (no se revela que existe). */
export function assertRead(p: Principal | undefined, doc: FileDocument, domeLevel: string, dome: string): void {
  if (!canRead(p, doc, domeLevel)) throw new FilesError('NOT_FOUND', `documento ${doc.id} no existe en ${dome}`);
}

/** Escritura: NOT_FOUND si ni siquiera puede leerlo; POLICY_DENIED si solo lo lee. */
export function assertWrite(p: Principal | undefined, doc: FileDocument, domeLevel: string, dome: string): void {
  assertRead(p, doc, domeLevel, dome);
  if (!canWrite(p, doc, domeLevel)) throw new FilesError('POLICY_DENIED', `sin permiso de escritura sobre ${doc.id}`);
}

export interface PolicyPatch { confidentiality?: string; readers?: string[] | null; writers?: string[] | null }

function list(v: unknown, field: string): string[] | null {
  if (v === null) return null;
  if (!Array.isArray(v) || v.length > MAX_LIST) throw new FilesError('INVALID_INPUT', `${field}: lista de hasta ${MAX_LIST} usuarios, o null para heredar`);
  const names = v.map((x) => (typeof x === 'string' ? x : ''));
  if (names.some((n) => !USERNAME_RE.test(n) && !SUBJECT_RE.test(n))) throw new FilesError('INVALID_INPUT', `${field}: nombres de usuario de 1 a 64 caracteres [A-Za-z0-9._-]`);
  if (new Set(names).size !== names.length) throw new FilesError('INVALID_INPUT', `${field}: usuarios repetidos`);
  return [...names].sort();
}

/** Nombres actuales → `sub:<subjectId>`; los desconocidos se guardan tal cual (compatibilidad SE-419). */
export function toSubjects(list: string[] | null | undefined, r?: SubjectResolver): string[] | null | undefined {
  if (!list || !r) return list;
  const out = list.map((n) => (n.startsWith(SUBJECT_PREFIX) ? n : (r.idOf(n) ? SUBJECT_PREFIX + r.idOf(n) : n)));
  if (new Set(out).size !== out.length) throw new FilesError('INVALID_INPUT', 'la lista nombra dos veces al mismo usuario');
  return out.sort();
}

/** `sub:<subjectId>` → nombre actual, para mostrar; un Subject borrado se muestra como está. */
export function toNames(list: string[] | undefined, r?: SubjectResolver): string[] | undefined {
  if (!list || !r) return list;
  return list.map((n) => (n.startsWith(SUBJECT_PREFIX) ? r.nameOf(n.slice(SUBJECT_PREFIX.length)) ?? n : n));
}

/** Valida y normaliza un cambio de política. Solo devuelve los campos presentes. */
export function validatePolicy(patch: PolicyPatch, domeLevel: string): { confidentiality?: Confidentiality } & DocumentAcl {
  const out: { confidentiality?: Confidentiality } & DocumentAcl = {};
  if (patch.confidentiality !== undefined) {
    const level = String(patch.confidentiality).toUpperCase() as Confidentiality;
    if (!LEVELS.includes(level)) throw new FilesError('INVALID_INPUT', `confidencialidad no válida: ${String(patch.confidentiality).slice(0, 8)}`);
    if (LEVELS.indexOf(level) > LEVELS.indexOf(domeLevel as Confidentiality)) {
      throw new FilesError('INVALID_INPUT', `confidencialidad ${level} superior a la cúpula (${domeLevel})`);
    }
    out.confidentiality = level;
  }
  if (patch.readers !== undefined) out.readers = list(patch.readers, 'readers');
  if (patch.writers !== undefined) out.writers = list(patch.writers, 'writers');
  if (!Object.keys(out).length) throw new FilesError('INVALID_INPUT', 'nada que cambiar: indica confidentiality, readers o writers');
  return out;
}

/** Normaliza el principal que devuelve `authorize` (cualquier otra cosa ⇒ modo local). */
export function asPrincipal(v: unknown): Principal | undefined {
  if (!v || typeof v !== 'object') return undefined;
  const { username, role, subjectId, credentialId, aliases } = v as Record<string, unknown>;
  if (typeof username !== 'string' || !(role === 'reader' || role === 'writer' || role === 'admin')) return undefined;
  return {
    username, role,
    ...(typeof subjectId === 'string' ? { subjectId } : {}),
    ...(typeof credentialId === 'string' ? { credentialId } : {}),
    ...(Array.isArray(aliases) ? { aliases: aliases.filter((a): a is string => typeof a === 'string') } : {}),
  };
}
