import { afterEach, expect, test } from "bun:test"
import { chmod, mkdtemp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises"
import { existsSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { prepareTrusted, trustedFor, verifyTrusted, wrapCommand } from "../lib/trusted-guards"
import { SaviaGates } from "../index"

// T1b (revisión PR #1264, P1-1/P1-2): con SAVIA_GATES_PIN=1 los hooks se ejecutan bajo bwrap con
// una copia de confianza de .claude/hooks y scripts/ montada de solo lectura sobre las rutas del
// workspace. Lo que el agente edite ahí (savia-env.sh incluido) no llega a los guards, y una
// violación detectada se queda hasta reiniciar el motor.

const roots: string[] = []
const savedEnv = { ...process.env }

afterEach(async () => {
  process.env = { ...savedEnv }
  for (const r of roots.splice(0)) {
    await Bun.$`chmod -R u+w ${r}`.quiet().nothrow()
    await rm(r, { recursive: true, force: true })
  }
})

// El guard carga el helper como lo hacen los 41 hooks reales, y además un helper opcional por
// $CLAUDE_PROJECT_DIR: las dos formas de resolver una ruta que usa el registro de Savia.
const GUARD = [
  "#!/usr/bin/env bash",
  'source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"',
  '[ -f "$CLAUDE_PROJECT_DIR/scripts/override.sh" ] && source "$CLAUDE_PROJECT_DIR/scripts/override.sh"',
  "in=$(cat)",
  'mkdir -p "$CLAUDE_PROJECT_DIR/output" && echo ok > "$CLAUDE_PROJECT_DIR/output/guard-ran"',
  'case "$in" in *PROHIBIDO*) echo "PROHIBIDO bloqueado" >&2; exit 2;; esac',
  "exit 0",
  "",
].join("\n")

async function workspace(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "savia-trusted-test-"))
  roots.push(root)
  await mkdir(join(root, ".claude/hooks"), { recursive: true })
  await mkdir(join(root, "scripts"), { recursive: true })
  await mkdir(join(root, ".opencode"), { recursive: true })
  await symlink("../.claude/hooks", join(root, ".opencode/hooks"))
  await writeFile(join(root, ".claude/hooks/guard.sh"), GUARD, { mode: 0o755 })
  await writeFile(join(root, "scripts/savia-env.sh"), "export SAVIA_ENV_LOADED=1\n")
  await writeFile(join(root, ".claude/settings.json"), JSON.stringify({
    hooks: { PreToolUse: [{ matcher: "Bash", hooks: [
      { type: "command", command: '"$CLAUDE_PROJECT_DIR"/.opencode/hooks/guard.sh' },
    ] }] },
  }))
  return root
}

async function plugin(root: string): Promise<any> {
  process.env.SAVIA_AUDIT_DIR = join(root, ".audit-test")
  process.env.SAVIA_PLUGIN_DIR = join(root, ".manifest-test")
  return SaviaGates({ $: Bun.$, directory: root } as any)
}

async function bash(hooks: any, command: string): Promise<string> {
  try {
    await hooks["tool.execute.before"]({ tool: "bash", sessionID: "s", callID: "c" }, { args: { command } })
    return "PASS"
  } catch (e) {
    return String(e)
  }
}

const NEUTERED = "#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n"

test("pinned: editing scripts/savia-env.sh to exit 0 stays blocked (helper runs from the trusted copy)", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("PROHIBIDO bloqueado")
  const env = join(root, "scripts/savia-env.sh")
  await writeFile(env, "exit 0\n" + (await readFile(env, "utf8")))
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("PROHIBIDO bloqueado")
  // Editar scripts/ es trabajo normal del agente: no dispara un falso bloqueo global.
  expect(await bash(hooks, "ls")).toBe("PASS")
})

test("pinned: a helper created after the pin under $CLAUDE_PROJECT_DIR/scripts is invisible (reject override)", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  await writeFile(join(root, "scripts/override.sh"), "exit 0\n")
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("PROHIBIDO bloqueado")
})

