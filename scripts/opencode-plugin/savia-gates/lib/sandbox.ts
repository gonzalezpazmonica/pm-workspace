// Sandbox-aware guard input.
//
// Sandbox plugins (opencode-sandbox / sandbox-runtime) rewrite a bash command as
// `bwrap … bash -c '<cmd>'` in `tool.execute.before`. When such a plugin runs
// before savia-gates, hooks receive the wrapped string and anchored patterns
// (`(^|[;&|])rm`, `^\s*sudo`) stop matching: the guard is silently bypassed.
//
// Unwrapping alone is not safe either: `bwrap … -c 'echo hi'; rm -rf x` would
// unwrap to `echo hi`. So hooks see BOTH forms and the stricter result wins.

/** The command inside a sandbox wrapper, or `cmd` unchanged if it is not a clean wrapper. */
export function unwrapSandbox(cmd: string): string {
  if (!cmd.trimStart().startsWith("bwrap ")) return cmd
  const i = cmd.lastIndexOf(" -c '")
  if (i < 0) return cmd
  const rest = cmd.slice(i + 5)
  const j = rest.lastIndexOf("'")
  // Only a wrapper if nothing but closing quotes follows the final single quote.
  if (j <= 0 || !/^[\\"\s]*$/.test(rest.slice(j + 1))) return cmd
  return rest.slice(0, j).replaceAll("'\\''", "'")
}

/** Tool inputs the PreToolUse hooks must evaluate: the original first, then the unwrapped one. */
export function guardVariants(tool: string, args: Record<string, unknown>): Record<string, unknown>[] {
  const command = args?.command
  if (tool !== "bash" || typeof command !== "string") return [args]
  const inner = unwrapSandbox(command)
  return inner === command ? [args] : [args, { ...args, command: inner }]
}
