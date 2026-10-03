import { test, expect } from "bun:test";
import { validateBashGlobal } from "../guards/validate-bash-global.ts";

const run = (command: string) => validateBashGlobal({ tool: "bash", args: { command } } as any, {} as any);

test("validateBashGlobal: sudo encadenado, con prefijo o en subshell se bloquea", async () => {
  for (const c of ["true && sudo apt install x", "LANG=C sudo apt install x", "echo $(sudo id)", "(sudo id)", "true && sudo"]) {
    await expect(run(c)).rejects.toThrow();
  }
});

test("validateBashGlobal: menciones y palabras que contienen sudo pasan", async () => {
  for (const c of ['echo "usa sudo solo con permiso"', "ls pseudocode/", "LANG=C ls -la"]) {
    await expect(run(c)).resolves.toBeUndefined();
  }
});
