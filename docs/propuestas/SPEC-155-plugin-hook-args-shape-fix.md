---
id: SPEC-155
title: OpenCode plugin hooks — fix args shape (input.args → output.args) + restore guard efficacy
status: PROPOSED
priority: CRITICAL
estimated_hours: 4
origin: Investigación 2026-05-30 tras fallo reproducible "BLOCKED [tool-healing]: read called with empty file_path" en sesión OpenCode/claude-opus-4.7
severity: SILENT_SECURITY_REGRESSION
---

# SPEC-155 — Plugin hook args shape fix

## Problema (root cause)

Los guards en `.opencode/plugins/guards/*.ts` leen los argumentos de la tool call desde `input.args.*`, pero OpenCode v1.14+ los pasa en `output.args.*`. El shape correcto está documentado en https://opencode.ai/docs/plugins/:

```js
"tool.execute.before": async (input, output) => {
  if (input.tool === "read" && output.args.filePath.includes(".env")) { ... }
}
```

Contrato real:
- `input.tool` → nombre de la tool (string)
- `output.args` → argumentos mutables de la tool (objeto)
- `input.args` → no existe / vacío en v1.14+

### Síntoma visible

`tool-call-healing.ts` lanza `BLOCKED [tool-healing]: read called with empty file_path` cada vez que el LLM intenta `read`/`edit`/`write` con un path absoluto válido. Reproducible 100% en OpenCode v1.14+.

### Síntoma invisible (más grave)

**Todos** los guards están leyendo args vacíos desde la migración:

| Guard | Comportamiento real | Comportamiento esperado |
|---|---|---|
| `tool-call-healing` | Throw ruidoso en read/edit/write (visible) | Validar paths |
| `validate-bash-global` | `extractCommand()` → `""` → return silencioso | Bloquear rm -rf /, force-push, etc. |
| `credential-leak` | `extractCommand()` → `""` → return silencioso | Bloquear AWS keys, PATs |
| `data-sovereignty-gate` | `extractFilePath()` → `""` → skip | Bloquear escritura N4 en N1 |

**Diagnóstico**: hooks de seguridad de Savia operan como security theater desde la migración a OpenCode v1.14. **No bloquean nada en producción** salvo el ruido visible de tool-call-healing. Los tests pasan porque emulan shape `{ tool, args }` en `input` y `{}` en `output`, exactamente al revés del contrato real.

## Por qué los tests no lo detectaron

`__tests__/savia-foundation.test.ts`:
```ts
const input = { tool: "bash", args: { command: "rm -rf /" } };
await expect(hooks["tool.execute.before"](input, {})).rejects.toThrow(/rm -rf/);
```

Pasa args en `input`, no en `output`. Coincide con shape que los guards leen, así que pasa. Pero NO refleja lo que OpenCode entrega.

Caso textbook de **tests que validan implementación, no contrato externo**. Ver `docs/rules/domain/verification-before-done.md` Rule #22.

## Solución

### Cambio 1 — `lib/hook-input.ts`: aceptar ambas formas con preferencia output

```ts
export type HookCtx = { input: ToolInput; output: ToolOutput };

export function extractFilePath(ctx: HookCtx): string {
  const args = ctx.output?.args ?? ctx.input?.args ?? {};
  const fp = args.filePath ?? args.file_path ?? args.path ?? "";
  return typeof fp === "string" ? fp : "";
}

export function extractCommand(ctx: HookCtx): string {
  const args = ctx.output?.args ?? ctx.input?.args ?? {};
  const cmd = args.command ?? "";
  return typeof cmd === "string" ? cmd : "";
}

export function extractContent(ctx: HookCtx): string {
  const args = ctx.output?.args ?? ctx.input?.args ?? {};
  return String(args.content ?? args.newString ?? args.new_string ?? "");
}
```

Preferir `output.args` (contrato actual) con fallback a `input.args` (compat legacy).

### Cambio 2 — refactor signature de todos los guards

De: `async function guard(input, _output)`
A: `async function guard(ctx: HookCtx)`

En `savia-foundation.ts`:
```ts
"tool.execute.before": async (input: any, output: any) => {
  const ctx = { input, output };
  for (const guard of BEFORE_GUARDS) await guard(ctx);
}
```

### Cambio 3 — golden integration test (pieza que faltaba)

`__tests__/plugin-contract.integration.test.ts`:

