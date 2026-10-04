// trusted-guards.ts — los guards del modo mediado corren desde una copia de confianza (T1b)
//
// El pin por hash (guard-pin.ts) detecta cambios en lo que fija, pero un hook carga mucho más:
// 41 hooks hacen `source .../scripts/savia-env.sh`, otros `$LIB_DIR/...`, `$SAVIA_ENV`,
// `$CLAUDE_PROJECT_DIR/scripts/...`, y el script se lee de disco DESPUÉS de verificar (TOCTOU).
// Resolver ese cierre estáticamente es frágil (rutas dinámicas) y fijar scripts/ entero
// bloquearía el motor cada vez que el agente edita un script, que es su trabajo normal.
//
// Por eso, con SAVIA_GATES_PIN=1, la primera carga de un directorio copia `.claude/hooks`,
// `scripts/` y el registro a un directorio privado (0700, ficheros de solo lectura, fuera del
// workspace) y cada hook corre bajo `bwrap --dev-bind / /` con esa copia montada de solo lectura
// sobre las rutas del workspace (y sobre los alias que usa el registro, como
// `.opencode/hooks -> ../.claude/hooks`). BASH_SOURCE, `$CLAUDE_PROJECT_DIR` y los enlaces
// resuelven igual que antes, sin reescribir una ruta; el resto del workspace (git, output/, data/)
// sigue siendo el real. Una edición del agente en esos directorios —o cambiarlos por un enlace—
// no llega a los guards. La copia se vigila por (inodo, tamaño, ctime, modo): ctime no se puede
// fijar desde espacio de usuario, así que cualquier escritura o chmod en ella se detecta.
//
// Mismo diseño que Savia Space (crates/space-hooks/src/trusted.rs). Sin bwrap no hay aislamiento
// y el modo fijado bloquea todo (fail-closed). Límites: la copia sale del disco en la primera
// carga (no de HEAD); no cubre `.venv` (lo fija guard-pin solo como fichero `bin/activate`) ni lo
// que un hook lea fuera de esos directorios.

import { copyFile, lstat, mkdir, mkdtemp, readFile, readdir, readlink, realpath, symlink, chmod } from "node:fs/promises"
import { lstatSync, mkdirSync, readdirSync, readlinkSync, realpathSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, relative, sep } from "node:path"

export const OVERLAY_DIRS = [".claude/hooks", "scripts"] as const
export const REGISTRY = ".claude/settings.json"
const SKIP_DIRS = new Set([".git", "node_modules", "target", "__pycache__"])

export interface TrustedGuards {
  /** Workspace canónico. */
  workspace: string
  /** Directorio privado con la copia (mismas rutas relativas que el workspace). */
  copy: string
  bwrap: string
  /** Montajes de solo lectura: origen en la copia → destino relativo al workspace. */
  mounts: Array<{ from: string; to: string }>
  /** Firma de cada entrada de la copia al prepararla. */
  sigs: Map<string, string>
}

function signature(path: string): string | null {
  try {
    const s = lstatSync(path, { bigint: true })
    const link = s.isSymbolicLink() ? `:${readlinkSync(path)}` : ""
    return `${s.ino}:${s.size}:${s.ctimeNs}:${s.mode}${link}${s.isDirectory() ? ":d" : ""}`
  } catch {
    return null // desaparecida: la comparación la cuenta como cambio
  }
}

// Síncrono a propósito: ~1400 lstat por decisión cuestan unos pocos ms; con promesas, decenas.
function snapshot(root: string): Map<string, string> {
  const out = new Map<string, string>()
  const stack = [root]
  while (stack.length) {
    const p = stack.pop() as string
    const sig = signature(p)
    if (sig === null) continue
    out.set(p, sig)
    if (!sig.endsWith(":d")) continue
    let names: string[] = []
    try {
      names = readdirSync(p)
    } catch (e) {
      out.set(p, `${sig}:unreadable:${e}`) // ilegible: distinto de la firma guardada → cambio
    }
    for (const name of names) stack.push(join(p, name))
  }
  return out
}

async function copyTree(src: string, dst: string): Promise<void> {
  const s = await lstat(src)
  if (s.isSymbolicLink()) {
    await symlink(await readlink(src), dst)
  } else if (s.isDirectory()) {
    await mkdir(dst, { recursive: true, mode: 0o700 })
    for (const name of await readdir(src)) {
      if (SKIP_DIRS.has(name) && (await lstat(join(src, name))).isDirectory()) continue
      await copyTree(join(src, name), join(dst, name))
    }
  } else if (s.isFile()) {
    await copyFile(src, dst)
    await chmod(dst, s.mode & 0o100 ? 0o500 : 0o400)
  }
}

