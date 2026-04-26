// permission.ts — AUTONOMOUS_REVIEWER policy enforcement
//
// Default Claude Code policy: never auto-merge / push --force / approve PR
// from agent/* branches. OpenCode exposes `permission.ask` so we can return
// "deny" deterministically before the human is even prompted, instead of
// trusting the runtime to ask every time.

const DESTRUCTIVE_PATTERNS: RegExp[] = [
  /\bgit\s+push\s+--force/i,
  /\bgit\s+push\s+--force-with-lease/i,
  /\bgit\s+reset\s+--hard\b/i,
  /\bgit\s+branch\s+-D\b/i,
  /\bgit\s+rebase\s+-i\b/i,
  /\bgh\s+pr\s+merge\b/i,
  /\bgh\s+pr\s+(approve|review\s+--approve)\b/i,
  /\brm\s+-rf\s+\//i,
]

async function detectAgentBranch($: any, projectRoot: string): Promise<boolean> {
  try {
    const r = await $`git -C ${projectRoot} symbolic-ref --short HEAD`.quiet().nothrow().text()
    const branch = String((r as any)?.stdout ?? r ?? "").trim()
    return branch.startsWith("agent/") || branch.startsWith("spec-")
  } catch {
    return false
  }
}

function isDestructive(input: any): boolean {
  // Inputs we get vary across hook signatures; coerce to a single string.
  const candidate =
    typeof input?.command === "string" ? input.command :
    typeof input?.args?.command === "string" ? input.args.command :
    JSON.stringify(input ?? {})
  return DESTRUCTIVE_PATTERNS.some((re) => re.test(candidate))
}

function reviewerConfigured(): boolean {
  // Mirrors pm-config.local.md: AUTONOMOUS_REVIEWER must be set for autonomous mode.
  const v = process.env.AUTONOMOUS_REVIEWER ?? ""
  return v.startsWith("@") && v.length > 1
}

export async function decidePermission(
  $: any,
  projectRoot: string,
  input: any,
): Promise<"allow" | "deny" | "ask"> {
  const onAgentBranch = await detectAgentBranch($, projectRoot)
  if (!onAgentBranch) return "ask"
  if (isDestructive(input)) {
    if (!reviewerConfigured()) return "deny"
    return "deny"  // even with reviewer configured, agent/* never auto-allows destructive ops
  }
  return "ask"
}
