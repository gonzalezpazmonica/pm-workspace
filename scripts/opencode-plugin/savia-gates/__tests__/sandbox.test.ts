import { expect, test } from "bun:test"
import { guardVariants, unwrapSandbox } from "../lib/sandbox"

// Formato real de opencode-sandbox (sandbox-runtime) visto en OpenCode 1.18.32.
const REAL =
  `bwrap --new-session --unshare-net --ro-bind / / -- /usr/bin/bash -c "/usr/bin/bash -c \\"socat x &\n` +
  `/opt/apply-seccomp /opt/x.bpf /usr/bin/bash -c 'rm -rf build'\\""`

test("unwrapSandbox extracts the command from a real sandbox wrapper", () => {
  expect(unwrapSandbox(REAL)).toBe("rm -rf build")
  expect(unwrapSandbox("ls -la")).toBe("ls -la")
})

test("unwrapSandbox does not hide anything that follows the closing quote", () => {
  const fake = "bwrap --new-session --bind /a /a bash -c 'echo hola'; rm -rf x"
  expect(unwrapSandbox(fake)).toBe(fake)
})

test("guardVariants gives hooks the original and the unwrapped bash command", () => {
  expect(guardVariants("bash", { command: REAL, description: "x" })).toEqual([
    { command: REAL, description: "x" },
    { command: "rm -rf build", description: "x" },
  ])
  expect(guardVariants("bash", { command: "ls" })).toEqual([{ command: "ls" }])
  expect(guardVariants("edit", { filePath: "a" })).toEqual([{ filePath: "a" }])
})
