import { test, expect } from "bun:test";
import { dataSovereigntyGate } from "../guards/data-sovereignty-gate.ts";

// Credencial sintética armada en tiempo de ejecución (un literal la bloquearía el propio shield al escribir este test).
const k = (...p: string[]) => p.join("");
const secret = "conexion: " + k("Ser", "ver=db.interna;") + k("User ", "Id=sa;") + k("Pass", "word=") + "Sint3tic0Secreto!;";
const write = (filePath: string) => dataSovereigntyGate({ tool: "write" } as any, { args: { filePath, content: secret } } as any);

test("una credencial hacia docs/ (público) se bloquea", async () => {
  await expect(write("/repo/docs/fuga.md")).rejects.toThrow(/BLOCKED/);
});

test("«projects/..» no convierte un destino público en privado", async () => {
  await expect(write("/repo/projects/../docs/fuga.md")).rejects.toThrow(/BLOCKED/);
  await expect(write("/repo/output/../../repo/docs/fuga.md")).rejects.toThrow(/BLOCKED/);
});

test("una ruta que de verdad acaba en projects/ sigue siendo privada", async () => {
  await expect(write("/repo/docs/../projects/x/notas.md")).resolves.toBeUndefined();
});
