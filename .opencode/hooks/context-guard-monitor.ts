// context-guard-monitor.ts -- OpenCode hook (TypeScript variant). SPEC-127.
// Fires before each model call in agents with context_guard.enabled: true.
// Delegates to Python CLI (Rule 26). Non-blocking per D-1.
// TODO: typecheck con bun cuando CI lo soporte (PLUGIN-TYPECHECK-CI-01)
import { execSync } from "child_process";
import * as path from "path";

const WORKSPACE_DIR = path.resolve(__dirname, "..", "..");
const BASE_DIR = path.join(WORKSPACE_DIR, "output", "context-guard");
const agentFile = process.env["OPENCODE_AGENT_FILE"] ?? "";
const runId = process.env["OPENCODE_RUN_ID"] ?? "unknown";

function main(): void {
  if (!agentFile) { process.exit(0); }
  try {
    const cmd = [
      "python3", "-m", "scripts.lib.context_guard.cli",
      "--base-dir", BASE_DIR,
      "list", runId,
    ].join(" ");
    execSync(cmd, { cwd: WORKSPACE_DIR, stdio: "ignore" });
  } catch (_e) {
    // Non-blocking: hook errors never abort agent execution (D-1 optional).
  }
}

main();