```ts
// SPEC-155 regression: valida shape REAL OpenCode v1.14+, no la asunción interna.
test("read tool con path absoluto NO bloqueado por tool-healing", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "read", callID: "x", sessionID: "y" };
  const output = { args: { filePath: "/etc/hostname" } };
  await expect(hooks["tool.execute.before"](input, output)).resolves.toBeUndefined();
});

test("validate-bash-global bloquea rm -rf con args en output (v1.14)", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash", callID: "x", sessionID: "y" };
  const output = { args: { command: "rm -rf /" } };
  await expect(hooks["tool.execute.before"](input, output)).rejects.toThrow(/rm -rf/);
});

test("credential-leak bloquea AWS key con args en output", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash", callID: "x", sessionID: "y" };
  const output = { args: { command: "X=" + "AKIA" + "IOSFODNN7EXAMPLE" } };
  await expect(hooks["tool.execute.before"](input, output)).rejects.toThrow(/AWS/);
});
```

### Cambio 4 — migrar tests legacy

Actualizar `savia-foundation.test.ts` para pasar `{ input, output }` con shape real. Mantener al menos un test por guard validando shape de producción.

## Acceptance Criteria

| AC | Criterio | Verificación |
|---|---|---|
| AC-1 | `read` con path absoluto no lanza BLOCKED | Manual en sesión OpenCode |
| AC-2 | `validate-bash-global` bloquea `rm -rf /` con shape real | Integration test verde |
| AC-3 | `credential-leak` bloquea AWS key con shape real | Integration test verde |
| AC-4 | `data-sovereignty-gate` bloquea N4→N1 con shape real | Integration test verde |
| AC-5 | `tool-call-healing` valida path existence con shape real | Integration test verde |
| AC-6 | Tests legacy (input.args) siguen pasando por fallback | `bun test` verde |
| AC-7 | Golden test falla si revertimos extractor a solo input.args | Mutación manual |

## Riesgo y rollback

**Riesgo bajo**: cambio retro-compatible (lee `output.args` con fallback a `input.args`).
**Rollback**: revert del PR. Guards vuelven al estado roto-pero-silencioso. Sin corrupción.

## Lecciones (Rule #21 self-improvement)

1. **Tests emulan contrato externo, no implementación interna**. Cada plugin/hook que dialoga con sistema externo (OpenCode, Claude Code, API) debe tener al menos un test que use la shape documentada por el sistema externo, copiada literalmente de su doc oficial.

2. **Detección activa de silent failure**. Guard que devuelve `return` silencioso ante input vacío es bug, no feature. Añadir warning log cuando guard se ejecuta pero no encuentra campo esperado.

3. **Verificación post-migración runtime**. Cuando se migra a nueva versión de frontend, validar manualmente en sesión real que los guards siguen disparándose. Tests unitarios no son suficientes.

## Trabajo derivado

Crear `docs/rules/domain/external-contract-testing.md`:
> Todo módulo que dialoga con sistema externo debe tener al menos un integration test que use la shape documentada del sistema externo, copiada literalmente de su doc oficial. El test debe romperse si el sistema externo cambia el contrato.

## Referencias

- OpenCode plugins docs: https://opencode.ai/docs/plugins/ (sección `.env protection`)
- Código afectado: `.opencode/plugins/guards/*.ts`, `.opencode/plugins/lib/hook-input.ts`, `.opencode/plugins/savia-foundation.ts`
- Tests afectados: `.opencode/plugins/__tests__/savia-foundation.test.ts`, `.opencode/plugins/lib/hook-input.test.ts`
- Rule #22 Verification Before Done
- Rule #21 Self-Improvement

## Estimación

- 1h refactor `hook-input.ts` + 4 guards a `HookCtx`
- 1h integration tests con shape real (1 por guard mínimo)
- 1h migrar tests legacy + mantener fallback
- 1h verificación manual sesión real + `external-contract-testing.md`

**Total**: 4h.

## Prioridad

**CRITICAL**. Guards de seguridad no funcionan en producción. Cualquier sesión OpenCode v1.14+ ejecuta `rm -rf /`, AWS keys o escrituras N4→N1 sin bloqueo real a nivel plugin (solo bash global del shell intercepta `rm -rf /`, y pre-commit hooks atrapan algo; la defensa en profundidad de Savia Shield a nivel plugin está rota).

Implementar antes que cualquier otro SE de Era 197.
