# Spec: SE-307 — Open Knowledge Format (OKF) Adapter para SaviaVaults

**Task ID:**        SE-307
**PBI padre:**      SE-307 — Interoperabilidad OKF de SaviaVaults
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia (analisis del articulo OKF de Google Cloud, 2026-06-12)

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 120 min |
| Human effort | 6 h |
| Review effort | 45 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 3h |

---

## 1. Contexto y Objetivo

Google Cloud publicó en junio 2026 el **Open Knowledge Format (OKF) v0.1**: una especificación
abierta y vendor-neutral que formaliza el patrón LLM-wiki (Karpathy) como un directorio de
ficheros markdown con YAML frontmatter. El objetivo: que wikis escritas por productores distintos
sean consumidas por agentes distintos sin traducción.

**Los 3 principios de OKF:**
1. **Minimamente opinionado** — solo exige `type` en el frontmatter, todo lo demas es libre
2. **Independencia productor/consumidor** — el formato es el contrato, el tooling es swappable
3. **Formato, no plataforma** — sin SDK propietario, sin cuenta, sin cloud

**Estado actual de SaviaVaults**: ya implementa ~80% del patron OKF:
- Markdown + YAML frontmatter (title, tags, created, modified) ✓
- Git-backed storage con diffs y logs ✓
- BM25 search (minisearch) ✓
- Wikilinks con validacion, backlinks y health (SE-298) ✓
- Federacion entre domes (A2A) ✓
- Firma Ed25519 ✓

**Gap con OKF (lo que falta):**

| Capacidad OKF | Estado en SaviaVaults | Gap |
|---|---|---|
| Campos frontmatter `type`, `description`, `resource`, `timestamp` | Solo title, tags, created, modified | **Faltan 4 campos** |
| `type` como unico campo obligatorio | No hay enforcement | **Falta validacion** |
| `index.md` para progressive disclosure | No existe | **Falta convencion** |
| `log.md` para cronologia de cambios | Git log si existe, no como fichero | **Falta convencion** |
| Cross-linking via markdown links | Usa wikilinks `[[...]]` (SE-298) | **Compatibilidad** |
| Import/export de bundles OKF | Solo export basico de contenido crudo | **Falta adapter** |
| Conformance validator | No existe | **Falta** |

**Objetivo**: convertir SaviaVaults en productor y consumidor OKF-compliant, habilitando:
1. Exportar cualquier dome como bundle OKF consumible por Google Knowledge Catalog y otros agentes
2. Importar bundles OKF externos (GA4, Stack Overflow, Bitcoin datasets de Google) en un dome
3. Validar conformancia OKF v0.1 de cualquier dome
4. Enriquecer frontmatter con los 6 campos OKF (type, title, description, resource, tags, timestamp)

---

## 2. Contrato Tecnico

### 2.1 Enriquecimiento de Frontmatter

```typescript
// projects/savia-vaults/src/knowledge/okf.ts

/**
 * Campos OKF v0.1. Solo `type` es obligatorio.
 * La identidad de un concepto es su path en el bundle.
 */
export interface OkfFrontmatter {
  type: string;              // OBLIGATORIO — ej: "BigQuery Table", "Metric", "Runbook"
  title?: string;
  description?: string;
  resource?: string;         // URL/referencia al recurso real
  tags?: string[];
  timestamp?: string;        // ISO 8601
}

export interface OkfConformanceReport {
  conformant: boolean;
  violations: string[];
  warnings: string[];
  noteCount: number;
  checkedAt: string;
}

const OKF_REQUIRED_FIELDS = ['type'] as const;
const OKF_OPTIONAL_FIELDS = ['title', 'description', 'resource', 'tags', 'timestamp'] as const;
const OKF_RESERVED_FILENAMES = ['index.md', 'log.md'] as const;

export function validateOkfFrontmatter(
  fm: Record<string, unknown>,
  path: string,
): OkfConformanceReport {
  const violations: string[] = [];
  const warnings: string[] = [];

  if (!fm.type || typeof fm.type !== 'string') {
    violations.push(`[${path}] missing required field: type`);
  }
  if (fm.timestamp && isNaN(Date.parse(String(fm.timestamp)))) {
    violations.push(`[${path}] invalid timestamp: ${fm.timestamp}`);
  }

  const unknownFields = Object.keys(fm).filter(
    k => ![...OKF_REQUIRED_FIELDS, ...OKF_OPTIONAL_FIELDS].includes(k),
  );
  for (const u of unknownFields) {
    warnings.push(`[${path}] non-OKF field present: ${u}`);
  }

  const baseName = path.split('/').pop() || '';
  if (baseName === 'index.md' || baseName === 'log.md') {
    warnings.push(`[${path}] reserved filename used; index.md/log.md have special meaning in OKF`);
  }

  return {
    conformant: violations.length === 0,
    violations,
    warnings,
    noteCount: 0,
    checkedAt: new Date().toISOString(),
  };
}
```

