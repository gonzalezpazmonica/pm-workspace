// block-commit-to-main.ts — SE-337 (guarda TS del runtime OpenCode)
//
// Bloquea `git commit` cuando la rama actual es main/master, mecanizando la
// regla autonomous-safety "NUNCA commit en ramas de humanos". Contraparte TS
// del hook shell `.opencode/hooks/block-commit-to-main.sh`, con la diferencia
// clave: este guard está conectado al runtime OpenCode (tool.execute.before),
// mientras el hook shell solo existía como script sin registro — por eso los
// commits en main pasaron sin oposición.
//
// Bypass consciente de la operadora: SAVIA_ALLOW_MAIN_COMMIT=1 (queda
// registrado en el log, no es silencioso).
//
// PURE_BASH/TS, sin red (CRIT-001). Coste ~5-10ms (subprocess read-only).

import { extractToolName, extractCommand, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

async function currentBranch(): Promise<string> {
  // read-only: git branch --show-current, no modifica nada.
  // TEST_BRANCH permite a los tests simular la rama sin depender del repo real.
  if (process.env.TEST_BRANCH) return process.env.TEST_BRANCH;
  try {
    const { spawnSync } = await import("node:child_process");
    const res = spawnSync("git", ["branch", "--show-current"], { encoding: "utf8", timeout: 3000 });
    return (res.stdout || "").trim();
  } catch {
    return "";
  }
}

export async function blockCommitToMain(input: ToolInput, output: ToolOutput): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input, output);
  if (!command || !/\bgit\s+commit\b/.test(command)) return;

  // Bypass consciente de la operadora: se registra, no es silencioso.
  if (process.env.SAVIA_ALLOW_MAIN_COMMIT === "1") {
    try {
      const fs = await import("node:fs");
      const path = await import("node:path");
      const log = path.join(process.cwd(), "output", "turn-sdlc", "commit-guard.jsonl");
      fs.appendFileSync(
        log,
        JSON.stringify({
          ts: new Date().toISOString(),
          action: "commit",
          verdict: "bypass",
          env: "SAVIA_ALLOW_MAIN_COMMIT=1",
        }) + "\n",
      );
    } catch { /* best-effort */ }
    return;
  }

  const branch = await currentBranch();
  if (branch !== "main" && branch !== "master") return; // rama segura (agent/*, feature/*)

  try {
    const fs = await import("node:fs");
    const path = await import("node:path");
    const log = path.join(process.cwd(), "output", "turn-sdlc", "commit-guard.jsonl");
    fs.appendFileSync(
      log,
      JSON.stringify({ ts: new Date().toISOString(), branch, action: "commit", verdict: "block" }) + "\n",
    );
  } catch { /* best-effort */ }

  const reason = `Commit en rama humana (${branch}) bloqueado por autonomous-safety (NUNCA commit en main/master). Crea una rama agent/* y commitea ahí: git checkout -b agent/<tarea>. Si es intencional de la operadora, repítelo con SAVIA_ALLOW_MAIN_COMMIT=1 (queda registrado).`;
  throw new Error(`BLOCKED [commit-to-main]: ${reason}`);
}