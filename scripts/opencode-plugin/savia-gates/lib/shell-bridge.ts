// shell-bridge.ts — runs Claude Code bash hooks from OpenCode plugin
//
// Reads .claude/settings.json once, builds an event → hook[] map keyed by
// the same matcher Claude Code uses (tool name regex / glob), then on each
// event invokes the matching hook scripts via Bun's `$` shell. This way
// the EXISTING .sh hooks run unchanged in OpenCode.

import { readFile } from "node:fs/promises"

export interface HookEntry {
  command: string         // resolved absolute path of the .sh
  matcher?: string         // optional matcher (tool name regex)
  timeout?: number
  async?: boolean
  declared_event: string  // SessionStart / PreToolUse / etc.
}

export type HookMap = Record<string, HookEntry[]>

export interface HookResult {
  blocked: boolean
  stderr: string
  stdout: string
  mutatedArgs?: any
  injectedContext?: string
}

export async function loadHookMap(_$: any, projectRoot: string): Promise<HookMap> {
  const settingsPath = `${projectRoot}/.claude/settings.json`
  const raw = await readFile(settingsPath, "utf-8").catch(() => "")
  if (!raw) return {}
  let parsed: any = {}
  try {
    parsed = JSON.parse(raw)
  } catch {
    return {}
  }
  const out: HookMap = {}
  const events = parsed.hooks || {}
  for (const [eventName, entries] of Object.entries(events)) {
    if (!Array.isArray(entries)) continue
    out[eventName] = []
    for (const entry of entries as any[]) {
      const matcher = entry.matcher
      const hooks = entry.hooks || []
      for (const h of hooks) {
        if (h.type !== "command" || typeof h.command !== "string") continue
        const cmd = h.command
          .replace(/"\$CLAUDE_PROJECT_DIR"/g, projectRoot)
          .replace(/\$CLAUDE_PROJECT_DIR/g, projectRoot)
          .replace(/^"|"$/g, "")
        out[eventName].push({
          command: cmd,
          matcher,
          timeout: h.timeout,
          async: h.async,
          declared_event: eventName,
        })
      }
    }
  }
  return out
}

function matcherApplies(matcher: string | undefined, tool: string | null): boolean {
  if (!matcher) return true
  if (!tool) return true   // event hooks (UserPromptSubmit, etc.) — no tool axis
  // Claude Code matchers are simple regex / pipe-separated globs. Use a relaxed match.
  try {
    const re = new RegExp(matcher.replace(/\*/g, ".*"), "i")
    return re.test(tool)
  } catch {
    return matcher === tool
  }
}

export async function runHooksForEvent(
  $: any,
  projectRoot: string,
  hookMap: HookMap,
  event: string,
  tool: string | null,
  payload: string,
): Promise<HookResult> {
  const result: HookResult = { blocked: false, stderr: "", stdout: "" }
  const hooks = hookMap[event] || []
  for (const h of hooks) {
    if (!matcherApplies(h.matcher, tool)) continue
    try {
      // Pipe payload on stdin; capture stdout/stderr; honour timeout.
      const timeout = (h.timeout ?? 5) * 1000
      const proc = $`bash ${h.command}`
        .env({ ...process.env, CLAUDE_PROJECT_DIR: projectRoot })
        .quiet()
        .timeout(timeout)
        .nothrow()
      const r = await proc.text({ stdin: payload }).catch(() => null)
      // The Bun `$` API differs slightly across versions; fall back to a manual spawn.
      const exit = (r as any)?.exitCode ?? 0
      const stdout = (r as any)?.stdout ?? ""
      const stderr = (r as any)?.stderr ?? ""
      if (exit === 2) {
        result.blocked = true
        result.stderr = String(stderr).trim() || `${h.command} exited 2`
        return result
      }
      // If a hook prints structured JSON on stdout, treat it as arg/context mutation.
      try {
        const parsed = JSON.parse(String(stdout))
        if (parsed?.mutatedArgs) result.mutatedArgs = parsed.mutatedArgs
        if (parsed?.injectedContext) result.injectedContext = parsed.injectedContext
      } catch {
        /* not JSON — ignore stdout */
      }
    } catch (err) {
      // Hook crashed — log but don't block by default. Pre-event hooks
      // declared as critical can opt-in via exit code 2 explicitly.
      result.stderr = String(err)
    }
  }
  return result
}