### 2.2 Conformance Validator

```typescript
// projects/savia-vaults/src/knowledge/okf-conformance.ts

import type { VaultStorage } from '../storage/index.js';

export async function checkOkfConformance(
  storage: VaultStorage,
): Promise<OkfConformanceReport> {
  const notes = await storage.list();
  const violations: string[] = [];
  const warnings: string[] = [];

  for (const notePath of notes) {
    if (notePath.endsWith('/index.md')) continue;  // index.md is exempt (progressive disclosure)
    if (notePath.endsWith('/log.md')) continue;    // log.md is exempt (chronology)

    const note = await storage.read(notePath);
    const report = validateOkfFrontmatter(note.frontmatter, notePath);
    violations.push(...report.violations);
    warnings.push(...report.warnings);
  }

  return {
    conformant: violations.length === 0,
    violations,
    warnings,
    noteCount: notes.length,
    checkedAt: new Date().toISOString(),
  };
}
```

### 2.3 OKF Exporter

```typescript
// projects/savia-vaults/src/knowledge/okf-export.ts

import type { VaultStorage } from '../storage/index.js';
import { validateOkfFrontmatter } from './okf.js';

export interface OkfExportOptions {
  includeIndexFiles?: boolean;   // default true — progressive disclosure
  includeLogFiles?: boolean;     // default true — chronology
}

export async function exportOkfBundle(
  storage: VaultStorage,
  outputDir: string,
  opts: OkfExportOptions = {},
): Promise<{ exported: number; skipped: string[] }> {
  const fs = await import('node:fs/promises');
  const path = await import('node:path');

  const notes = await storage.list();
  const skipped: string[] = [];
  let exported = 0;

  for (const notePath of notes) {
    // Resolver wikilinks [[x]] → markdown links [x](x.md) para OKF compat
    const note = await storage.read(notePath);
    const convertedContent = convertWikiLinksToMarkdown(note.content);

    // Enriquecer frontmatter con campos OKF si faltan
    const fm = { ...note.frontmatter };
    fm.timestamp ??= note.modified;
    if (!fm.type) {
      fm.type = inferOkfType(notePath, fm);
      skipped.push(`${notePath}: type inferido como '${fm.type}'`);
    }

    const report = validateOkfFrontmatter(fm, notePath);
    if (!report.conformant) {
      skipped.push(`${notePath}: ${report.violations.join('; ')}`);
      continue;
    }

    const destPath = path.join(outputDir, notePath);
    await fs.mkdir(path.dirname(destPath), { recursive: true });
    await fs.writeFile(destPath, serializeOkfNote(fm, convertedContent), 'utf-8');
    exported++;
  }

  if (opts.includeIndexFiles) {
    await generateOkfIndexes(storage, outputDir);
  }

  return { exported, skipped };
}

function convertWikiLinksToMarkdown(content: string): string {
  // [[path/to/note]] → [path/to/note](path/to/note.md)
  return content.replace(
    /\[\[([^\]]+)\]\]/g,
    (_, target: string) => {
      const clean = target.split('|')[0] ?? target;
      const label = target.split('|')[1] ?? clean;
      const mdPath = clean.replace(/\.md$/, '') + '.md';
      return `[${label}](${mdPath})`;
    },
  );
}

function inferOkfType(notePath: string, fm: Record<string, unknown>): string {
  const base = notePath.split('/').pop() || '';
  if (fm.tags?.includes('metric')) return 'Metric';
  if (base.includes('table') || base.includes('_db')) return 'BigQuery Table';
  if (base.includes('runbook')) return 'Runbook';
  if (base.includes('api')) return 'API';
  return 'Concept';
}

function serializeOkfNote(fm: Record<string, unknown>, content: string): string {
  const fmLines = Object.entries(fm)
    .filter(([k]) => k !== 'created' && k !== 'modified')  // OKF usa timestamp, no created/modified
    .map(([k, v]) => {
      if (Array.isArray(v)) return `${k}: [${v.join(', ')}]`;
      if (typeof v === 'string') return `${k}: ${v}`;
      return `${k}: ${String(v)}`;
    });
  return `---\n${fmLines.join('\n')}\n---\n\n${content}`;
}
```

### 2.4 OKF Importer

