// tool-call-healing.ts — SPEC-OC-04 Slice 2 (port of SPEC-141 hook)
//
// Pre-execution validation for file/pattern tools. Catches common LLM errors
// (empty paths, non-existent files, missing patterns) and throws diagnostic
// messages instead of letting the underlying tool fail with a cryptic error.
// Port of `.opencode/hooks/tool-call-healing.sh` (Tier: standard).
//
// Tools covered: read, edit, write, glob, grep.

import { existsSync, readdirSync, statSync } from "node:fs";
import { dirname, basename } from "node:path";
import { extractToolName, extractFilePath, type ToolInput } from "../lib/hook-input.ts";

function extractPattern(input: ToolInput): string {
  const p = input?.args?.pattern;
  return typeof p === "string" ? p : "";
}

function findSimilar(filePath: string): string {
  const dir = dirname(filePath);
  const base = basename(filePath);
  if (!existsSync(dir)) return "";
  try {
    const stem = base.replace(/\.[^.]*$/, "");
    const matches = readdirSync(dir)
      .filter((n) => n.toLowerCase().startsWith(stem.toLowerCase()))
      .filter((n) => {
        try {
          return statSync(`${dir}/${n}`).isFile();
        } catch {
          return false;
        }
      })
      .slice(0, 3);
    return matches.join(", ");
  } catch {
    return "";
  }
}

export async function toolCallHealing(input: ToolInput, _output: unknown): Promise<void> {
  const tool = extractToolName(input);

  switch (tool) {
    case "read":
    case "edit": {
      const filePath = extractFilePath(input);
      if (!filePath) {
        throw new Error(`BLOCKED [tool-healing]: ${tool} called with empty file_path`);
      }
      if (!existsSync(filePath)) {
        const similar = findSimilar(filePath);
        const hint = similar ? ` Similar files: ${similar}` : "";
        throw new Error(
          `BLOCKED [tool-healing]: file not found: ${filePath}.${hint}`,
        );
      }
      return;
    }
    case "write": {
      const filePath = extractFilePath(input);
      if (!filePath) {
        throw new Error("BLOCKED [tool-healing]: write called with empty file_path");
      }
      const dir = dirname(filePath);
      if (!existsSync(dir)) {
        throw new Error(
          `BLOCKED [tool-healing]: write to ${filePath} — parent directory does not exist: ${dir}`,
        );
      }
      return;
    }
    case "glob":
    case "grep": {
      const pattern = extractPattern(input);
      if (!pattern) {
        throw new Error(`BLOCKED [tool-healing]: ${tool} called with empty pattern`);
      }
      return;
    }
    default:
      return;
  }
}