function probe(bwrap: string): void {
  let ok = false
  let why = ""
  try {
    const r = Bun.spawnSync({ cmd: [bwrap, "--dev-bind", "/", "/", "--", "true"], stdout: "ignore", stderr: "pipe" })
    ok = r.exitCode === 0
    why = r.stderr.toString().trim()
  } catch (e) {
    why = String(e)
  }
  if (!ok) throw new Error(`GUARDS_ISOLATION_UNAVAILABLE: ${bwrap}: ${why || "no ejecuta"}`)
}

/** Directorios literales que nombra el registro y que, vía enlace, son un directorio de guards. */
function aliases(ws: string, registry: string): Array<{ from: string; to: string }> {
  const out = new Map<string, string>()
  for (const m of registry.matchAll(/\$\{?CLAUDE_(?:PROJECT_DIR|PLUGIN_ROOT)\}?"?\/([^\s"';|&]+)/g)) {
    const dirRel = dirname(m[1])
    if (dirRel === "." || OVERLAY_DIRS.some((d) => dirRel === d || dirRel.startsWith(d + "/"))) continue
    let real: string
    try {
      real = realpathSync(join(ws, dirRel))
    } catch {
      continue // no existe al fijar: no es un alias de un directorio de guards
    }
    for (const d of OVERLAY_DIRS) {
      const base = join(ws, d)
      if (real === base || real.startsWith(base + sep)) out.set(dirRel, join(d, relative(base, real)))
    }
  }
  return [...out].map(([to, from]) => ({ from, to }))
}

/** Hace la copia. Lanza (cerrado) si no hay bwrap utilizable. */
export async function prepareTrusted(workspace: string, opts: { bwrap?: string; base?: string } = {}): Promise<TrustedGuards> {
  const bwrap = opts.bwrap ?? process.env.SAVIA_GATES_BWRAP ?? "bwrap"
  probe(bwrap)
  const ws = await realpath(workspace)
  const copy = await mkdtemp(join(opts.base ?? tmpdir(), "savia-gates-trusted-"))
  // Copia privada y temporal: se borra al salir el proceso del motor.
  process.once("exit", () => rmSync(copy, { recursive: true, force: true }))
  for (const rel of [...OVERLAY_DIRS, REGISTRY]) {
    const src = await realpath(join(ws, rel)).catch(() => null)
    if (src) await copyTree(src, join(copy, rel))
  }
  for (const d of OVERLAY_DIRS) await mkdir(join(copy, d), { recursive: true, mode: 0o700 })
  await chmod(join(copy, ".claude"), 0o700)
  const registry = await readFile(join(copy, REGISTRY), "utf8").catch(() => "")
  const mounts = [...OVERLAY_DIRS.map((d) => ({ from: d as string, to: d as string })), ...aliases(ws, registry)]
  return { workspace: ws, copy, bwrap, mounts, sigs: snapshot(copy) }
}

/** Entradas de la copia que cambiaron, aparecieron o desaparecieron desde que se hizo. */
export async function verifyTrusted(t: TrustedGuards): Promise<string[]> {
  const now = snapshot(t.copy)
  const changed = new Set<string>()
  for (const [p, s] of t.sigs) if (now.get(p) !== s) changed.add(p)
  for (const p of now.keys()) if (!t.sigs.has(p)) changed.add(p)
  return [...changed].sort()
}

/** argv para ejecutar `bash -c <command>` con los guards montados desde la copia. */
export function wrapCommand(t: TrustedGuards, command: string): string[] {
  const argv = [t.bwrap, "--dev-bind", "/", "/"]
  for (const m of t.mounts) {
    let dest = join(t.workspace, m.to)
    try {
      // Si el agente borró el directorio, el punto de montaje se recrea.
      mkdirSync(dest, { recursive: true })
      dest = realpathSync(dest)
    } catch (e) {
      // Un enlace roto o un fichero en su lugar: bwrap no podrá montar y el hook falla cerrado.
      console.error(`savia-gates: punto de montaje ${dest}: ${e}`)
    }
    argv.push("--ro-bind", join(t.copy, m.from), dest)
  }
  argv.push("--chdir", t.workspace, "--die-with-parent", "--", "bash", "-c", command)
  return argv
}

// Una copia por directorio y por proceso del motor, como el pin: una recarga no la rehace.
const TRUSTED = new Map<string, Promise<TrustedGuards>>()

export function trustedFor(root: string): Promise<TrustedGuards> {
  let key = root
  try {
    key = realpathSync(root)
  } catch (e) {
    console.error(`savia-gates: ${root}: ${e}`) // sin canonicalizar: la clave es la ruta dada
  }
  let t = TRUSTED.get(key)
  if (!t) {
    t = prepareTrusted(root)
    TRUSTED.set(key, t)
  }
  return t
}
