// wikilink-validator.ts — WikiLink extraction, validation, and backlink resolution

export interface WikiLinkValidation {
  source: string;
  target: string;
  displayText: string;
  exists: boolean;
  line?: number;
}

export interface BacklinkInfo {
  source: string;
  context: string;
}

const WIKILINK_RE = /\[\[([^\]]+)\]\]/g;

export function extractWikiLinks(content: string): { target: string; displayText: string }[] {
  const links: { target: string; displayText: string }[] = [];
  const matches = content.matchAll(WIKILINK_RE);
  for (const match of matches) {
    const inner = match[1];
    const pipeIdx = inner.indexOf('|');
    const target = pipeIdx > -1 ? inner.slice(0, pipeIdx).trim() : inner.trim();
    const displayText = pipeIdx > -1 ? inner.slice(pipeIdx + 1).trim() : target;
    links.push({ target, displayText });
  }
  return links;
}

export function validateWikiLinks(
  sourcePath: string,
  content: string,
  knownEntities: Set<string>,
): WikiLinkValidation[] {
  const links = extractWikiLinks(content);
  return links.map((link, i) => ({
    source: sourcePath,
    target: link.target,
    displayText: link.displayText,
    exists: knownEntities.has(link.target),
    line: i + 1,
  }));
}

export function resolveBacklinks(
  targetEntityId: string,
  allNotes: Array<{ path: string; content: string }>,
  maxResults = 50,
  contextChars = 200,
): BacklinkInfo[] {
  const backlinks: BacklinkInfo[] = [];

  for (const note of allNotes) {
    if (note.path === targetEntityId) continue;

    const links = extractWikiLinks(note.content);
    for (const link of links) {
      if (link.target === targetEntityId) {
        const idx = note.content.indexOf(`[[${link.target}]]`) || note.content.indexOf(`[[${link.target}|`);
        const start = Math.max(0, (idx > -1 ? idx : 0) - contextChars / 2);
        const context = note.content.slice(start, start + contextChars).replace(/\n/g, ' ').trim();
        backlinks.push({ source: note.path, context: `...${context}...` });
        break;
      }
    }
    if (backlinks.length >= maxResults) break;
  }

  return backlinks;
}

export function buildEntityIndex(
  notes: Array<{ path: string; frontmatter: Record<string, unknown> }>,
): Set<string> {
  const entities = new Set<string>();
  for (const note of notes) {
    const fm = note.frontmatter || {};
    const entity = fm.entity as Record<string, unknown> | undefined;
    if (entity?.id) entities.add(String(entity.id));
    // Also index by note name without extension
    const name = note.path.replace(/\.md$/, '').split('/').pop() || note.path;
    entities.add(name);
  }
  return entities;
}

export function computeWikiLinkHealth(
  notes: Array<{ path: string; content: string }>,
  knownEntities: Set<string>,
): {
  total_links: number;
  valid_links: number;
  broken_links: number;
  broken_details: Array<{ source: string; target: string }>;
  most_linked: Array<{ entity: string; count: number }>;
} {
  let total = 0;
  let valid = 0;
  const broken: Array<{ source: string; target: string }> = [];
  const linkCounts = new Map<string, number>();

  for (const note of notes) {
    const links = extractWikiLinks(note.content);
    for (const link of links) {
      total++;
      if (knownEntities.has(link.target)) {
        valid++;
      } else {
        broken.push({ source: note.path, target: link.target });
      }
      linkCounts.set(link.target, (linkCounts.get(link.target) || 0) + 1);
    }
  }

  const most_linked = Array.from(linkCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([entity, count]) => ({ entity, count }));

  return {
    total_links: total,
    valid_links: valid,
    broken_links: broken.length,
    broken_details: broken.slice(0, 20),
    most_linked,
  };
}
