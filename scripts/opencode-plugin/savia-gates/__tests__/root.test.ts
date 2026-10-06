import { afterEach, expect, test } from "bun:test"
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { resolveProjectRoot } from "../lib/root"
import { SaviaGates } from "../index"

// 2026-10-06: con `opencode run` abierto en un subdirectorio del repo (p. ej. `docs/`), el plugin
// buscaba `docs/.claude/settings.json`, no existía y bloqueaba todo prompt con
// INVALID_HOOK_CONFIGURATION. La raíz es el `worktree` de OpenCode; sin git sigue cerrado.

const roots: string[] = []
const savedEnv = { ...process.env }

afterEach(async () => {
  process.env = { ...savedEnv }
  await Promise.all(roots.splice(0).map((r) => rm(r, { recursive: true, force: true })))
})

const BLOCKING_GUARD = '#!/usr/bin/env bash\nin=$(cat)\ncase "$in" in *PROHIBIDO*) echo "PROHIBIDO bloqueado" >&2; exit 2;; esac\nexit 0\n'

async function workspace(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "savia-root-test-"))
  roots.push(root)
  await mkdir(join(root, ".claude/hooks"), { recursive: true })
  await mkdir(join(root, "docs"), { recursive: true })
  await writeFile(join(root, ".claude/hooks/guard.sh"), BLOCKING_GUARD, { mode: 0o755 })
  await writeFile(join(root, ".claude/settings.json"), JSON.stringify({
    hooks: { UserPromptSubmit: [{ hooks: [{ type: "command", command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/guard.sh' }] }] },
  }))
  return root
}

async function plugin(root: string, directory: string, worktree: string): Promise<any> {
  process.env.SAVIA_AUDIT_DIR = join(root, ".audit-test")
  process.env.SAVIA_PLUGIN_DIR = join(root, ".manifest-test")
  return SaviaGates({ $: Bun.$, directory, worktree } as any)
}

async function prompt(hooks: any, text: string): Promise<string> {
  try {
    await hooks["chat.message"]({ sessionID: "s", agent: "build" }, { message: text, parts: [] })
    return "PASS"
  } catch (e) {
    return String(e)
  }
}

test("resolveProjectRoot: worktree wins; '/' (no git) falls back to the session directory", () => {
  expect(resolveProjectRoot("/repo/docs", "/repo")).toBe("/repo")
  expect(resolveProjectRoot("/repo", "/repo")).toBe("/repo")
  expect(resolveProjectRoot("/tmp/x", "/")).toBe("/tmp/x")
  expect(resolveProjectRoot("/tmp/x", undefined)).toBe("/tmp/x")
})

test("a session opened in a subdirectory uses the repo registry: allowed prompts pass, guarded ones block", async () => {
  const root = await workspace()
  const hooks = await plugin(root, join(root, "docs"), root)
  expect(await prompt(hooks, "Responde solo: OK")).toBe("PASS")
  const blocked = await prompt(hooks, "esto es PROHIBIDO")
  expect(blocked).toContain("PROHIBIDO bloqueado")
  expect(blocked).not.toContain("INVALID_HOOK_CONFIGURATION")
})

test("outside any git repo and without a registry, every prompt is still blocked (fail-closed)", async () => {
  const dir = await mkdtemp(join(tmpdir(), "savia-root-nogit-"))
  roots.push(dir)
  const hooks = await plugin(dir, dir, "/")
  expect(await prompt(hooks, "Responde solo: OK")).toContain("INVALID_HOOK_CONFIGURATION")
})

test("a registry only in the subdirectory is not trusted over the repo root", async () => {
  const root = await workspace()
  await mkdir(join(root, "docs/.claude"), { recursive: true })
  await writeFile(join(root, "docs/.claude/settings.json"), JSON.stringify({ hooks: {} }))
  const hooks = await plugin(root, join(root, "docs"), root)
  expect(await prompt(hooks, "esto es PROHIBIDO")).toContain("PROHIBIDO bloqueado")
})
