// prompt-injection-guard.ts — SPEC-127 Slice 2b-ii
//
// Port of `.claude/hooks/prompt-injection-guard.sh` (SE-028). Scans
// context-classified files (agents, skills, commands, rules, profiles,
// projects/CLAUDE.md, docs/) for prompt injection patterns. Override and
// hidden-instruction categories BLOCK; social engineering only WARNS.
//
// Reference: SPEC-127 Slice 2b-ii AC-2.2, AC-2.3 (PV-02 critical safety hook)
// Reference: SE-028 Prompt Injection Guard

import {
  extractToolName,
  extractFilePath,
  extractContent,
  type ToolInput,
} from "./lib/hook-input.ts";
import { detectInjection } from "./lib/injection-patterns.ts";

const SKIP_EXTENSIONS = new Set([
  "sh", "py", "ts", "js", "cs", "java", "go", "rs", "rb", "php",
  "css", "json", "yaml", "yml", "toml",
]);

const SKIP_PATH_PATTERNS = [
  /\/tests\//,
  /\/output\//,
  /\/node_modules\//,
  /\/\.git\//,
];

const CONTEXT_PATH_PATTERNS = [
  /\/\.claude\/rules\//,
  /\/docs\/rules\//,
  /\/\.claude\/agents\//,
  /\/\.claude\/skills\//,
  /\/\.claude\/commands\//,
  /\/projects\/[^/]+\/CLAUDE\.md$/,
  /\/projects\/[^/]+\/reglas-negocio/,
  /\/projects\/[^/]+\/specs\//,
  /\/projects\/[^/]+\/agent-memory\//,
  /\/projects\/[^/]+\/team\//,
  /\/docs\//,
  /\/CLAUDE\.md$/,
  /\/\.claude\/profiles\//,
];

function ext(path: string): string {
  const i = path.lastIndexOf(".");
  return i >= 0 ? path.slice(i + 1).toLowerCase() : "";
}

function isContextPath(p: string): boolean {
  return CONTEXT_PATH_PATTERNS.some((rx) => rx.test(p));
}

function shouldSkipPath(p: string): boolean {
  return SKIP_PATH_PATTERNS.some((rx) => rx.test(p));
}

export async function promptInjectionGuard(input: ToolInput, _output: unknown): Promise<void> {
  const tool = extractToolName(input);
  if (tool !== "edit" && tool !== "write") return;

  const filePath = extractFilePath(input);
  if (!filePath) return;
  if (SKIP_EXTENSIONS.has(ext(filePath))) return;
  if (shouldSkipPath(filePath)) return;
  if (!isContextPath(filePath)) return;

  const content = extractContent(input);
  if (!content) return;

  const verdict = detectInjection(content);
  if (verdict.blocked) {
    const where = verdict.line ? `${filePath}:${verdict.line}` : filePath;
    throw new Error(
      `BLOCKED [prompt-injection/${verdict.category}]: ${verdict.match ?? "unknown"} in ${where}`,
    );
  }
  if (verdict.warned) {
    const where = verdict.line ? `${filePath}:${verdict.line}` : filePath;
    // eslint-disable-next-line no-console
    console.warn(
      `WARNING [prompt-injection/social]: ${verdict.match ?? "social-engineering"} in ${where}`,
    );
  }
}
