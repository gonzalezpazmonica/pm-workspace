// sandbox.ts — guards a través del envoltorio de sandbox, sin fiarse de él.
//
// Plugins como opencode-sandbox reescriben la orden como `bwrap … bash -c '<cmd>'`
// antes que los guards; los patrones anclados (`^\s*sudo`) dejan de casar. Desenvolver
// sin más tampoco vale: `bwrap … -c 'echo hola'; sudo x` se quedaría en `echo hola`.
// Por eso los guards se ejecutan sobre la forma original y, si es un envoltorio limpio,
// también sobre la desenvuelta (en una copia): cualquier bloqueo gana y las mutaciones
// solo se aplican desde la forma original.

type Guard = (input: any, output: any) => Promise<void>;

/** La orden dentro de un envoltorio limpio de sandbox; si no lo es, la orden tal cual. */
export function unwrapSandbox(cmd: string): string {
  if (!cmd.trimStart().startsWith("bwrap ")) return cmd;
  const i = cmd.lastIndexOf(" -c '");
  if (i < 0) return cmd;
  const rest = cmd.slice(i + 5);
  const j = rest.lastIndexOf("'");
  if (j <= 0 || !/^[\\"\s]*$/.test(rest.slice(j + 1))) return cmd;
  return rest.slice(0, j).replaceAll("'\\''", "'");
}

export async function runGuardsOnVariants(guards: readonly Guard[], input: any, output: any): Promise<void> {
  for (const guard of guards) await guard(input, output);
  const command = output?.args?.command ?? input?.args?.command;
  if (typeof command !== "string") return;
  const inner = unwrapSandbox(command);
  if (inner === command) return;
  const args = { ...(output?.args ?? input?.args ?? {}), command: inner };
  const shadowIn = { ...input, ...(input?.args ? { args: { ...args } } : {}) };
  const shadowOut = { ...output, args };
  for (const guard of guards) await guard(shadowIn, shadowOut);
}
