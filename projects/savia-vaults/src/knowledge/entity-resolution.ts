/**
 * SE-329 — Entity resolution determinista: canonicalización de IDs y sinónimos.
 *
 * Referente: comentario de DIRENTIS en el artículo de referencia (LinkedIn):
 * "Antes de conectar entidades hace falta poder nombrarlas de forma
 * consistente." SaviaVaults tiene alias como propiedad (SE-288); esta capa
 * añade canonicalización en ingesta y resolución en consulta.
 */

export interface ResolutionEntity {
  id: string;
  alias?: string[];
}

export interface EntityResolutionIndex {
  canonicalId: Map<string, string>;
  synonyms: Map<string, string>;
}

/** NFKD strip diacritics → lowercase → trim → collapse whitespace → _+ → '-'. */
export function canonicalizeId(raw: string): string {
  return raw
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '-')
    .replace(/_+/g, '-')
    .replace(/-{2,}/g, '-');
}

export class EntityResolver {
  private index: EntityResolutionIndex = { canonicalId: new Map(), synonyms: new Map() };

  /**
   * Construye el índice. Devuelve las colisiones de canonicalización
   * (dos entidades cuyo canonical coincide): [{a, b, canonical}].
   */
  build(entities: ResolutionEntity[]): { a: string; b: string; canonical: string }[] {
    this.index = { canonicalId: new Map(), synonyms: new Map() };
    const seen = new Map<string, string>();
    const collisions: { a: string; b: string; canonical: string }[] = [];

    for (const e of entities) {
      const canonical = canonicalizeId(e.id);
      const prev = seen.get(canonical);
      if (prev !== undefined && prev !== e.id) {
        collisions.push({ a: prev, b: e.id, canonical });
        continue;
      }
      seen.set(canonical, e.id);
      this.index.canonicalId.set(canonical, e.id);
      this.index.synonyms.set(canonicalizeId(e.id), e.id);
      for (const a of e.alias ?? []) {
        this.index.synonyms.set(canonicalizeId(a), e.id);
      }
    }

    return collisions;
  }

  /** Input (id, canonical o alias) → id canónico de la entidad. */
  resolve(input: string): string | undefined {
    const c = canonicalizeId(input);
    if (c === '') return undefined;
    return this.index.synonyms.get(c) ?? this.index.canonicalId.get(c);
  }
}
