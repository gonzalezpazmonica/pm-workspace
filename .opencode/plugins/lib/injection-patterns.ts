// injection-patterns.ts — SPEC-127 Slice 2b-ii
//
// Mirror of `.claude/hooks/prompt-injection-guard.sh` rules, ported to
// TypeScript. Distinguishes BLOCK (override + hidden) from WARN-only
// (social engineering). Returns a structured verdict.

export type InjectionVerdict = {
  blocked: boolean;
  warned: boolean;
  category?: "override" | "hidden" | "social";
  match?: string;
  line?: number;
};

const OVERRIDE_PATTERNS = [
  "ignore previous instructions",
  "ignore all prior instructions",
  "disregard your instructions",
  "forget everything above",
  "override system prompt",
  "you are now a different",
  "act as if you have no rules",
  "new instructions override",
  "system prompt override",
  "jailbreak",
];

const SOCIAL_PATTERNS = [
  "do not tell the user",
  "don't mention this to",
  "keep this secret from",
  "the user doesn't need to know",
  "hide this from the user",
];

const ZERO_WIDTH = /[​‌‍]|(?<=.)﻿/;
const HTML_COMMENT_INJECTION = /<!--[^>]*(?:ignore|override|forget|disregard|system prompt)[^>]*-->/i;
const HIDDEN_DIV = /<div[^>]*display\s*:\s*none/i;

export function detectInjection(content: string): InjectionVerdict {
  if (!content) return { blocked: false, warned: false };

  const lines = content.split("\n");

  // Category 1 — direct override attempts (BLOCK)
  for (let i = 0; i < lines.length; i++) {
    const lower = lines[i].toLowerCase();
    for (const p of OVERRIDE_PATTERNS) {
      if (lower.includes(p)) {
        return { blocked: true, warned: false, category: "override", match: p, line: i + 1 };
      }
    }
  }

  // Category 2 — hidden instructions (BLOCK)
  if (ZERO_WIDTH.test(content)) {
    return { blocked: true, warned: false, category: "hidden", match: "zero-width-characters" };
  }
  if (HTML_COMMENT_INJECTION.test(content)) {
    return { blocked: true, warned: false, category: "hidden", match: "html-comment-injection" };
  }
  if (HIDDEN_DIV.test(content)) {
    return { blocked: true, warned: false, category: "hidden", match: "hidden-div" };
  }

  // Category 3 — social engineering (WARN only)
  for (let i = 0; i < lines.length; i++) {
    const lower = lines[i].toLowerCase();
    for (const p of SOCIAL_PATTERNS) {
      if (lower.includes(p)) {
        return { blocked: false, warned: true, category: "social", match: p, line: i + 1 };
      }
    }
  }

  return { blocked: false, warned: false };
}