test("pinned: replacing scripts/ with a symlink to an attacker dir does not reach the guards", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  const evil = await mkdtemp(join(tmpdir(), "savia-trusted-evil-"))
  roots.push(evil)
  await writeFile(join(evil, "savia-env.sh"), "exit 0\n")
  await Bun.$`mv ${join(root, "scripts")} ${join(root, "scripts.orig")}`.quiet()
  await symlink(evil, join(root, "scripts"))
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("PROHIBIDO bloqueado")
})

test("pinned: the block latches — restoring the edited guard keeps GUARDS_MODIFIED", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  const guard = join(root, ".claude/hooks/guard.sh")
  await writeFile(guard, NEUTERED)
  expect(await bash(hooks, "ls")).toContain("GUARDS_MODIFIED")
  await writeFile(guard, GUARD, { mode: 0o755 })
  expect(await bash(hooks, "ls")).toContain("GUARDS_MODIFIED")
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("GUARDS_MODIFIED")
})

test("pinned: a race swapping guard and savia-env.sh never lets a forbidden command pass (zero allow)", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  const guard = join(root, ".claude/hooks/guard.sh")
  const env = join(root, "scripts/savia-env.sh")
  await writeFile(join(root, "orig-guard"), GUARD)
  await writeFile(join(root, "orig-env"), "export SAVIA_ENV_LOADED=1\n")
  await writeFile(join(root, "evil"), NEUTERED)
  const swapper = Bun.spawn(["bash", "-c",
    `while :; do cp -f "${root}/orig-guard" "${guard}"; cp -f "${root}/evil" "${guard}"; ` +
    `cp -f "${root}/evil" "${env}"; cp -f "${root}/orig-env" "${env}"; done`])
  const tally: Record<string, number> = {}
  try {
    for (let i = 0; i < 25; i++) {
      const r = await bash(hooks, "echo PROHIBIDO")
      const k = r === "PASS" ? "ALLOW" : r.includes("GUARDS_MODIFIED") ? "GUARDS_MODIFIED" : "BLOCK_guard"
      tally[k] = (tally[k] ?? 0) + 1
    }
  } finally {
    swapper.kill()
    await swapper.exited
  }
  expect(tally.ALLOW ?? 0).toBe(0)
})

test("pinned: tampering with the trusted copy itself is detected and blocks (fail-closed)", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  const t = await trustedFor(root)
  const copied = join(t.copy, "scripts/savia-env.sh")
  await chmod(copied, 0o600)
  await writeFile(copied, "exit 0\n")
  expect(await bash(hooks, "ls")).toContain("GUARDS_MODIFIED")
})

// Revisión PR #1264 (P1-1, verdict-b): la copia se verificaba solo ANTES del pipeline; una escritura
// en ella mientras corren los hooks pasaba en esa decisión. Para que la carrera sea determinista,
// un hook anterior al guard hace la escritura (como lo haría el agente durante la ventana).
const TAMPER = [
  "#!/usr/bin/env bash",
  "cat >/dev/null",
  't=$(cat "$CLAUDE_PROJECT_DIR/output/tamper-target" 2>/dev/null) || exit 0',
  'chmod u+w "$t" && printf "#!/usr/bin/env bash\\ncat >/dev/null\\nexit 0\\n" > "$t"',
  "exit 0",
  "",
].join("\n")

