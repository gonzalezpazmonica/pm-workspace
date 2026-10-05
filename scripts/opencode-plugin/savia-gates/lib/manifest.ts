// manifest.ts — emits a sibling JSON manifest of registered bindings.
//
// The parity-audit script (SE-077 Slice 2) reads this file to compare against
// .claude/settings.json instead of parsing the TS source.
//
// The plugin never writes it while loading: the install dir is part of the
// engine fingerprint (Savia Space pluginSetHash), and a write per load turned
// every engine start into ENGINE_INTEGRITY DEGRADED. opencode-install.sh runs
// this file as a CLI; the content is deterministic (no timestamp) and the file
// is only rewritten when the bindings change.
//
//   bun lib/manifest.ts [project-root]   # writes $SAVIA_PLUGIN_DIR/manifest.json

import { loadHookMap, type HookMap } from "./shell-bridge"
import { mkdir, readFile, writeFile } from "node:fs/promises"

function manifestDir(): string {
  return process.env.SAVIA_PLUGIN_DIR ?? `${process.env.HOME ?? ""}/.savia/opencode/plugins/savia-gates`
}

/** Manifest JSON for a hook map; same map, same bytes. */
export function buildManifest(hookMap: HookMap): string {
  const bindings: Array<{
    claudeHook: string
    event: string
    matcher: string | null
    handler: string
  }> = []
  // Map Claude Code event names → OpenCode plugin handler names. Mirrors the
  // dispatch table in index.ts. A single Claude Code event may map to several
  // OpenCode hook points (e.g. PostCompact fires on `session.compacted` and on
  // `experimental.compaction.autocontinue`; SessionStart/InstructionsLoaded
  // both fire on `session.created`).
  const HANDLERS: Record<string, string[]> = {
    PreToolUse: ["tool.execute.before"],
    PostToolUse: ["tool.execute.after"],
    UserPromptSubmit: ["chat.message"],
    SessionStart: ["event:session.created"],
    InstructionsLoaded: ["event:session.created"],
    SessionEnd: ["event:session.deleted"],
    Stop: ["event:session.stopped"],
    PostCompact: ["event:session.compacted", "experimental.compaction.autocontinue"],
    SubagentStart: ["event:subagent.started"],
    SubagentStop: ["event:subagent.completed"],
    TaskCreated: ["event:task.created"],
    TaskCompleted: ["event:task.completed"],
    PreCompact: ["experimental.session.compacting"],
    FileChanged: ["event:file.edited", "event:file.watcher.updated"],
    CwdChanged: ["shell.env"],
    ConfigChange: ["config"],
    // PostToolUseFailure has no native OpenCode hook point — the hook bash
    // declares its own # opencode-binding: NOT_EXPOSED justification.
  }
  for (const [event, entries] of Object.entries(hookMap)) {
    const eventHandlers = HANDLERS[event]
    if (!eventHandlers) continue
    for (const e of entries) {
      // The parity inventory compares command hook basenames. HTTP Shield
      // hooks have no command basename and are exercised by runtime tests.
      if (e.type !== "command") continue
      // Extract the .sh basename the same way opencode-parity-audit.sh does
      // (regex over the command path), so manifest claudeHook matches the CC
      // binding even when the command carries args like "$CLAUDE_JSON_INPUT".
      const m = /([^/"\s]+\.sh)/.exec(e.command)
      const file = m?.[1] ?? e.command.split("/").pop() ?? e.command
      for (const handler of eventHandlers) {
        bindings.push({
          claudeHook: file,
          event,
          matcher: e.matcher ?? null,
          handler,
        })
      }
    }
  }
  const manifest = { spec: "SE-077", plugin: "savia-gates", bindings }
  return JSON.stringify(manifest, null, 2) + "\n"
}

/** Writes manifest.json in `dir` only if its content changed. Returns whether it wrote. */
export async function writeManifestIfChanged(hookMap: HookMap, dir = manifestDir()): Promise<boolean> {
  const file = `${dir}/manifest.json`
  const next = buildManifest(hookMap)
  if ((await readFile(file, "utf8").catch(() => null)) === next) return false
  await mkdir(dir, { recursive: true })
  await writeFile(file, next)
  return true
}

if (import.meta.main) {
  const root = process.argv[2] ?? process.env.PROJECT_ROOT ?? process.cwd()
  const wrote = await writeManifestIfChanged(await loadHookMap(root))
  console.log(`${wrote ? "written" : "unchanged"}: ${manifestDir()}/manifest.json`)
}