```typescript
// projects/savia-vaults/src/knowledge/okf-import.ts

import type { VaultStorage } from '../storage/index.js';
import { validateOkfFrontmatter } from './okf.js';

export interface OkfImportOptions {
  sourceDir: string;
  stripPrefix?: string;       // ej: "sales/" para importar solo esa rama
  validateFirst?: boolean;    // default true — validar antes de importar
  force?: boolean;            // sobrescribir notas existentes
}

export async function importOkfBundle(
  storage: VaultStorage,
  opts: OkfImportOptions,
): Promise<{ imported: number; rejected: string[] }> {
  const fs = await import('node:fs/promises');
  const path = await import('node:path');
  const { glob } = await import('glob');

  const files = await glob('**/*.md', { cwd: opts.sourceDir });
  const rejected: string[] = [];
  let imported = 0;

  for (const relPath of files) {
    // Saltar index.md/log.md al importar (son estructura, no conceptos)
    if (relPath.endsWith('/index.md') || relPath.endsWith('/log.md')) continue;

    const raw = await fs.readFile(path.join(opts.sourceDir, relPath), 'utf-8');
    const { frontmatter, content } = parseOkf(raw);

    const report = validateOkfFrontmatter(frontmatter, relPath);
    if (opts.validateFirst && !report.conformant) {
      rejected.push(`${relPath}: ${report.violations.join('; ')}`);
      continue;
    }

    let destPath = opts.stripPrefix && relPath.startsWith(opts.stripPrefix)
      ? relPath.slice(opts.stripPrefix.length)
      : relPath;

    const existing = await storage.read(destPath).catch(() => null);
    if (existing && !opts.force) {
      rejected.push(`${relPath}: already exists (use --force to overwrite)`);
      continue;
    }

    // Convertir markdown links → wikilinks para el grafo Savia
    const converted = convertMarkdownLinksToWikiLinks(content);
    await storage.write(destPath, converted, frontmatter);
    imported++;
  }

  return { imported, rejected };
}

function convertMarkdownLinksToWikiLinks(content: string): string {
  return content.replace(
    /\[([^\]]+)\]\(([^)]+)\.md\)/g,
    (_, label: string, target: string) => `[[${target}|${label}]]`,
  );
}

function parseOkf(raw: string): { frontmatter: Record<string, unknown>; content: string } {
  const { YAML } = require('yaml');
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content: raw };
  return { frontmatter: YAML.parse(match[1]) || {}, content: match[2].trim() };
}
```

### 2.5 CLI Extensions

```bash
# Nuevos comandos savia-vaults

# Validar conformancia OKF de un dome
savia-vaults okf-conformance --path <vault>

# Exportar como bundle OKF (conversion wikilinks→links, frontmatter enriquecido)
savia-vaults okf-export --path <vault> --output <dir> [--no-index] [--no-log]

# Importar bundle OKF externo
savia-vaults okf-import --source <dir> --path <vault> [--strip-prefix <prefix>] [--force]

# Ejemplo: importar bundle GA4 de Google
savia-vaults okf-import --source ./ga4-okf-bundle --path ./my-vault
```

---

## 3. Inputs/Outputs

### Inputs
- Vault existente (notas markdown + frontmatter)
- Bundle OKF externo (directorio de .md con frontmatter conforme)

### Outputs
- Bundle OKF exportado (directorio de notas conformes, wikilinks convertidos a links)
- Reporte de conformancia (conformant/not, violations, warnings)
- Notas importadas (markdown links convertidos a wikilinks para el grafo)

---

## 4. Constraints and Limits

- `type` es el unico campo OKF obligatorio — nunca rechazar una nota por falta de type, inferirlo
- index.md y log.md son nombres reservados (progressive disclosure + cronologia) — exentos de validacion
- `timestamp` reemplaza created/modified en export OKF (convencion OKF)
- Los wikilinks `[[x]]` se convierten a markdown links `[x](x.md)` en export, y viceversa en import
- El import NUNCA sobrescribe sin `--force`
- La validacion es no-destructiva: reporta, no bloquea
- Round-trip: export → import debe preservar el contenido del cuerpo (solo cambia formato de links)

---

## 5. Test Scenarios

1. **Conformance de vault conformado**: vault con frontmatter type/title/description → conformant
2. **Conformance de vault legacy**: nota sin `type` → violation, reportada no bloqueada
3. **Export conversion**: wikilink `[[tables/customers|customers]]` → `[customers](tables/customers.md)`
4. **Import conversion**: markdown link → wikilink `[[tables/customers|customers]]`
5. **Import preserve body**: import → export → body identico (solo links cambian de sintaxis)
6. **index.md exemption**: nota llamada `index.md` no genera violation
7. **Timestamp enrichment**: nota sin timestamp → usa `modified` en export
8. **Type inference**: nota en `metrics/` con tag `metric` → type "Metric"
9. **Force import**: nota existente sin `--force` → rechazada; con `--force` → sobrescrita
10. **Round-trip grafo**: wikilinks convertidos a links y viceversa mantienen el grafo (backlinks preservados)