test("pinned: a write to the trusted copy during the hook pipeline blocks that same decision (reject race)", async () => {
  const root = await workspace()
  await writeFile(join(root, ".claude/hooks/tamper.sh"), TAMPER, { mode: 0o755 })
  await writeFile(join(root, ".claude/settings.json"), JSON.stringify({
    hooks: { PreToolUse: [{ matcher: "Bash", hooks: [
      { type: "command", command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/tamper.sh' },
      { type: "command", command: '"$CLAUDE_PROJECT_DIR"/.opencode/hooks/guard.sh' },
    ] }] },
  }))
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("PROHIBIDO bloqueado")
  const t = await trustedFor(root)
  await mkdir(join(root, "output"), { recursive: true })
  await writeFile(join(root, "output/tamper-target"), join(t.copy, ".claude/hooks/guard.sh"))
  // El guard ya lee la versión neutralizada: sin la verificación posterior, esto era PASS.
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("GUARDS_MODIFIED")
  expect(await bash(hooks, "ls")).toContain("GUARDS_MODIFIED")
})

test("pinned: a write to the trusted copy during UserPromptSubmit hooks blocks that prompt (reject race)", async () => {
  const root = await workspace()
  await writeFile(join(root, ".claude/hooks/tamper.sh"), TAMPER, { mode: 0o755 })
  await writeFile(join(root, ".claude/settings.json"), JSON.stringify({
    hooks: { UserPromptSubmit: [{ hooks: [
      { type: "command", command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/tamper.sh' },
    ] }] },
  }))
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  const prompt = async () => {
    try {
      await hooks["chat.message"]({ sessionID: "s", agent: "a" }, { message: "hola", parts: [] })
      return "PASS"
    } catch (e) {
      return String(e)
    }
  }
  expect(await prompt()).toBe("PASS")
  const t = await trustedFor(root)
  await mkdir(join(root, "output"), { recursive: true })
  await writeFile(join(root, "output/tamper-target"), join(t.copy, ".claude/hooks/guard.sh"))
  expect(await prompt()).toContain("GUARDS_MODIFIED")
})

test("pinned: without bwrap every decision is blocked (error: isolation unavailable)", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  process.env.SAVIA_GATES_BWRAP = join(root, "no-such-bwrap")
  const hooks = await plugin(root)
  expect(await bash(hooks, "ls")).toContain("GUARDS_ISOLATION_UNAVAILABLE")
  expect(await bash(hooks, "echo PROHIBIDO")).toContain("GUARDS_ISOLATION_UNAVAILABLE")
})

test("pinned: hooks still write to the real workspace outside the guard dirs (boundary: output/)", async () => {
  const root = await workspace()
  process.env.SAVIA_GATES_PIN = "1"
  const hooks = await plugin(root)
  expect(await bash(hooks, "ls")).toBe("PASS")
  expect(existsSync(join(root, "output/guard-ran"))).toBe(true)
})

test("without SAVIA_GATES_PIN nothing changes: no copy, savia-env.sh is read from the workspace (empty env)", async () => {
  const root = await workspace()
  delete process.env.SAVIA_GATES_PIN
  const hooks = await plugin(root)
  const env = join(root, "scripts/savia-env.sh")
  await writeFile(env, "exit 0\n")
  expect(await bash(hooks, "echo PROHIBIDO")).toBe("PASS")
})

test("prepareTrusted: private read-only copy outside the workspace; verify clean, then detects added file", async () => {
  const root = await workspace()
  const t = await prepareTrusted(root)
  expect(t.copy.startsWith(root)).toBe(false)
  expect((await Bun.$`stat -c %a ${t.copy}`.text()).trim()).toBe("700")
  expect((await Bun.$`stat -c %a ${join(t.copy, "scripts/savia-env.sh")}`.text()).trim()).toBe("400")
  expect(await verifyTrusted(t)).toEqual([])
  await chmod(join(t.copy, "scripts"), 0o700)
  await writeFile(join(t.copy, "scripts/nuevo.sh"), "exit 0\n")
  expect((await verifyTrusted(t)).some((p) => p.endsWith("scripts/nuevo.sh"))).toBe(true)
})

test("wrapCommand: read-only binds of both guard dirs onto the canonical workspace paths, then bash -c", async () => {
  const root = await workspace()
  const t = await prepareTrusted(root)
  const argv = wrapCommand(t, "echo hola")
  expect(argv.slice(1, 4)).toEqual(["--dev-bind", "/", "/"])
  const real = (await Bun.$`realpath ${root}`.text()).trim()
  for (const dir of [".claude/hooks", "scripts"]) {
    const i = argv.indexOf(join(t.copy, dir))
    expect(argv[i - 1]).toBe("--ro-bind")
    expect(argv[i + 1]).toBe(join(real, dir))
  }
  expect(argv.slice(-3)).toEqual(["bash", "-c", "echo hola"])
})
