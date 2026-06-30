// block-blind-signing.ts — SE-229 / confidentiality integrity
//
// Blocks `confidentiality-sign.sh sign` unless the command includes
// an explicit audit step first (running the PII scan or the security-guardian).
//
// The pattern this guards against: calling `sign` immediately after a commit
// or push to make CI pass, without reviewing whether the diff leaks N3/N4 data.
//
// CORRECT flow:
//   1. bash scripts/confidentiality-sign.sh audit  (or equivalent PII scan)
//   2. Review output — no N3/N4 found
//   3. bash scripts/confidentiality-sign.sh sign
//
// BLOCKED flow:
//   bash scripts/confidentiality-sign.sh sign   ← straight to sign, no audit
//
// The guard allows sign when:
//   a) The command explicitly chains `audit && ... sign` or `pii-scan && ... sign`
//   b) The env var SAVIA_CONFIDENTIALITY_AUDITED=1 is set (set by audit step)
//   c) The command is `verify` or `status` (read-only, always allowed)
//
// Reference: docs/rules/domain/parallel-session-protocol.md
// Reference: scripts/confidentiality-sign.sh
// Reference: SE-229 incident 2026-06-26

import { extractToolName, extractCommand, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

// Patterns that indicate a sign command is being called
const SIGN_RX = /confidentiality-sign\.sh\s+(sign|--sign)\b/i;

// Patterns that indicate a prior audit in the same command chain
const AUDIT_CHAIN_RX: RegExp[] = [
  /confidentiality-sign\.sh\s+audit/i,           // explicit audit subcommand
  /pii[_-]scan|pii-check/i,                       // pii scan script
  /security[_-]guardian|security.*audit/i,        // security guardian
  /data-sovereignty-audit/i,                      // existing shield audit
  /SAVIA_CONFIDENTIALITY_AUDITED\s*=\s*1/,        // env var set by audit step
];

// Patterns that are always safe (verify/status are read-only)
const SAFE_RX = /confidentiality-sign\.sh\s+(verify|status|--verify|--status)\b/i;

export async function blockBlindSigning(input: ToolInput, _output: ToolOutput): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input, _output);
  if (!command) return;

  // Not a sign command — nothing to check
  if (!SIGN_RX.test(command)) return;

  // verify/status are always allowed
  if (SAFE_RX.test(command)) return;

  // Check if an audit step is chained in the same command
  const hasAuditChain = AUDIT_CHAIN_RX.some(rx => rx.test(command));
  if (hasAuditChain) return;

  // Blocked: sign without prior audit
  throw new Error(
    `BLOCKED [blind-signing]: confidentiality-sign.sh sign requires a prior audit.\n` +
    `\n` +
    `DO THIS FIRST:\n` +
    `  1. Read the diff: git diff origin/main...HEAD --name-only\n` +
    `  2. Review each changed file for N3/N4 data (credentials, PII,\n` +
    `     client names, private paths, internal IPs)\n` +
    `  3. Only sign after confirming the diff is clean:\n` +
    `     bash scripts/confidentiality-sign.sh sign\n` +
    `\n` +
    `Or chain audit + sign:\n` +
    `  bash scripts/confidentiality-sign.sh audit && bash scripts/confidentiality-sign.sh sign\n` +
    `\n` +
    `The signature exists to certify no confidential data leaks — not to pass CI.`
  );
}