---

## 6. Ficheros a Crear/Modificar

### Crear
| Fichero | Proposito |
|---|---|
| `projects/savia-vaults/src/knowledge/okf.ts` | Frontmatter OKF, validacion, tipos |
| `projects/savia-vaults/src/knowledge/okf-conformance.ts` | Conformance validator |
| `projects/savia-vaults/src/knowledge/okf-export.ts` | Bundle exporter (wikilinks→links) |
| `projects/savia-vaults/src/knowledge/okf-import.ts` | Bundle importer (links→wikilinks) |
| `projects/savia-vaults/tests/unit/knowledge/okf.test.ts` | Tests unitarios OKF |
| `projects/savia-vaults/tests/unit/knowledge/okf-export.test.ts` | Tests exporter |
| `projects/savia-vaults/tests/unit/knowledge/okf-import.test.ts` | Tests importer |
| `projects/savia-vaults/tests/fixtures/okf-bundle/` | Bundle OKF de ejemplo (GA4 minimal) |

### Modificar
| Fichero | Cambio |
|---|---|
| `projects/savia-vaults/src/cli/index.ts` | Añadir okf-conformance, okf-export, okf-import |
| `projects/savia-vaults/src/types.ts` | Extender Frontmatter con type/description/resource/timestamp |

---

## 7. Codigo de Referencia

- **Open Knowledge Format v0.1** (Google Cloud, 2026-06-12):
  - Bundle = directorio de markdown con YAML frontmatter
  - Path = identidad del concepto
  - Campos frontmatter: type (obligatorio), title, description, resource, tags, timestamp
  - index.md para progressive disclosure, log.md para cronologia
  - Cross-linking via markdown links → grafo
  - 3 principios: minimamente opinionado, independencia productor/consumidor, formato no plataforma
  - Referencias: enrichment agent (BigQuery→OKF), static HTML visualizer, sample bundles (GA4, Stack Overflow, Bitcoin)
  - Repo: GoogleCloudPlatform/knowledge-catalog (spec + examples)
- **SaviaVaults existente**:
  - `src/storage/index.ts` — VaultStorage, parseFrontmatter, extractTags
  - `src/knowledge/wikilink-validator.ts` — wikilinks, backlinks, health (SE-298)
  - `src/types.ts` — Frontmatter, Note, VaultConfig
  - `src/cli/index.ts` — comandos CLI

---

## 8. Reglas de Negocio

1. La identidad de un concepto OKF es su path — nunca el title
2. `type` es el unico campo obligatorio; se infiere si falta (nunca se rechaza)
3. index.md/log.md son estructura, no conceptos — exentos de validacion de type
4. `timestamp` (ISO 8601) reemplaza created/modified en el export OKF
5. Wikilinks y markdown links son dos sintaxis del mismo grafo — se convierten bidireccionalmente
6. El import nunca destruye datos existentes sin `--force`
7. Round-trip export→import preserva el cuerpo de las notas
8. La validacion OKF es no-destructiva: reporta violations sin bloquear el vault

---

## 9. Estado de Implementacion

- [ ] S1: Tipos OKF + validacion frontmatter (okf.ts)
- [ ] S2: Conformance validator (okf-conformance.ts)
- ] S3: Exporter con conversion wikilinks→links + enrichment (okf-export.ts)
- [ ] S4: Importer con conversion links→wikilinks (okf-import.ts)
- [ ] S5: CLI (okf-conformance, okf-export, okf-import)
- [ ] S6: Tests (conformance, export, import, round-trip)
- [ ] S7: Fixtures bundle OKF de ejemplo
- [ ] S8: Documentacion

---

## 10. Checklist Pre-Entrega

- [ ] Vault existente exporta como bundle OKF conforme
- [ ] Bundle OKF externo (GA4 minimal) importa correctamente
- [ ] Wikilinks ↔ markdown links round-trip preserva el grafo
- [ ] `type` se infiere correctamente en export
- [ ] `timestamp` se usa en lugar de created/modified
- [ ] index.md/log.md exentos de validacion
- [ ] Conformance reporte accurate (violations vs warnings)
- [ ] Import sin --force rechaza notas existentes
- [ ] Cobertura de tests >80%
- [ ] CLI documentado
