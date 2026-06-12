// subagent-audience-filter.ts — SE-221 Slice 3 (OpenCode port)
//
// Capa context-engineering of Savia Shield: PreToolUse `task` audience filter.
// Port of `.claude/hooks/subagent-audience-filter.sh` for OpenCode v1.14+.
//
// When a subagent is invoked via the `task` tool, this guard inspects the
// audience graph (output/context-audience-graph.json) and logs which lazy
// imports the subagent has audience access to vs which are denied. The
// logic is "deny-by-default" for unknown subagents (they only see files
// marked `audience: all-agents`).
//
// The hook is NON-BLOCKING and NON-MUTATING:
// - Passes the task invocation through unchanged.
// - Side-effect: appends one line to output/audience-filter.jsonl with the
//   filtered allowed/denied lists. Other components (e.g., a context
//   loader) may consume that log to enforce the filter at load time.
//
// Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-16)

import { extractToolName, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

function workspaceRoot(): string {
  return process.env.SAVIA_WORKSPACE_DIR ?? process.cwd();
}

function graphPath(): string {
  return workspaceRoot() + "/output/context-audience-graph.json";
}

function auditLogPath(): string {
  return process.env.AUDIENCE_FILTER_AUDIT_LOG ?? (workspaceRoot() + "/output/audience-filter.jsonl");
}

interface AudienceGraph {
  agents: Record<string, string[]>;
}

interface FilterResult {
  subagent: string;
  allowed: string[];
  denied: string[];
  n_allowed: number;
  n_denied: number;
}

async function loadGraph(): Promise<AudienceGraph | null> {
  try {
    const { readFile } = await import("node:fs/promises");
    const raw = await readFile(graphPath(), "utf-8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || !parsed.agents) return null;
    return parsed as AudienceGraph;
  } catch {
    return null;
  }
}

function computeFilter(subagent: string, graph: AudienceGraph): FilterResult {
  const agents = graph.agents ?? {};
  const allowedSet = new Set<string>();
  for (const p of agents[subagent] ?? []) allowedSet.add(p);
  for (const p of agents["all-agents"] ?? []) allowedSet.add(p);

  // All audience-targeted files across the graph
  const allFiles = new Set<string>();
  for (const list of Object.values(agents)) {
    for (const p of list) allFiles.add(p);
  }

  // denied = files with audience that don't include subagent or all-agents
  const deniedSet = new Set<string>();
  for (const f of allFiles) if (!allowedSet.has(f)) deniedSet.add(f);

  // humans-only override: always denied for any subagent
  const humansOnly = new Set<string>(agents["humans-only"] ?? []);
  for (const f of humansOnly) {
    allowedSet.delete(f);
    if (allFiles.has(f)) deniedSet.add(f);
  }

  const allowed = Array.from(allowedSet).sort();
  const denied = Array.from(deniedSet).sort();
  return {
    subagent,
    allowed,
    denied,
    n_allowed: allowed.length,
    n_denied: denied.length,
  };
}

async function appendAudit(filter: FilterResult): Promise<void> {
  try {
    const { appendFile, mkdir } = await import("node:fs/promises");
    const { dirname } = await import("node:path");
    const path = auditLogPath();
    await mkdir(dirname(path), { recursive: true });
    const ts = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
    const entry = JSON.stringify({ ts, filter });
    await appendFile(path, entry + "\n");
  } catch {
    // Best-effort audit logging
  }
}

export async function subagentAudienceFilter(input: ToolInput, _output: ToolOutput): Promise<void> {
  try {
    const tool = extractToolName(input);
    if (tool !== "task") return;

    const args = (input as any)?.args ?? {};
    const subagent = args?.subagent_type;
    if (typeof subagent !== "string" || subagent.length === 0) return;

    const graph = await loadGraph();
    if (!graph) return;

    const filter = computeFilter(subagent, graph);
    await appendAudit(filter);
  } catch {
    // Best-effort: never throw from a before-guard.
  }
}
