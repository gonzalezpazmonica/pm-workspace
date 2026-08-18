// dispatch-trace.ts — SE-313 S7c (OpenCode port)
//
// Capa observability de Savia Shield: PreToolUse `task` dispatch tracer.
// Port of `scripts/subagent-dispatch-gate.sh` for OpenCode v1.14+.
//
// When a subagent is invoked via the `task` tool, this guard:
//  1. Resolves the agent model (tier→model via ~/.savia/preferences.yaml).
//  2. Verifies the resolved model exists in config/model-registry.json
//     (cached `opencode models`), falling back to a direct runtime query.
//  3. Appends dispatch.resolved | dispatch.failed to
//     output/telemetry-events.jsonl (schema savia.event/1.0).
//
// NON-BLOCKING by default (mode=shadow): a model resolution failure is
// logged and surfaced as a stderr warning, but does NOT abort the dispatch.
// Set SAVIA_DISPATCH_GATE=block to fail the task on unresolvable model.
//
// Spec: docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md

import { extractToolName, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

function workspaceRoot(): string {
  return process.env.SAVIA_WORKSPACE_DIR ?? process.cwd();
}

function telemetryPath(): string {
  return process.env.SAVIA_TELEMETRY_FILE ?? (workspaceRoot() + "/output/telemetry-events.jsonl");
}

function registryPath(): string {
  return workspaceRoot() + "/config/model-registry.json";
}

function prefsPath(): string {
  return process.env.SAVIA_PREFS ?? (process.env.HOME + "/.savia/preferences.yaml");
}

interface Registry {
  models?: string[];
}

// ── Preferences parser (mirrors savia-env.sh savia_resolve_model) ──────────

async function loadTierMap(): Promise<Record<string, string>> {
  try {
    const { readFile } = await import("node:fs/promises");
    const raw = await readFile(prefsPath(), "utf-8");
    const map: Record<string, string> = {};
    for (const line of raw.split(/\r?\n/)) {
      const m = line.match(/^\s*(model_heavy|model_mid|model_fast|provider)\s*:\s*(.+?)\s*$/);
      if (m) {
        const key = m[1];
        const val = m[2].replace(/^["']|["']$/g, "").trim();
        if (key === "provider") map.provider = val;
        else map[key.replace("model_", "")] = val;
      }
    }
    return map;
  } catch {
    return {};
  }
}

function resolveModel(raw: string, tierMap: Record<string, string>): string {
  return tierMap[raw] ?? raw;
}

// ── Registry check ──────────────────────────────────────────────────────────

async function registryHas(id: string): Promise<boolean> {
  try {
    const { readFile } = await import("node:fs/promises");
    const raw = await readFile(registryPath(), "utf-8");
    const reg: Registry = JSON.parse(raw);
    if (Array.isArray(reg.models)) return reg.models.includes(id);
  } catch {
    // fall through to runtime query
  }
  try {
    const { execFile } = await import("node:child_process");
    const out = await new Promise<string>((resolve, reject) => {
      execFile("opencode", ["models"], { timeout: 8000 }, (err, stdout) => {
        if (err) reject(err);
        else resolve(stdout);
      });
    });
    return out.split(/\r?\n/).some((l) => l.trim() === id);
  } catch {
    return false; // registry unreachable → do not block, only warn
  }
}

// ── Telemetry append ────────────────────────────────────────────────────────

async function appendEvent(event: string, attrs: Record<string, string | number>): Promise<void> {
  try {
    const { appendFile, mkdir } = await import("node:fs/promises");
    const { dirname } = await import("node:path");
    await mkdir(dirname(telemetryPath()), { recursive: true });
    const ts = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
    const spanId = Array.from({ length: 16 }, () => Math.floor(Math.random() * 16).toString(16)).join("");
    const traceId = Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join("");
    const base: Record<string, unknown> = {
      schema: "savia.event/1.0",
      ts,
      trace_id: traceId,
      span_id: spanId,
      event,
    };
    const entry = JSON.stringify({ ...base, ...attrs });
    await appendFile(telemetryPath(), entry + "\n");
  } catch {
    // Best-effort: telemetry must never throw.
  }
}

// ── Main guard ──────────────────────────────────────────────────────────────

export async function dispatchTrace(input: ToolInput, output: ToolOutput): Promise<void> {
  try {
    const tool = extractToolName(input);
    if (tool !== "task") return;

    // Real OpenCode v1.14+ contract: args live on output.args; input.args is
    // a legacy/Claude-Code shape. Reading input.args alone would leave
    // subagent_type undefined and silently skip telemetry.
    const args = (output as any)?.args ?? (input as any)?.args ?? {};
    const subagent = args?.subagent_type;
    if (typeof subagent !== "string" || subagent.length === 0) return;

    const tierMap = await loadTierMap();
    // Agent model from its own config (tier name or id); fallback to mid tier.
    const configured = (args as any)?.model ?? "mid";
    const resolved = resolveModel(String(configured), tierMap);

    const ok = await registryHas(resolved);
    // SE-313 S3: atributos GenAI semconv — system provider + modelo real.
    const provider = resolved.includes("/")
      ? resolved.slice(0, resolved.indexOf("/"))
      : (tierMap.provider ?? "unknown");
    const genAi: Record<string, string | number> = {
      gen_ai_system: provider,
      gen_ai_request_model: String(configured),
      gen_ai_response_model: resolved,
    };
    if (ok) {
      await appendEvent("dispatch.resolved", {
        agent_name: subagent,
        requested_model: String(configured),
        resolved_model: resolved,
        ...genAi,
      });
      return;
    }

    await appendEvent("dispatch.failed", {
      agent_name: subagent,
      requested_model: String(configured),
      resolved_model: resolved,
      error: `Model not found: ${resolved}`,
      ...genAi,
    });
    process.stderr.write(
      `[savia-shield:dispatch] WARN ${subagent}: '${resolved}' not resolvable. ` +
        `Fix ~/.savia/preferences.yaml (provider-prefixed model ids).\n`,
    );

    if (process.env.SAVIA_DISPATCH_GATE === "block") {
      throw new Error(`BLOCKED [dispatch-trace]: model '${resolved}' not in runtime registry.`);
    }
  } catch (e) {
    if (e instanceof Error && e.message.includes("BLOCKED")) throw e;
    // Never throw from a before-guard on telemetry errors.
  }
}
