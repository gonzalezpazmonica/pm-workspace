// manifest.ts — emits a sibling JSON manifest of registered bindings.
//
// The parity-audit script (SE-077 Slice 2) reads this file to compare against
// .claude/settings.json instead of parsing the TS source. Idempotent.

import type { HookMap } from "./shell-bridge"
import { mkdir, writeFile } from "node:fs/promises"

const MANIFEST_DIR =
  process.env.SAVIA_PLUGIN_DIR ??
  `${process.env.HOME ?? ""}/.savia/opencode/plugins/savia-gates`
const MANIFEST_FILE = `${MANIFEST_DIR}/manifest.json`

export async function writeManifest(hookMap: HookMap): Promise<void> {
  const bindings: Array<{
    claudeHook: string
    event: string
    matcher: string | null
    handler: string
  }> = []
  // Map Claude Code event names → OpenCode plugin handler names. Mirrors the
  // dispatch table in index.ts.
  const HANDLER: Record<string, string> = {
    PreToolUse: "tool.execute.before",
    PostToolUse: "tool.execute.after",
    UserPromptSubmit: "chat.message",
    SessionStart: "event:session.created",
    SessionEnd: "event:session.deleted",
    Stop: "event:session.stopped",
    SubagentStart: "event:subagent.started",
    SubagentStop: "event:subagent.completed",
    TaskCreated: "event:task.created",
    TaskCompleted: "event:task.completed",
    PreCompact: "experimental.session.compacting",
    // The remaining event types have no native OpenCode binding yet — leave
    // them OUT of the manifest so the audit reports them as gap candidates.
  }
  for (const [event, entries] of Object.entries(hookMap)) {
    const handler = HANDLER[event]
    if (!handler) continue
    for (const e of entries) {
      const file = e.command.split("/").pop() ?? e.command
      bindings.push({
        claudeHook: file,
        event,
        matcher: e.matcher ?? null,
        handler,
      })
    }
  }
  const manifest = {
    spec: "SE-077",
    plugin: "savia-gates",
    generated_at: new Date().toISOString(),
    bindings,
  }
  await mkdir(MANIFEST_DIR, { recursive: true }).catch(() => {})
  await writeFile(MANIFEST_FILE, JSON.stringify(manifest, null, 2)).catch(() => {})
}
