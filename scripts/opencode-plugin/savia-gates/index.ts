// savia-gates — OpenCode v1.14 plugin
// Spec: SE-077 (docs/propuestas/SE-077-opencode-replatform-v114.md)
// Doc:  docs/rules/domain/opencode-savia-bridge.md
//
// Strategy: this plugin does NOT re-implement Claude Code hooks. It reads the
// SAME `.claude/settings.json` Claude Code already uses, builds an event→hooks
// map, and delegates to the existing bash files via Bun's `$` shell API.
// Exit code 2 from a hook == block; 0 == pass; JSON on stdout == arg mutation.
// AUTONOMOUS_REVIEWER policy is enforced via `permission.ask` returning
// "deny" for destructive ops on agent/* branches when no human reviewer is on
// the line.

import type { Plugin, PluginInput } from "@opencode-ai/plugin"
import { loadHookMap, runHooksForEvent } from "./lib/shell-bridge"
import { decidePermission } from "./lib/permission"
import { auditLog } from "./lib/audit"
import { writeManifest } from "./lib/manifest"

function resolveProjectRoot(directory: string | undefined): string {
  if (directory) return directory
  return process.env.PROJECT_ROOT || `${process.env.HOME}/claude`
}

export const SaviaGates: Plugin = async (ctx: PluginInput) => {
  const { $, directory } = ctx
  const root = resolveProjectRoot(directory)
  const hookMap = await loadHookMap($, root)

  await writeManifest(hookMap)
  await auditLog({ event: "plugin-loaded", root, events: Object.keys(hookMap).length })

  return {
    "tool.execute.before": async (input, output) => {
      const payload = JSON.stringify({
        hook_event_name: "PreToolUse",
        tool_name: input.tool,
        tool_input: output.args,
        session_id: input.sessionID,
        call_id: input.callID,
      })
      const result = await runHooksForEvent($, root, hookMap, "PreToolUse", input.tool, payload)
      if (result.blocked) {
        await auditLog({ event: "tool-blocked", tool: input.tool, reason: result.stderr })
        throw new Error(`savia-gates: ${result.stderr || "PreToolUse blocked"}`)
      }
      if (result.mutatedArgs) output.args = result.mutatedArgs
    },

    "tool.execute.after": async (input, output) => {
      const payload = JSON.stringify({
        hook_event_name: "PostToolUse",
        tool_name: input.tool,
        tool_input: input.args,
        tool_output: output.output,
        session_id: input.sessionID,
        call_id: input.callID,
      })
      const result = await runHooksForEvent($, root, hookMap, "PostToolUse", input.tool, payload)
      if (result.blocked) {
        await auditLog({ event: "post-hook-warning", tool: input.tool, reason: result.stderr })
      }
    },

    "chat.message": async (input, output) => {
      const payload = JSON.stringify({
        hook_event_name: "UserPromptSubmit",
        session_id: input.sessionID,
        agent: input.agent,
        prompt_text: typeof output.message === "string" ? output.message : JSON.stringify(output.message),
      })
      const result = await runHooksForEvent($, root, hookMap, "UserPromptSubmit", null, payload)
      if (result.blocked) {
        await auditLog({ event: "prompt-blocked", reason: result.stderr })
        throw new Error(`savia-gates: prompt blocked — ${result.stderr}`)
      }
      if (result.injectedContext) {
        output.parts = output.parts ?? []
        output.parts.push({ type: "text", text: result.injectedContext })
      }
    },

    "permission.ask": async (input, output) => {
      const decision = await decidePermission($, root, input)
      if (decision !== "ask") {
        output.status = decision
        await auditLog({ event: "permission-decision", decision, tool: (input as any).tool ?? "unknown" })
      }
    },

    "command.execute.before": async (input, output) => {
      // Slash commands are gated through the same PreToolUse pipeline so
      // credential-leak / branch-safety checks apply uniformly.
      const payload = JSON.stringify({
        hook_event_name: "CommandExecuteBefore",
        command: input.command,
        session_id: input.sessionID,
        arguments: input.arguments,
      })
      const result = await runHooksForEvent($, root, hookMap, "PreToolUse", null, payload)
      if (result.blocked) {
        throw new Error(`savia-gates: command ${input.command} blocked — ${result.stderr}`)
      }
    },

    "event": async (input) => {
      // Map OpenCode generic events onto Claude Code categories.
      const ev = (input as any).event
      if (!ev || typeof ev.type !== "string") return
      const map: Record<string, string> = {
        "session.created": "SessionStart",
        "session.deleted": "SessionEnd",
        "session.stopped": "Stop",
        "subagent.completed": "SubagentStop",
        "subagent.started": "SubagentStart",
        "task.created": "TaskCreated",
        "task.completed": "TaskCompleted",
      }
      const ccEvent = map[ev.type]
      if (!ccEvent) return
      const payload = JSON.stringify({ hook_event_name: ccEvent, event: ev })
      await runHooksForEvent($, root, hookMap, ccEvent, null, payload).catch(() => {})
    },

    "experimental.session.compacting": async (input, _output) => {
      const payload = JSON.stringify({ hook_event_name: "PreCompact", session_id: input.sessionID })
      await runHooksForEvent($, root, hookMap, "PreCompact", null, payload).catch(() => {})
    },
  }
}

export default SaviaGates
