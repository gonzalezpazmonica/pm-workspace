import { afterEach, expect, test } from "bun:test"
import { mkdtemp, mkdir, readdir, readFile, rm, stat, writeFile } from "node:fs/promises"
import { createHash } from "node:crypto"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { buildManifest, writeManifestIfChanged } from "../lib/manifest"
import { loadHookMap } from "../lib/shell-bridge"
import { SaviaGates } from "../index"

// Space e2e 2026-10-05: el plugin reescribía manifest.json (generated_at) en su directorio de
// instalación al cargarse; cada motor cambiaba el pluginSetHash y Space marcaba ENGINE_INTEGRITY
// DEGRADED. Cargar el plugin no escribe ahí; el manifiesto es determinista y lo genera la instalación.

const roots: string[] = []
const savedEnv = { ...process.env }

afterEach(async () => {
  process.env = { ...savedEnv }
  for (const r of roots.splice(0)) await rm(r, { recursive: true, force: true })
})

async function workspace(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "savia-manifest-test-"))
  roots.push(root)
  await mkdir(join(root, ".claude"), { recursive: true })
  await writeFile(join(root, ".claude/settings.json"), JSON.stringify({
    hooks: { PreToolUse: [{ matcher: "Bash", hooks: [{ type: "command", command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/g.sh' }] }] },
  }))
  return root
}

async function treeHash(dir: string): Promise<string> {
  const h = createHash("sha256")
  for (const name of (await readdir(dir)).sort()) h.update(name).update(await readFile(join(dir, name)))
  return h.digest("hex")
}

test("loading the plugin twice leaves its install dir byte-identical (pluginSetHash stable)", async () => {
  const root = await workspace()
  const pluginDir = join(root, ".plugin-dir")
  await mkdir(pluginDir)
  await writeFile(join(pluginDir, "index.ts"), "// plugin\n")
  process.env.SAVIA_PLUGIN_DIR = pluginDir
  process.env.SAVIA_AUDIT_DIR = join(root, ".audit-test")
  const before = await treeHash(pluginDir)
  await SaviaGates({ $: Bun.$, directory: root } as any)
  const once = await treeHash(pluginDir)
  await SaviaGates({ $: Bun.$, directory: root } as any)
  expect(once).toBe(before)
  expect(await treeHash(pluginDir)).toBe(before)
})

test("buildManifest is deterministic: same registry, same bytes, no timestamp", async () => {
  const root = await workspace()
  const map = await loadHookMap(root)
  const a = buildManifest(map)
  const b = buildManifest(await loadHookMap(root))
  expect(a).toBe(b)
  expect(a).not.toContain("generated_at")
  expect(JSON.parse(a).bindings).toEqual([
    { claudeHook: "g.sh", event: "PreToolUse", matcher: "Bash", handler: "tool.execute.before" },
  ])
})

test("writeManifestIfChanged: writes once, then leaves the file untouched (same mtime)", async () => {
  const root = await workspace()
  const dir = join(root, "out")
  const map = await loadHookMap(root)
  expect(await writeManifestIfChanged(map, dir)).toBe(true)
  const m1 = (await stat(join(dir, "manifest.json"))).mtimeMs
  await Bun.sleep(20)
  expect(await writeManifestIfChanged(map, dir)).toBe(false)
  expect((await stat(join(dir, "manifest.json"))).mtimeMs).toBe(m1)
})
