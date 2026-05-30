// block-credential-leak.ts — SPEC-127 Slice 2b-ii
//
// Port of `.opencode/hooks/block-credential-leak.sh` to OpenCode TS plugin.
// Inspects bash commands for credential signatures (AWS/GitHub/OpenAI/
// Anthropic/Azure/Vault/PEM/Docker/etc.) and throws to block when found.
//
// Block mechanism: throw Error. OpenCode v1.14 plugin runtime catches the
// throw and surfaces it as a tool-execution failure to the user.
//
// Reference: SPEC-127 Slice 2b-ii AC-2.2

import { extractToolName, extractCommand, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";
import { detectCredentialLeak } from "../lib/credential-patterns.ts";

export async function blockCredentialLeak(input: ToolInput, output: ToolOutput): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input, output);
  if (!command) return;
  const detection = detectCredentialLeak(command);
  if (detection) {
    throw new Error(`BLOCKED [credential-leak/${detection.kind}]: ${detection.message}`);
  }
}
