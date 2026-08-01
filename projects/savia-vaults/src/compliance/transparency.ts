import * as fs from 'node:fs';
import * as path from 'node:path';
import * as crypto from 'node:crypto';
import { signContent, verifySignature } from '../security/index.js';

export interface ContentMark {
  ai_generated: boolean;
  ai_manipulated: boolean;
  system: string;
  system_version: string;
  timestamp: string;
  human_reviewed?: boolean;
  human_reviewer?: string;
  human_review_scope?: string;
  signature?: string;
}

export interface OutputEntry {
  type: string;
  description: string;
  audience: string;
  exposure: string;
  art50_1: boolean;
  art50_2: boolean;
  art50_4: boolean;
  exclusion: string;
  notes: string;
}

export interface TransparencyReport {
  content_id: string;
  generated_by_ai: boolean;
  was_marked: boolean;
  mark_valid: boolean;
  human_reviewed: boolean;
  confidence: 'HIGH' | 'MEDIUM' | 'LOW' | 'NONE';
  details: string;
}

const AI_NOTICE = 'Savia — EU AI Act Art. 50(1): You are interacting with an AI system.';

export function getAINotice(): string {
  return AI_NOTICE;
}

export function loadInventory(inventoryDir: string): OutputEntry[] {
  const file = path.join(inventoryDir, 'output-inventory.yaml');
  if (!fs.existsSync(file)) return [];
  try {
    const raw = fs.readFileSync(file, 'utf-8');
    return parseInventoryYaml(raw);
  } catch {
    return [];
  }
}

function parseInventoryYaml(raw: string): OutputEntry[] {
  const entries: OutputEntry[] = [];
  let current: Partial<OutputEntry> = {};
  let inEntry = false;

  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (trimmed.startsWith('entries:') || trimmed.startsWith('version:') || trimmed.startsWith('last_updated:') || trimmed === '') continue;
    if (trimmed.startsWith('#') || trimmed.startsWith('- type:')) {
      if (inEntry && current.type) {
        entries.push(current as OutputEntry);
        current = {};
      }
      inEntry = true;
      const m = trimmed.match(/- type:\s*(\S+)/);
      if (m) current.type = m[1];
      continue;
    }

    const match = trimmed.match(/^(\w+):\s*['"]?(.*?)['"]?$/);
    if (match) {
      const key = match[1];
      let val: string | boolean = match[2].trim();
      if (key.startsWith('art50_')) val = val === 'true';
      (current as Record<string, unknown>)[key] = val;
    }
  }
  if (inEntry && current.type) entries.push(current as OutputEntry);
  return entries;
}

export function getClassification(outputType: string, inventory: OutputEntry[]): OutputEntry | undefined {
  return inventory.find(e => e.type === outputType);
}

export function requiresMarking(outputType: string, inventory: OutputEntry[]): boolean {
  const entry = getClassification(outputType, inventory);
  return entry?.art50_2 === true;
}

export function createContentMark(system: string, version: string, reviewed = false, reviewer?: string, scope?: string): ContentMark {
  const mark: ContentMark = { ai_generated: true, ai_manipulated: false, system, system_version: version, timestamp: new Date().toISOString() };
  if (reviewed) { mark.human_reviewed = true; mark.human_reviewer = reviewer; mark.human_review_scope = scope; }
  return mark;
}

export function signMark(mark: ContentMark): string {
  return signContent(JSON.stringify({ ai_generated: mark.ai_generated, timestamp: mark.timestamp, system: mark.system }));
}

export function verifyMark(mark: ContentMark): boolean {
  if (!mark.signature) return false;
  return verifySignature(JSON.stringify({ ai_generated: mark.ai_generated, timestamp: mark.timestamp, system: mark.system }), mark.signature);
}

export function injectMarkIntoContent(content: string, mark: ContentMark): string {
  mark.signature = signMark(mark);
  const lines = ['---', `ai_generated: true`, `ai_system: ${mark.system}`, `ai_version: ${mark.system_version}`, `ai_timestamp: ${mark.timestamp}`, `ai_signature: ${mark.signature}`];
  if (mark.human_reviewed) { lines.push('ai_human_reviewed: true'); if (mark.human_reviewer) lines.push(`ai_reviewer: ${mark.human_reviewer}`); }
  lines.push('---', '');
  return lines.join('\n') + content;
}

export function extractMark(content: string): ContentMark | null {
  const match = content.match(/^---\r?\nai_generated: true[\s\S]*?\r?\n---\r?\n/);
  if (!match) return null;
  const block = match[0];
  const mark: ContentMark = { ai_generated: true, ai_manipulated: false, system: extractField(block, 'ai_system') || 'unknown', system_version: extractField(block, 'ai_version') || '0.0.0', timestamp: extractField(block, 'ai_timestamp') || '', signature: extractField(block, 'ai_signature') };
  if (block.includes('ai_human_reviewed: true')) { mark.human_reviewed = true; mark.human_reviewer = extractField(block, 'ai_reviewer'); }
  return mark;
}

function extractField(block: string, field: string): string | undefined {
  const match = block.match(new RegExp(`${field}:\\s*(.+)`));
  return match ? match[1].trim() : undefined;
}

export function detectAIContent(content: string, generationLog: Map<string, string>): TransparencyReport {
  const contentHash = crypto.createHash('sha256').update(content).digest('hex');
  const mark = extractMark(content);
  if (mark && verifyMark(mark)) {
    return { content_id: contentHash, generated_by_ai: true, was_marked: true, mark_valid: true, human_reviewed: mark.human_reviewed || false, confidence: 'HIGH', details: `Generated by ${mark.system} v${mark.system_version} at ${mark.timestamp}` };
  }
  if (generationLog.has(contentHash)) {
    return { content_id: contentHash, generated_by_ai: true, was_marked: false, mark_valid: false, human_reviewed: false, confidence: 'MEDIUM', details: 'Found in generation log; mark was stripped or lost' };
  }
  return { content_id: contentHash, generated_by_ai: false, was_marked: false, mark_valid: false, human_reviewed: false, confidence: 'NONE', details: 'No evidence of AI generation found' };
}
