// shell-bridge.ts — runs Claude Code bash hooks from OpenCode plugin
//
// Reads .claude/settings.json once, builds an event → hook[] map keyed by
// the same matcher Claude Code uses (tool name regex / glob), then on each
// event invokes the matching hook scripts via Bun's `$` shell. This way
// the EXISTING .sh hooks run unchanged in OpenCode.

import { readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { auditLog } from "./audit"

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
          .replace(/"\$CLAUDE_PLUGIN_ROOT"/g, projectRoot)
          .replace(/\$CLAUDE_PLUGIN_ROOT/g, projectRoot)
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

function toMatcherRegex(matcher: string): RegExp {
  // Claude Code matchers are simple regex / `*` globs / pipe-separated
  // alternatives. Convert `*` to `.*` and match case-insensitively.
  return new RegExp(matcher.replace(/\*/g, ".*"), "i")
}

function matcherApplies(
  matcher: string | undefined,
  tool: string | null,
  payload?: string,
): boolean {
  if (!matcher) return true
  if (!tool && !payload) return true  // event hooks (UserPromptSubmit, etc.) — no tool axis
  // Prefer a relaxed regex match against the tool name (Claude Code semantics).
  // When the tool name does not match, also try the serialized payload so
  // content-sensitive matchers (`Bash:gh pr create*`, `Bash(gh pr create*)`)
  // can fire — OpenCode passes the tool name lowercased (`bash` vs `Bash`).
  let re: RegExp
  try {
    re = toMatcherRegex(matcher)
  } catch {
    if (tool && matcher === tool) return true
    if (payload && payload.includes(matcher)) return true
    return false
  }
  if (tool && re.test(tool)) return true
  const candidates: string[] = []
  if (payload) candidates.push(payload)
  // Claude Code matchers of the form `Tool(command*)` are matched against a
  // composite "tool name" like `Bash(git commit -m x)` or `Bash:gh pr create`.
  // OpenCode passes the lowercased tool name and the args. Rebuild the
  // composite forms so command-scoped matchers fire.
  let cmd: string | undefined
  try {
    const parsed = JSON.parse(payload ?? "")
    cmd = parsed?.tool_input?.command ?? parsed?.command ?? parsed?.tool_input?.input
    if (typeof cmd !== "string") cmd = undefined
  } catch {
    cmd = undefined
  }
  if (tool && cmd) {
    candidates.push(`${tool}(${cmd})`)
    candidates.push(`${tool}:${cmd}`)
    candidates.push(`${tool} ${cmd}`)
  }
  for (const c of candidates) {
    try {
      if (re.test(c)) return true
    } catch {
      /* already handled */
    }
  }
  return false
}

/** Path for a per-call stdin payload file (local, ephemeral, CRIT-001 safe). */
function stdinPayloadPath(): { path: string; cleanup: () => Promise<void> } {
  const path = `${tmpdir()}/savia-gates-${process.pid}-${Date.now()}-${Math.random().toString(36).slice(2)}.json`
  return { path, cleanup: () => rm(path, { force: true }).catch(() => {}) }
}

/**
 * Build the Bun `$` chain for a hook, feeding the payload on stdin via a
 * temporary-file redirect and resolving to BunShellOutput { stdout, stderr,
 * exitCode }.
 *
 * The bundled `$` runtime does NOT expose `.timeout()` (and `proc.text({
 * stdin })` silently drops the payload), so we feature-detect the chain and
 * enforce the timeout in `runHookOnce` with a manual race.
 */
async function spawnHook(
  $: any,
  projectRoot: string,
  h: HookEntry,
  payload: string,
): Promise<{ proc: Promise<any>; cleanup: () => Promise<void> }> {
  const { path: stdinPath, cleanup } = stdinPayloadPath()
  await writeFile(stdinPath, payload, "utf8")
  let p: any
  try {
    // `bash -c "<command>"` runs the hook command string as shell syntax:
    // handles plain paths (shebang), `bash "..."` prefixes, redirections and
    // `||` chains that appear in settings.json. Interpolate as `{raw}` so Bun
    // does NOT escape the command's inner quotes (that broke `bash -c`).
    p = $`bash -c ${{ raw: h.command }} < "${stdinPath}"`
      .env({ ...process.env, CLAUDE_PROJECT_DIR: projectRoot, CLAUDE_JSON_INPUT: payload })
      .cwd(projectRoot)
      .quiet()
    if (typeof p.timeout === "function") p = p.timeout(timeoutFor(h))
    if (typeof p.nothrow === "function") p = p.nothrow()
  } catch (err) {
    await cleanup()
    throw err
  }
  return { proc: p, cleanup }
}

/** Honours the configured timeout (Claude Code default 5s, cap 30s). */
function timeoutFor(h: HookEntry): number {
  const configured = h.timeout ?? 5000
  return Math.min(configured < 1000 ? configured * 1000 : configured, 30000)
}

/** Await one hook with a hard timeout; never throws on non-2 exits. */
async function runHookOnce(
  $: any,
  projectRoot: string,
  h: HookEntry,
  payload: string,
): Promise<{ exit: number; stdout: string; stderr: string }> {
  const { proc, cleanup } = await spawnHook($, projectRoot, h, payload)
  const timeout = timeoutFor(h)
  const outcome: any = await Promise.race([
    proc.then((r: any) => ({ r }), (e: any) => ({ err: e })),
    new Promise((res) => setTimeout(() => res({ timeout: true }), timeout + 1000)),
  ])
  void cleanup()
  if (outcome?.timeout) {
    return { exit: 0, stdout: "", stderr: `${h.command} timed out after ${timeout}ms` }
  }
  if (outcome?.err) {
    const e: any = outcome.err
    // Without `.nothrow()` a non-zero exit rejects with BunShellError, which
    // still carries exitCode/stdout/stderr — recover the block contract.
    if (e && typeof e.exitCode === "number") {
      return { exit: e.exitCode, stdout: e.stdout ? String(e.stdout) : "", stderr: e.stderr ? String(e.stderr) : "" }
    }
    throw e
  }
  const r: any = outcome?.r
  return {
    exit: typeof r?.exitCode === "number" ? r.exitCode : 0,
    stdout: r?.stdout ? String(r.stdout) : "",
    stderr: r?.stderr ? String(r.stderr) : "",
  }
}

// Exit code 2 == hard block (Claude Code contract). Anything else (including
// hook crashes / timeouts) passes through — logging the cause when present.
const BLOCK_EXIT = 2

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
    if (!matcherApplies(h.matcher, tool, payload)) continue
    try {
      // `async: true` hooks are fire-and-forget (Claude Code semantics):
      // their exit code and output are ignored, and the caller never waits.
      if (h.async) {
        void runHookOnce($, projectRoot, h, payload).catch(() => {})
        continue
      }
      const { exit, stdout, stderr } = await runHookOnce($, projectRoot, h, payload)
      if (exit === BLOCK_EXIT) {
        result.blocked = true
        result.stderr = stderr.trim() || `${h.command} exited ${BLOCK_EXIT}`
        return result
      }
      // Claude Code block contract #2: exit 0 + stdout JSON `{"decision":"block"}`
      // (used by SE-337 commit guard and the Stop gates). Parse BEFORE mutation
      // so a block is not swallowed by the mutatedArgs/injectedContext handling.
      let parsed: any = null
      try {
        parsed = JSON.parse(stdout)
      } catch {
        /* not JSON — ignore stdout */
      }
      if (parsed?.decision === "block") {
        result.blocked = true
        result.stderr = String(parsed.reason ?? "") || `${h.command} blocked via {decision:block}`
        await auditLog({ event: "hook-json-block", command: h.command, reason: result.stderr })
        return result
      }
      // If a hook prints structured JSON on stdout, treat it as arg/context mutation.
      if (parsed) {
        if (parsed.mutatedArgs) result.mutatedArgs = parsed.mutatedArgs
        if (parsed.injectedContext) result.injectedContext = parsed.injectedContext
        if (parsed?.hookSpecificOutput?.additionalContext) {
          result.injectedContext = parsed.hookSpecificOutput.additionalContext
        }
      }
    } catch (err) {
      // Hook crashed — log but don't block by default. Pre-event hooks
      // declared as critical can opt-in via exit code 2 explicitly.
      result.stderr = String(err)
    }
  }
  return result
}
