import { test, expect } from "bun:test";
import { runGuardsOnVariants, unwrapSandbox } from "../lib/sandbox.ts";

const wrap = (c: string) => `bwrap --new-session --die-with-parent --unshare-net --bind /a /a bash -c '${c}'`;
const blocksSudo = async (input: any, output: any) => {
  const cmd = output?.args?.command ?? input?.args?.command ?? "";
  if (/^\s*sudo\s/.test(cmd)) throw new Error("BLOCKED [sudo]");
};

test("unwrapSandbox: solo envoltorios limpios", () => {
  expect(unwrapSandbox(wrap("sudo x"))).toBe("sudo x");
  const fake = "bwrap --x bash -c 'echo hola'; sudo x";
  expect(unwrapSandbox(fake)).toBe(fake);
});

test("una orden envuelta por el sandbox no esquiva un guard anclado", async () => {
  const output = { args: { command: wrap("sudo apt install x") } };
  await expect(runGuardsOnVariants([blocksSudo], { tool: "bash" }, output)).rejects.toThrow(/sudo/);
});

test("las mutaciones de la pasada desenvuelta no tocan los argumentos reales", async () => {
  const mutate = async (_i: any, o: any) => { o.args.command = o.args.command + "!"; };
  const output = { args: { command: wrap("echo hola") } };
  await runGuardsOnVariants([mutate], { tool: "bash" }, output);
  expect(output.args.command).toBe(wrap("echo hola") + "!");
  const plain = { args: { command: "echo hola" } };
  let calls = 0;
  await runGuardsOnVariants([async () => { calls++; }], { tool: "bash" }, plain);
  expect(calls).toBe(1);
});
